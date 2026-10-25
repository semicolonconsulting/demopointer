// Makes the app icon, DemoPointer/AppIcon.icon, from art/icon-source.png (a 1254 px render of a glossy
// teal squircle with a white ring and pointing hand).
// macOS 26 and later draw an app icon's shape, edge and shadow themselves, and put icons that bring their
// own squircle on a grey plate. So this is an Icon Composer icon: a teal gradient fill, plus one layer holding just
// the ring and hand, lifted off the render. Xcode also makes a classic .icns from it for macOS 13–15.
// Usage: swift scripts/make-icon.swift
import AppKit

let iconDir = URL(fileURLWithPath: "DemoPointer/AppIcon.icon")
let teal = (r: 0.05, g: 0.75, b: 0.79) // the render's background, sampled

// Measured in the source: the squircle's bounds, and where the ring and hand are.
let sourceBody = CGRect(x: 126, y: 114, width: 1002, height: 985)
let ringCenter = CGPoint(x: 622, y: 552)
let ringReach: CGFloat = 335 // past the ring's outer edge
let handArea = CGRect(x: 495, y: 555, width: 280, height: 480)

let source = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "art/icon-source.png")))!.cgImage!
let width = source.width, height = source.height

// Source pixels as sRGB bytes, row 0 at the top. The context owns the memory, so it's kept for the run.
let inputContext: CGContext = {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    return ctx
}()
let input = inputContext.data!.assumingMemoryBound(to: UInt8.self)

/// The ring and hand on a transparent background. Only pixels near the ring or on the hand are taken, so
/// the glossy highlights elsewhere on the render stay behind. White is told from teal by the red channel,
/// which teal has almost none of, and the teal is un-mixed from the anti-aliased edges.
let foreground: CGImage = {
    let out = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let o = out.data!.assumingMemoryBound(to: UInt8.self)
    for y in 0..<height {
        for x in 0..<width {
            let i = (y * width + x) * 4
            let inArea = hypot(CGFloat(x) - ringCenter.x, CGFloat(y) - ringCenter.y) <= ringReach
                || handArea.contains(CGPoint(x: x, y: y))
            guard inArea else { continue }
            let r = Double(input[i]) / 255, g = Double(input[i + 1]) / 255, b = Double(input[i + 2]) / 255
            // Starts above the lighter teal inside the ring (red up to about 0.22), so only the white is lifted.
            let alpha = min(max((r - 0.25) / (0.88 - 0.25), 0), 1)
            guard alpha > 0.02 else { continue }
            func unmix(_ v: Double, _ bg: Double) -> UInt8 {
                let c = min(max((v - (1 - alpha) * bg) / alpha, 0), 1)
                return UInt8(c * alpha * 255)
            }
            o[i] = unmix(r, teal.r); o[i + 1] = unmix(g, teal.g); o[i + 2] = unmix(b, teal.b)
            o[i + 3] = UInt8(alpha * 255)
        }
    }
    return out.makeImage()!
}()

/// The foreground on Icon Composer's 1024 canvas, with the render's squircle filling it edge to edge.
func layerPNG() -> Data {
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 1024 * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = 1024 / sourceBody.width
    let top = (1024 - sourceBody.height * scale) / 2
    // CGContext has a bottom-left origin; convert from the source's top-left layout.
    let rect = CGRect(x: -sourceBody.minX * scale,
                      y: 1024 - (top - sourceBody.minY * scale) - CGFloat(height) * scale,
                      width: CGFloat(width) * scale, height: CGFloat(height) * scale)
    ctx.interpolationQuality = .high
    ctx.draw(foreground, in: rect)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

// desktopcloth's gradient: blue-teal at the top to green-teal at the bottom. The layer is flat (glass and
// specular off): the render already has its own soft shading, and the system glass darkened the places
// where the hand meets the ring and the cuff.
let iconJSON = """
{
  "fill" : {
    "linear-gradient" : [
      "srgb:0.25000,0.72000,0.81000,1.00000",
      "srgb:0.11000,0.78000,0.68000,1.00000"
    ],
    "orientation" : {
      "start" : { "x" : 0.5, "y" : 0 },
      "stop" : { "x" : 0.5, "y" : 1 }
    }
  },
  "groups" : [
    {
      "layers" : [
        {
          "glass" : false,
          "image-name" : "foreground.png",
          "name" : "foreground"
        }
      ],
      "specular" : false
    }
  ],
  "supported-platforms" : {
    "squares" : [
      "macOS"
    ]
  }
}

"""

try FileManager.default.createDirectory(at: iconDir.appendingPathComponent("Assets"), withIntermediateDirectories: true)
try layerPNG().write(to: iconDir.appendingPathComponent("Assets/foreground.png"))
try iconJSON.write(to: iconDir.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
print("Wrote \(iconDir.path)")
