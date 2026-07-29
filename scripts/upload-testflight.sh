#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"
XCRUN="/usr/bin/xcrun"

PROJECT="${PROJECT:-tapeze.xcodeproj}"
SCHEME="${SCHEME:-tapeze}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-6KQV68SJ5P}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT_DIR/Config/TestFlightExportOptions.plist}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/TestFlight}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/tapeze.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$BUILD_DIR/export}"
IPA_PATH="${IPA_PATH:-$EXPORT_PATH/tapeze.ipa}"

INCREMENT_BUILD=0
SKIP_UPLOAD=0
SKIP_VALIDATE=0
WAIT_FOR_PROCESSING=0

usage() {
	cat <<USAGE
Usage: scripts/upload-testflight.sh [options]

Archives Tapeze, exports an App Store Connect IPA, validates it, and uploads it
for TestFlight processing.

Options:
  --increment-build      Increment CURRENT_PROJECT_VERSION before archiving.
  --skip-upload          Archive/export only; do not validate or upload.
  --skip-validate        Upload without the separate validation step.
  --wait                 Ask App Store Connect upload to wait for processing.
  -h, --help             Show this help.

Authentication:
  Preferred:
    ASC_API_KEY_ID       App Store Connect API key ID.
    ASC_API_ISSUER_ID    App Store Connect issuer ID.
    ASC_API_KEY_PATH     Optional path to AuthKey_<key id>.p8.

  Fallback:
    ASC_USERNAME         Apple ID email.
    ASC_PASSWORD         App-specific password, or @keychain:item.

Example:
  ASC_API_KEY_ID=ABC123 ASC_API_ISSUER_ID=... \\
    scripts/upload-testflight.sh --increment-build
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--increment-build) INCREMENT_BUILD=1 ;;
		--skip-upload) SKIP_UPLOAD=1 ;;
		--skip-validate) SKIP_VALIDATE=1 ;;
		--wait) WAIT_FOR_PROCESSING=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown option: $1" >&2; usage; exit 2 ;;
	esac
	shift
done

require_tool() {
	if [[ ! -x "$1" ]]; then
		echo "Missing required tool: $1" >&2
		exit 1
	fi
}

current_build_number() {
	/usr/bin/awk -F'= ' '/CURRENT_PROJECT_VERSION = / {
		gsub(/;/, "", $2)
		print $2
		exit
	}' tapeze.xcodeproj/project.pbxproj
}

increment_build_number() {
	local current next
	current="$(current_build_number)"
	if [[ ! "$current" =~ ^[0-9]+$ ]]; then
		echo "Cannot auto-increment non-numeric build number: $current" >&2
		exit 1
	fi
	next=$((current + 1))
	/usr/bin/perl -0pi -e "s/CURRENT_PROJECT_VERSION = \\Q$current\\E;/CURRENT_PROJECT_VERSION = $next;/g" tapeze.xcodeproj/project.pbxproj
	echo "Incremented build number: $current -> $next"
}

# Fall back to the login keychain for API credentials so uploads don't need
# the issuer ID re-typed each session. Populate once with:
#   security add-generic-password -s ASC_API_KEY_ID -a "$USER" -w <key id> -U
#   security add-generic-password -s ASC_API_ISSUER_ID -a "$USER" -w <issuer uuid> -U
ASC_API_KEY_ID="${ASC_API_KEY_ID:-$(security find-generic-password -s ASC_API_KEY_ID -w 2>/dev/null || true)}"
ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:-$(security find-generic-password -s ASC_API_ISSUER_ID -w 2>/dev/null || true)}"
if [[ -z "${ASC_API_KEY_PATH:-}" ]]; then
	default_key_path="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
	[[ -n "${ASC_API_KEY_ID:-}" && -f "$default_key_path" ]] && ASC_API_KEY_PATH="$default_key_path"
fi

auth_args=()
build_auth_args=()
if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
	auth_args+=(--api-key "$ASC_API_KEY_ID" --api-issuer "$ASC_API_ISSUER_ID")
	build_auth_args+=(-authenticationKeyID "$ASC_API_KEY_ID" -authenticationKeyIssuerID "$ASC_API_ISSUER_ID")
	if [[ -n "${ASC_API_KEY_PATH:-}" ]]; then
		auth_args+=(--p8-file-path "$ASC_API_KEY_PATH")
		build_auth_args+=(-authenticationKeyPath "$ASC_API_KEY_PATH")
	fi
elif [[ -n "${ASC_USERNAME:-}" && -n "${ASC_PASSWORD:-}" ]]; then
	auth_args=(-u "$ASC_USERNAME" -p "$ASC_PASSWORD")
fi

require_tool "$XCODEBUILD"

if [[ "$INCREMENT_BUILD" == "1" ]]; then
	increment_build_number
fi

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "Archiving $SCHEME ($CONFIGURATION) for App Store Connect..."
if [[ ${#build_auth_args[@]} -eq 0 ]]; then
	echo "No ASC API key was provided for xcodebuild. Xcode must already have a Developer Program account signed in for export/signing."
fi
"$XCODEBUILD" \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-destination "generic/platform=iOS" \
	-archivePath "$ARCHIVE_PATH" \
	-allowProvisioningUpdates \
	${build_auth_args[@]+"${build_auth_args[@]}"} \
	DEVELOPMENT_TEAM="$TEAM_ID" \
	clean archive

echo "Exporting IPA..."
"$XCODEBUILD" \
	-exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_PATH" \
	-exportOptionsPlist "$EXPORT_OPTIONS" \
	-allowProvisioningUpdates \
	${build_auth_args[@]+"${build_auth_args[@]}"}

if [[ ! -f "$IPA_PATH" ]]; then
	echo "Expected IPA was not produced: $IPA_PATH" >&2
	exit 1
fi

echo "IPA ready: $IPA_PATH"

if [[ "$SKIP_UPLOAD" == "1" ]]; then
	echo "Skipping validation/upload."
	exit 0
fi

if [[ ${#auth_args[@]} -eq 0 ]]; then
	echo "Missing App Store Connect credentials. Set ASC_API_KEY_ID + ASC_API_ISSUER_ID, or ASC_USERNAME + ASC_PASSWORD." >&2
	exit 1
fi

if [[ "$SKIP_VALIDATE" != "1" ]]; then
	echo "Validating IPA with App Store Connect..."
	"$XCRUN" altool --validate-app "$IPA_PATH" "${auth_args[@]}" --output-format json
fi

upload_args=(--upload-package "$IPA_PATH" "${auth_args[@]}" --show-progress --output-format json)
if [[ "$WAIT_FOR_PROCESSING" == "1" ]]; then
	upload_args+=(--wait)
fi

echo "Uploading IPA to App Store Connect/TestFlight..."
"$XCRUN" altool "${upload_args[@]}"
