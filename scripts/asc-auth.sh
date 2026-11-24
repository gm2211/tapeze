# shellcheck shell=bash
# Shared App Store Connect authentication for upload-testflight.sh and
# testflight-status.sh. Source it near the top of the script, BEFORE parsing
# arguments, passing the script's own arguments so a re-exec keeps them:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/asc-auth.sh" "$@"
#
# Afterwards these are set:
#   ASC_API_KEY_ID, ASC_API_ISSUER_ID  from the env, else the login Keychain
#   ASC_API_KEY_PATH                   from the env, else the default
#                                      ~/.appstoreconnect/private_keys file, else
#                                      a 0600 temp file decoded from ASC_P8_B64
#                                      (deleted on EXIT)
#   asc_auth_args                      altool auth arguments (may be empty)
#   asc_build_auth_args                xcodebuild auth arguments (may be empty)
#
# When no .p8 is available and ASC_P8_B64 is not in the environment, the calling
# script re-execs itself once under `with-secrets ASC_P8_B64 -- ...` so the key
# loads from the Keychain without manual wrapping. The key is never printed.

# Fall back to the login Keychain for the key and issuer IDs. Populate once with:
#   security add-generic-password -s ASC_API_KEY_ID -a "$USER" -w <key id> -U
#   security add-generic-password -s ASC_API_ISSUER_ID -a "$USER" -w <issuer uuid> -U
ASC_API_KEY_ID="${ASC_API_KEY_ID:-$(security find-generic-password -s ASC_API_KEY_ID -w 2>/dev/null || true)}"
ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:-$(security find-generic-password -s ASC_API_ISSUER_ID -w 2>/dev/null || true)}"

asc_find_with_secrets() {
	local candidate
	candidate="$(command -v with-secrets 2>/dev/null || true)"
	# `with-secrets` is often a shell alias, invisible to scripts; try its home.
	if [[ -z "$candidate" || ! -x "$candidate" ]]; then
		candidate="$HOME/.claude/bin/with-secrets"
	fi
	[[ -x "$candidate" ]] && printf '%s\n' "$candidate"
}

if [[ -z "${ASC_API_KEY_PATH:-}" && -n "${ASC_API_KEY_ID:-}" ]]; then
	asc_default_key_path="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
	if [[ -f "$asc_default_key_path" ]]; then
		ASC_API_KEY_PATH="$asc_default_key_path"
	elif [[ -n "${ASC_P8_B64:-}" ]]; then
		ASC_API_KEY_PATH="$(mktemp "${TMPDIR:-/tmp}/asc-authkey.XXXXXX")"
		chmod 600 "$ASC_API_KEY_PATH"
		# shellcheck disable=SC2064 # expand the path now
		trap "rm -f '$ASC_API_KEY_PATH'" EXIT
		if ! printf '%s' "$ASC_P8_B64" | /usr/bin/base64 -D >"$ASC_API_KEY_PATH" 2>/dev/null \
			|| ! /usr/bin/grep -q 'BEGIN PRIVATE KEY' "$ASC_API_KEY_PATH"; then
			echo "ASC_P8_B64 did not decode to a .p8 private key." >&2
			exit 1
		fi
		unset ASC_P8_B64
		export ASC_API_KEY_PATH
	elif [[ -z "${ASC_AUTH_REEXECED:-}" ]]; then
		asc_with_secrets="$(asc_find_with_secrets || true)"
		if [[ -n "$asc_with_secrets" ]]; then
			echo "Loading the App Store Connect key via with-secrets..." >&2
			export ASC_AUTH_REEXECED=1
			asc_self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
			exec "$asc_with_secrets" ASC_P8_B64 -- "$BASH" "$asc_self" "$@"
		fi
	fi
fi
unset ASC_AUTH_REEXECED

asc_auth_args=()
asc_build_auth_args=()
if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
	asc_auth_args+=(--api-key "$ASC_API_KEY_ID" --api-issuer "$ASC_API_ISSUER_ID")
	asc_build_auth_args+=(-authenticationKeyID "$ASC_API_KEY_ID" -authenticationKeyIssuerID "$ASC_API_ISSUER_ID")
	if [[ -n "${ASC_API_KEY_PATH:-}" ]]; then
		asc_auth_args+=(--p8-file-path "$ASC_API_KEY_PATH")
		asc_build_auth_args+=(-authenticationKeyPath "$ASC_API_KEY_PATH")
	fi
elif [[ -n "${ASC_USERNAME:-}" && -n "${ASC_PASSWORD:-}" ]]; then
	asc_auth_args=(-u "$ASC_USERNAME" -p "$ASC_PASSWORD")
fi

# Prints a 20-minute App Store Connect API bearer token (ES256 JWT) signed with
# the .p8 key. Needs ASC_API_KEY_ID, ASC_API_ISSUER_ID and ASC_API_KEY_PATH.
asc_jwt() {
	if [[ -z "${ASC_API_KEY_ID:-}" || -z "${ASC_API_ISSUER_ID:-}" || -z "${ASC_API_KEY_PATH:-}" ]]; then
		echo "asc_jwt needs ASC_API_KEY_ID, ASC_API_ISSUER_ID and a .p8 key." >&2
		return 1
	fi
	/usr/bin/python3 -I - "$ASC_API_KEY_ID" "$ASC_API_ISSUER_ID" "$ASC_API_KEY_PATH" <<'PY'
import base64, json, subprocess, sys, time
kid, iss, key = sys.argv[1:4]
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
now = int(time.time())
header = b64(json.dumps({"alg": "ES256", "kid": kid, "typ": "JWT"}).encode())
claims = b64(json.dumps({"iss": iss, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode())
signing_input = f"{header}.{claims}".encode()
der = subprocess.run(["/usr/bin/openssl", "dgst", "-sha256", "-sign", key],
                     input=signing_input, capture_output=True, check=True).stdout
# DER ECDSA signature -> raw r||s (32 bytes each), as JWS requires.
def read_int(buf, i):
    assert buf[i] == 0x02
    n = buf[i + 1]
    return int.from_bytes(buf[i + 2:i + 2 + n], "big"), i + 2 + n
i = 2 if der[1] < 0x80 else 3
r, i = read_int(der, i)
s, _ = read_int(der, i)
print(f"{header}.{claims}.{b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}")
PY
}
