import AppKit

let args = CommandLine.arguments
guard args.count > 1 else { fatalError("output path required") }
let output = args[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.035, green: 0.043, blue: 0.060, alpha: 1).setFill()
rect.fill()

let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.36, green: 0.94, blue: 0.70, alpha: 0.28),
    NSColor(calibratedRed: 0.36, green: 0.94, blue: 0.70, alpha: 0.0)
])!
glow.draw(in: NSBezierPath(ovalIn: NSRect(x: 500, y: 510, width: 640, height: 640)), relativeCenterPosition: .zero)

let boxRect = NSRect(x: 160, y: 160, width: 704, height: 704)
let box = NSBezierPath(roundedRect: boxRect, xRadius: 120, yRadius: 120)
NSColor(calibratedRed: 0.075, green: 0.088, blue: 0.115, alpha: 0.98).setFill()
box.fill()
NSColor(calibratedRed: 0.36, green: 0.94, blue: 0.70, alpha: 0.96).setStroke()
box.lineWidth = 28
box.stroke()

let tileSize: CGFloat = 160
let tileOrigins = [
    NSPoint(x: 210, y: 210),
    NSPoint(x: 654, y: 210),
    NSPoint(x: 210, y: 654),
    NSPoint(x: 654, y: 654)
]
for origin in tileOrigins {
    let tile = NSBezierPath(
        roundedRect: NSRect(x: origin.x, y: origin.y, width: tileSize, height: tileSize),
        xRadius: 28,
        yRadius: 28
    )
    NSColor.white.withAlphaComponent(0.045).setFill()
    tile.fill()
}

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 515, weight: .black),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
("♞" as NSString).draw(in: NSRect(x: 205, y: 250, width: 614, height: 575), withAttributes: attributes)

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("could not create PNG")
}
try png.write(to: URL(fileURLWithPath: output))
