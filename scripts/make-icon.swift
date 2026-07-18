import AppKit

// Genera l'icona 1024×1024 "Neon Destroyer": sfondo carbone arrotondato + fulmine
// con gradiente magenta→arancio. Salva PNG al path passato come argomento.

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no ctx") }

// Sfondo arrotondato (squircle-ish)
let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
let bgPath = CGPath(roundedRect: bgRect.insetBy(dx: 40, dy: 40),
                    cornerWidth: 220, cornerHeight: 220, transform: nil)
ctx.addPath(bgPath)
ctx.setFillColor(NSColor(calibratedRed: 0.055, green: 0.055, blue: 0.07, alpha: 1).cgColor)
ctx.fillPath()

// Bagliore radiale dietro il fulmine
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor(calibratedRed: 1, green: 0.35, blue: 0.24, alpha: 0.55).cgColor,
             NSColor(calibratedRed: 1, green: 0.35, blue: 0.24, alpha: 0).cgColor] as CFArray,
    locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: size/2, y: size/2), startRadius: 0,
    endCenter: CGPoint(x: size/2, y: size/2), endRadius: 420, options: [])

// Fulmine (bolt) come path
func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: size - y) } // y flip
let bolt = CGMutablePath()
bolt.move(to: p(560, 150))
bolt.addLine(to: p(360, 560))
bolt.addLine(to: p(500, 560))
bolt.addLine(to: p(440, 874))
bolt.addLine(to: p(680, 430))
bolt.addLine(to: p(530, 430))
bolt.closeSubpath()

ctx.saveGState()
ctx.addPath(bolt)
ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor(calibratedRed: 1, green: 0.176, blue: 0.47, alpha: 1).cgColor,
             NSColor(calibratedRed: 1, green: 0.35, blue: 0.235, alpha: 1).cgColor,
             NSColor(calibratedRed: 1, green: 0.60, blue: 0.18, alpha: 1).cgColor] as CFArray,
    locations: [0, 0.5, 1])!
ctx.drawLinearGradient(grad, start: p(360, 150), end: p(680, 874), options: [])
ctx.restoreGState()

image.unlockFocus()

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "icon_1024.png"
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("png fail") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("scritto \(outPath)")
