import AppKit

/// Hides the mouse pointer while the lens is shown; the lens itself marks where the pointer is.
///
/// macOS only lets the frontmost app hide the pointer, and Demo Pointer stays in the background so
/// the app being demoed keeps focus. The GitHub build turns on the "SetsCursorInBackground" property of
/// its WindowServer connection, an undocumented switch that presentation tools use, which lets
/// CGDisplayHideCursor work from the background. The functions are looked up at run time, so if a
/// macOS update removes them the pointer simply stays visible.
/// The Mac App Store doesn't allow undocumented APIs, so the App Store build leaves the pointer alone.
@MainActor
final class CursorHider {
    private var isHidden = false

    init() {
        #if !APPSTORE
        Self.allowHidingInBackground()
        #endif
    }

    func hide() {
        #if !APPSTORE
        guard !isHidden else { return }
        isHidden = CGDisplayHideCursor(CGMainDisplayID()) == .success
        #endif
    }

    func show() {
        guard isHidden else { return }
        isHidden = false
        CGDisplayShowCursor(CGMainDisplayID())
    }

    #if !APPSTORE
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private static func allowHidingInBackground() {
        let handle = dlopen(nil, RTLD_NOW)
        guard let connectionSymbol = dlsym(handle, "CGSMainConnectionID"),
              let propertySymbol = dlsym(handle, "CGSSetConnectionProperty")
        else {
            NSLog("DemoPointer: can't hide the pointer in the background on this macOS")
            return
        }
        let connection = unsafeBitCast(connectionSymbol, to: MainConnectionID.self)()
        let setProperty = unsafeBitCast(propertySymbol, to: SetConnectionProperty.self)
        let error = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        if error != 0 {
            NSLog("DemoPointer: SetsCursorInBackground failed: \(error)")
        }
    }
    #endif
}
