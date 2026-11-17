import AppKit

/// User preferences, persisted in UserDefaults.
final class Settings {
    static let shared = Settings()

    static let zoomLevels: [Double] = [1.5, 2, 3, 4]
    static let sizes: [(name: String, diameter: Double)] = [
        ("Small", 160),
        ("Medium", 276),
        ("Large", 468),
    ]
    /// How dark the rest of the screen gets while the lens is shown.
    static let shades: [(name: String, opacity: Double)] = [
        ("Off", 0),
        ("Light", 0.25),
        ("Medium", 0.45),
        ("Dark", 0.65),
    ]

    /// Pen colours for drawing and arrows.
    static let penColors: [(name: String, color: NSColor)] = [
        ("Red", .systemRed),
        ("Orange", .systemOrange),
        ("Yellow", .systemYellow),
        ("Green", .systemGreen),
        ("Blue", .systemBlue),
        ("Purple", .systemPurple),
        ("Pink", .systemPink),
        ("White", .white),
        ("Black", .black),
    ]

    private let defaults = UserDefaults.standard

    var isEnabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    var zoom: Double {
        get {
            let value = defaults.double(forKey: "zoom")
            return value > 0 ? value : 2
        }
        set { defaults.set(newValue, forKey: "zoom") }
    }

    /// Lens diameter in points.
    var diameter: Double {
        get {
            let value = defaults.double(forKey: "diameter")
            // Medium was 240 and Large 360 before they grew by 15% and 30%.
            switch value {
            case 240: return 276
            case 360: return 468
            case let value where value > 0: return value
            default: return 276
            }
        }
        set { defaults.set(newValue, forKey: "diameter") }
    }

    /// Draw on the screen while ⌥ Option is held by itself; ⌃ Control clears it.
    var drawsWithOption: Bool {
        get { defaults.object(forKey: "drawsWithOption") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "drawsWithOption") }
    }

    /// Name of the pen colour, one of `penColors`.
    var penColorName: String {
        get {
            let name = defaults.string(forKey: "penColor") ?? ""
            return Self.penColors.contains { $0.name == name } ? name : "Red"
        }
        set { defaults.set(newValue, forKey: "penColor") }
    }

    var penColor: NSColor { Self.penColors.first { $0.name == penColorName }?.color ?? .systemRed }

    /// Hide the mouse pointer while the lens is shown (GitHub build only). Off by default, so the pointer
    /// stays in view.
    var hidesPointer: Bool {
        get { defaults.bool(forKey: "hidesPointer") }
        set { defaults.set(newValue, forKey: "hidesPointer") }
    }

    /// Opacity of the shade over the rest of the screen; 0 is off.
    var shadeOpacity: Double {
        get { defaults.object(forKey: "shadeOpacity") as? Double ?? 0.25 }
        set { defaults.set(newValue, forKey: "shadeOpacity") }
    }
}

extension Settings {
    /// A round swatch of a pen colour, for menus and pop-up buttons.
    static func swatch(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            color.setFill()
            circle.fill()
            NSColor.separatorColor.setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
    }

    /// "2×", "1.5×".
    static func format(zoom: Double) -> String {
        zoom == zoom.rounded() ? "\(Int(zoom))×" : "\(zoom)×"
    }
}
