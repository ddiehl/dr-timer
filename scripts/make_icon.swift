// Generates DRTimer/Assets.xcassets/AppIcon.appiconset/icon-1024.png
// Run: swiftc -o /tmp/make_icon scripts/make_icon.swift && /tmp/make_icon <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Background: deep sky gradient
let space = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: space, colors: [
    NSColor(red: 0.04, green: 0.12, blue: 0.28, alpha: 1).cgColor,
    NSColor(red: 0.10, green: 0.32, blue: 0.62, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

let c = CGPoint(x: size / 2, y: size / 2 - 40)
let r: CGFloat = 330

// Crown button
ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(CGRect(x: c.x - 40, y: c.y + r + 8, width: 80, height: 60))
ctx.fill(CGRect(x: c.x - 70, y: c.y + r + 58, width: 140, height: 34))

// Dial
ctx.setFillColor(NSColor(red: 0.03, green: 0.08, blue: 0.20, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(34)
ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))

// Elapsed arc (amber), clockwise from 12 o'clock to 4
ctx.setStrokeColor(NSColor(red: 1.0, green: 0.72, blue: 0.1, alpha: 1).cgColor)
ctx.setLineWidth(34)
ctx.setLineCap(.round)
ctx.addArc(center: c, radius: r - 58, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi / 3, clockwise: true)
ctx.strokePath()

// Tick marks
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
for i in 0..<12 {
    let a = CGFloat(i) * .pi / 6
    let major = i % 3 == 0
    ctx.setLineWidth(major ? 16 : 9)
    ctx.setLineCap(.butt)
    let r1 = r - 100, r2 = r - (major ? 150 : 135)
    ctx.move(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
    ctx.addLine(to: CGPoint(x: c.x + cos(a) * r2, y: c.y + sin(a) * r2))
    ctx.strokePath()
}

// Airplane (SF Symbol), pointing up-right, centered on the dial
let cfg = NSImage.SymbolConfiguration(pointSize: 330, weight: .bold)
if let sym = NSImage(systemSymbolName: "airplane", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let tinted = NSImage(size: sym.size, flipped: false) { rect in
        sym.draw(in: rect)
        NSColor.white.setFill()
        rect.fill(using: .sourceAtop)
        return true
    }
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y)
    ctx.rotate(by: .pi / 2 - .pi / 3.2 - .pi / 2 + .pi / 2) // nose up-right
    ctx.rotate(by: -.pi / 2 + .pi / 2)
    tinted.draw(in: CGRect(x: -sym.size.width / 2, y: -sym.size.height / 2,
                           width: sym.size.width, height: sym.size.height))
    ctx.restoreGState()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
