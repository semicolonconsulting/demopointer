import Foundation

/// User preferences, persisted in UserDefaults.
final class Settings {
    static let shared = Settings()

    static let zoomLevels: [Double] = [1.5, 2, 3, 4]
    static let sizes: [(name: String, diameter: Double)] = [
        ("Small", 160),
        ("Medium", 240),
        ("Large", 360),
    ]
    /// How dark the rest of the screen gets while the lens is shown.
    static let shades: [(name: String, opacity: Double)] = [
        ("Off", 0),
        ("Light", 0.25),
        ("Medium", 0.45),
        ("Dark", 0.65),
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
            return value > 0 ? value : 240
        }
        set { defaults.set(newValue, forKey: "diameter") }
    }

    /// Opacity of the shade over the rest of the screen; 0 is off.
    var shadeOpacity: Double {
        get { defaults.object(forKey: "shadeOpacity") as? Double ?? 0.25 }
        set { defaults.set(newValue, forKey: "shadeOpacity") }
    }
}

extension Settings {
    /// "2×", "1.5×".
    static func format(zoom: Double) -> String {
        zoom == zoom.rounded() ? "\(Int(zoom))×" : "\(zoom)×"
    }
}
