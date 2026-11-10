import Foundation

// KeyboardLayout.swift reads the shared app-group suite name from
// KeyboardState, which drags in the whole keyboard runtime. The tests only
// need the name, so stand in for it here.
enum KeyboardState {
    static let appGroupSuiteName = "group.com.gm2211.tapeze.gesture-tests"
}
