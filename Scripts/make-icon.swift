import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: shape inset ~10%
let inset = size * 0.1
let rect = CGRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

// Shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size*0.012), blur: size*0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill(); path.fill()
ctx.restoreGState()

// Background gradient
path.addClip()
let bg = NSGradient(colors: [NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.95, alpha: 1),
                             NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.80, alpha: 1)])!
bg.draw(in: rect, angle: -60)
// subtle top highlight
let hl = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
hl.draw(in: rect, angle: -90)

// 2x2 grid of app tiles
let tile = rect.width * 0.30
let gap = rect.width * 0.07
let gridW = tile*2 + gap
let ox = rect.midX - gridW/2
let oy = rect.midY - gridW/2 - rect.height*0.02
let tileColors: [NSColor] = [
    NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.25, alpha: 1),  // orange
    NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.55, alpha: 1), // green
    NSColor(calibratedRed: 1.0, green: 0.40, blue: 0.50, alpha: 1),  // pink
    NSColor.white.withAlphaComponent(0.92),
]
var i = 0
for row in 0..<2 {
    for col in 0..<2 {
        let r = CGRect(x: ox + CGFloat(col)*(tile+gap), y: oy + CGFloat(1-row)*(tile+gap), width: tile, height: tile)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -size*0.006), blur: size*0.015, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        tileColors[i].setFill()
        NSBezierPath(roundedRect: r, xRadius: tile*0.24, yRadius: tile*0.24).fill()
        ctx.restoreGState()
        i += 1
    }
}

// Sparkle (AI) on bottom-right tile, drawn in brand blue
func sparkle(center c: CGPoint, r: CGFloat, color: NSColor) {
    let p = NSBezierPath()
    let k: CGFloat = 0.22
    p.move(to: CGPoint(x: c.x, y: c.y + r))
    p.curve(to: CGPoint(x: c.x + r, y: c.y), controlPoint1: CGPoint(x: c.x + r*k, y: c.y + r*k), controlPoint2: CGPoint(x: c.x + r*k, y: c.y + r*k))
    p.curve(to: CGPoint(x: c.x, y: c.y - r), controlPoint1: CGPoint(x: c.x + r*k, y: c.y - r*k), controlPoint2: CGPoint(x: c.x + r*k, y: c.y - r*k))
    p.curve(to: CGPoint(x: c.x - r, y: c.y), controlPoint1: CGPoint(x: c.x - r*k, y: c.y - r*k), controlPoint2: CGPoint(x: c.x - r*k, y: c.y - r*k))
    p.curve(to: CGPoint(x: c.x, y: c.y + r), controlPoint1: CGPoint(x: c.x - r*k, y: c.y + r*k), controlPoint2: CGPoint(x: c.x - r*k, y: c.y + r*k))
    p.close()
    color.setFill(); p.fill()
}
let brTile = CGRect(x: ox + tile + gap, y: oy, width: tile, height: tile)
let blue = NSColor(calibratedRed: 0.25, green: 0.35, blue: 0.90, alpha: 1)
sparkle(center: CGPoint(x: brTile.midX - tile*0.05, y: brTile.midY + tile*0.05), r: tile*0.30, color: blue)
sparkle(center: CGPoint(x: brTile.midX + tile*0.25, y: brTile.midY - tile*0.22), r: tile*0.13, color: blue)

img.unlockFocus()
let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
