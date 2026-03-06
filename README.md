# Tapeze

A gesture-based keyboard for iOS inspired by MessagEase. Uses a compact 3x3 grid where tap gives you the most common letters, and swiping between keys gives you the rest of the alphabet and symbols.

## Layout

### Letter Mode (3x3 grid)
```
 [a]  [n]  [i]  | [globe]
 [h]  [o]  [r]  | [123]
 [t]  [e]  [s]  | [backspace]
 [  spacebar  ]  | [enter]
```

### Number/Symbol Mode
```
 [1]  [2]  [3]  | [globe]
 [4]  [5]  [6]  | [abc]
 [7]  [8]  [9]  | [backspace]
 [0] [space]     | [enter]
```

## Gestures

1. **Tap** a key to type the yellow (center) letter
2. **Swipe** between two keys to type the gray letter shown between them
3. **Swipe and back** (out and return to same key) to get the **uppercase** version of the swipe character
4. **Circular motion** starting and ending on a key to type the **uppercase** of the tap character
5. **Spacebar swipe up** toggles symbols; **swipe up and back** toggles showing/hiding center labels
6. **Globe swipe left/right** toggles keyboard width mode
7. **Globe circle** moves command bar between left and right side
8. **Globe swipe up** increases keyboard size
9. **Globe swipe down** decreases keyboard size

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

4. Open any app with a text field (e.g., Notes, Safari)
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
