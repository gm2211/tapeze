#!/usr/bin/env bash
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

APPLE_ID="${APPLE_ID:-}"
BUNDLE_VERSION="${BUNDLE_VERSION:-}"
SHORT_VERSION="${SHORT_VERSION:-1.0}"

usage() {
	cat <<USAGE
Usage: APPLE_ID=<app apple id> BUNDLE_VERSION=<build> scripts/testflight-status.sh

Checks App Store Connect processing status for an uploaded TestFlight build.

Authentication is the same as upload-testflight.sh:
  ASC_API_KEY_ID + ASC_API_ISSUER_ID [ + ASC_API_KEY_PATH ], or
  ASC_USERNAME + ASC_PASSWORD
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ -z "$APPLE_ID" || -z "$BUNDLE_VERSION" ]]; then
	usage >&2
	exit 2
fi

ASC_API_KEY_ID="${ASC_API_KEY_ID:-$(security find-generic-password -s ASC_API_KEY_ID -w 2>/dev/null || true)}"
ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:-$(security find-generic-password -s ASC_API_ISSUER_ID -w 2>/dev/null || true)}"
if [[ -z "${ASC_API_KEY_PATH:-}" ]]; then
	default_key_path="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
	[[ -n "${ASC_API_KEY_ID:-}" && -f "$default_key_path" ]] && ASC_API_KEY_PATH="$default_key_path"
fi

auth_args=()
if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
	auth_args+=(--api-key "$ASC_API_KEY_ID" --api-issuer "$ASC_API_ISSUER_ID")
	if [[ -n "${ASC_API_KEY_PATH:-}" ]]; then
		auth_args+=(--p8-file-path "$ASC_API_KEY_PATH")
	fi
elif [[ -n "${ASC_USERNAME:-}" && -n "${ASC_PASSWORD:-}" ]]; then
	auth_args=(-u "$ASC_USERNAME" -p "$ASC_PASSWORD")
else
	echo "Missing App Store Connect credentials." >&2
	exit 1
fi

"$XCRUN" altool \
	--build-status \
	--apple-id "$APPLE_ID" \
	--bundle-short-version-string "$SHORT_VERSION" \
	--bundle-version "$BUNDLE_VERSION" \
	--platform ios \
	"${auth_args[@]}" \
	--output-format json
