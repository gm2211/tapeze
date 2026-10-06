# TestFlight

[Back to README](../README.md)

Run these commands from the repository root.

The repo includes a repeatable App Store Connect/TestFlight upload script. It defaults to Xcode at `/Applications/Xcode.app`, archives the app with automatic signing, exports an App Store Connect IPA, validates it, and uploads it.

Prerequisites:

- Paid Apple Developer Program membership on team `6KQV68SJ5P`
- App Store Connect app record for bundle ID `com.gm2211.tapeze`
- Matching keyboard extension bundle ID `com.gm2211.tapeze.keyboard`
- App Group enabled for both targets: `group.com.gm2211.tapeze`
- App Store Connect API key, or Apple ID plus app-specific password

Recommended API key setup:

```bash
export ASC_API_KEY_ID=ABC123DEF4
export ASC_API_ISSUER_ID=00000000-0000-0000-0000-000000000000
export ASC_API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
```

For first-time distribution on a machine, either keep those API key variables set or sign in through **Xcode > Settings > Accounts** with a Developer Program account. Without one of those, archive may succeed but export will fail with `No Accounts` or `No signing certificate "iOS Distribution" found`.

Archive/export only:

```bash
scripts/upload-testflight.sh --skip-upload
```

Increment the build number, validate, and upload:

```bash
scripts/upload-testflight.sh --increment-build
```

Check processing status after upload:

```bash
APPLE_ID=<app-apple-id> BUNDLE_VERSION=<build-number> scripts/testflight-status.sh
```
