import AppKit

let args = CommandLine.arguments
guard args.count > 1 else { fatalError("output path required") }
let output = args[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1),
    NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.20, alpha: 1),
    NSColor(calibratedRed: 0.13, green: 0.55, blue: 0.46, alpha: 1)
])!
gradient.draw(in: rect, angle: -45)

let glow = NSBezierPath(ovalIn: NSRect(x: 610, y: 590, width: 360, height: 360))
NSColor(calibratedRed: 0.42, green: 1.0, blue: 0.77, alpha: 0.16).setFill()
glow.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 590, weight: .black),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
let symbol = "♞" as NSString
symbol.draw(in: NSRect(x: 80, y: 165, width: 864, height: 680), withAttributes: attributes)

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("could not create PNG")
}
try png.write(to: URL(fileURLWithPath: output))
