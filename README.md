# Tapeze

A compact gesture keyboard for iOS. Tap the main keys for common letters, then swipe through the same grid for secondary letters, symbols, commands, and fast corrections.

## Layout

### Letter Mode
```
 [a]  [n]  [i]
 [h]  [o]  [r]
 [t]  [e]  [s]
```

Small diamond controls live between the keys for layer switching and return. Space and delete do not have dedicated keys.

### Number/Symbol Mode
```
 [1]  [2]  [3]
 [4]  [5]  [6]
 [7]  [8]  [9]
```

## Gestures

1. **Tap** a key to type the yellow (center) letter
2. **Swipe** between two keys to type the gray letter shown between them
3. **Swipe and back** (out and return to same key) to get the **uppercase** version of the swipe character
4. **Circular motion** starting and ending on a key to type the **uppercase** of the tap character
5. **Long horizontal swipe** crossing 3 keys inserts a space
6. **Long vertical swipe** crossing 3 keys deletes backward
7. **Layer diamond** switches between letters and numbers/symbols
8. **Return diamond** inserts a newline and also handles size gestures

Gesture trails are shown by default while swiping and can be turned off from the Tapeze app settings.

## TestFlight

The repo includes a repeatable App Store Connect/TestFlight upload script. It pins the Xcode path to `/Applications/Xcode.app`, archives the app with automatic signing, exports an App Store Connect IPA, validates it, and uploads it.

Prerequisites:
- Paid Apple Developer Program membership on team `6KQV68SJ5P`
- App Store Connect app record for bundle ID `com.gmecocci.tapeze`
- Matching keyboard extension bundle ID `com.gmecocci.tapeze.keyboard`
- App Group enabled for both targets: `group.com.gmecocci.tapeze`
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

## Setup & Testing on iPhone Simulator

### Prerequisites
- macOS with Xcode 15+ installed
- (Optional) [XcodeGen](https://github.com/yonaskolb/XcodeGen) for regenerating the project

### Quick Start

1. Clone the repo and open the project:
   ```bash
   git clone <repo-url>
   cd tapeze
   open Tapeze.xcodeproj
   ```

2. Select the **Tapeze** scheme and an iPhone simulator, then build and run (Cmd+R).

3. Enable the keyboard on the simulator:
   - Go to **Settings > General > Keyboard > Keyboards > Add New Keyboard**
   - Select **Tapeze**
   - Optionally enable "Allow Full Access" for clipboard support

4. Open an app with a plain text field (e.g., Notes, Messages, or the test field in Tapeze)
   - Avoid password fields, phone-number fields, and Safari's address/search bar while testing; iOS may force Apple's keyboard there.
   - Long-press the globe icon on the system keyboard
   - Select **Tapeze**

### Using XcodeGen (alternative)

If the .xcodeproj doesn't work (e.g., Xcode version mismatch), regenerate it:

```bash
brew install xcodegen
xcodegen generate
open Tapeze.xcodeproj
```

## Project Structure

```
Tapeze/
├── Tapeze.xcodeproj/          # Xcode project
├── project.yml                # XcodeGen spec (for regenerating)
├── Tapeze/                    # Container app
│   ├── TapezeApp.swift        # App entry point
│   ├── ContentView.swift      # Setup instructions + preview
│   ├── Info.plist
│   └── Assets.xcassets/
├── TapezeKeyboard/            # Keyboard extension
│   ├── KeyboardViewController.swift  # UIInputViewController
│   ├── KeyboardView.swift     # Main keyboard SwiftUI view
│   ├── KeyView.swift          # Individual key views + theme
│   ├── KeyboardLayout.swift   # Key maps for all layers
│   ├── KeyboardState.swift    # Observable state management
│   ├── GestureEngine.swift    # Gesture recognition engine
│   └── Info.plist             # Extension config
└── README.md
```

## Architecture

- **KeyboardLayout**: Static data defining key configurations for each layer (letters, numbers, symbols). Each key has a tap character and a map of swipe-direction to character.
- **KeyboardState**: `ObservableObject` managing current layer, shift state, keyboard size, layout preferences.
- **GestureEngine**: Tracks touch paths and classifies gestures (tap, swipe, swipe-back, circle).
- **KeyView**: SwiftUI view rendering a single key with center and peripheral labels.
- **KeyboardView**: Assembles the full keyboard grid, command bar, and bottom row. Handles gesture results and dispatches to the text document proxy.
- **KeyboardViewController**: `UIInputViewController` that hosts the SwiftUI keyboard view.
