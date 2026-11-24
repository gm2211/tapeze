#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/asc-auth.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/asc-auth.sh" "$@"

APPLE_ID="${APPLE_ID:-6771610102}"
BUNDLE_VERSION="${BUNDLE_VERSION:-}"
SHORT_VERSION="${SHORT_VERSION:-}"

usage() {
	cat <<USAGE
Usage: [APPLE_ID=<app apple id>] BUNDLE_VERSION=<build> [SHORT_VERSION=<x.y.z>] \\
  scripts/testflight-status.sh

Checks App Store Connect processing and TestFlight status for an uploaded
build through the App Store Connect API. APPLE_ID defaults to Tapeze's
(6771610102). (altool's --build-status only works with a --delivery-id now.)

Authentication: ASC_API_KEY_ID + ASC_API_ISSUER_ID (env or login Keychain) and
the .p8 key, found the same way as in upload-testflight.sh (scripts/asc-auth.sh).
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ -z "$BUNDLE_VERSION" ]]; then
	usage >&2
	exit 2
fi

if [[ -z "${ASC_API_KEY_PATH:-}" ]]; then
	echo "Missing App Store Connect API key (ASC_API_KEY_ID, ASC_API_ISSUER_ID and the .p8)." >&2
	exit 1
fi

query="filter%5Bapp%5D=$APPLE_ID&filter%5Bversion%5D=$BUNDLE_VERSION"
if [[ -n "$SHORT_VERSION" ]]; then
	query+="&filter%5BpreReleaseVersion.version%5D=$SHORT_VERSION"
fi
query+="&include=buildBetaDetail,preReleaseVersion"
query+="&fields%5Bbuilds%5D=version,processingState,uploadedDate,expired,expirationDate,buildBetaDetail,preReleaseVersion"
query+="&fields%5BbuildBetaDetails%5D=internalBuildState,externalBuildState"
query+="&fields%5BpreReleaseVersions%5D=version"

# The token goes to curl on stdin, never argv.
response="$(printf 'header = "Authorization: Bearer %s"\n' "$(asc_jwt)" \
	| /usr/bin/curl -sS --fail-with-body -K - "https://api.appstoreconnect.apple.com/v1/builds?$query")"

printf '%s' "$response" | /usr/bin/python3 -I -c '
import json, sys
doc = json.load(sys.stdin)
builds = doc.get("data", [])
if not builds:
    print("No matching build found."); sys.exit(1)
inc = {(i["type"], i["id"]): i.get("attributes", {}) for i in doc.get("included", [])}
for b in builds:
    a = b["attributes"]; rel = b.get("relationships", {})
    def related(name, typ):
        d = (rel.get(name) or {}).get("data") or {}
        return inc.get((typ, d.get("id")), {})
    beta = related("buildBetaDetail", "buildBetaDetails")
    pre = related("preReleaseVersion", "preReleaseVersions")
    print(json.dumps({
        "version": pre.get("version"),
        "build": a.get("version"),
        "processingState": a.get("processingState"),
        "uploadedDate": a.get("uploadedDate"),
        "expired": a.get("expired"),
        "internalBuildState": beta.get("internalBuildState"),
        "externalBuildState": beta.get("externalBuildState"),
    }, indent=2))
'
