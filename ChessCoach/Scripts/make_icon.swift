import AppKit

// Native vector-drawn icon inspired by ChessCoach's approved dark navy/gold visual system.
// All geometry stays editable and is rendered directly at App Store size (1024x1024).
guard CommandLine.arguments.count > 1 else { fatalError("output path required") }
let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

let background = NSBezierPath(rect: NSRect(origin: .zero, size: size))
NSGradient(colors: [
    NSColor(calibratedRed: 0.075, green: 0.15, blue: 0.25, alpha: 1),
    NSColor(calibratedRed: 0.045, green: 0.075, blue: 0.14, alpha: 1)
])!.draw(in: background, angle: 92)

let gold = NSColor(calibratedRed: 0.98, green: 0.77, blue: 0.38, alpha: 1)
let lightGold = NSColor(calibratedRed: 1, green: 0.87, blue: 0.55, alpha: 1)
let darkCutout = NSColor(calibratedRed: 0.055, green: 0.11, blue: 0.18, alpha: 1)

let base = NSBezierPath(roundedRect: NSRect(x: 267, y: 220, width: 496, height: 73), xRadius: 19, yRadius: 19)
gold.setFill()
base.fill()

// Horse-shaped knight in the same controlled flat vector language as the feature tiles.
let knight = NSBezierPath()
knight.move(to: NSPoint(x: 322, y: 295))
knight.curve(to: NSPoint(x: 420, y: 445), controlPoint1: NSPoint(x: 337, y: 376), controlPoint2: NSPoint(x: 378, y: 411))
knight.curve(to: NSPoint(x: 456, y: 535), controlPoint1: NSPoint(x: 482, y: 474), controlPoint2: NSPoint(x: 480, y: 508))
knight.curve(to: NSPoint(x: 370, y: 511), controlPoint1: NSPoint(x: 429, y: 512), controlPoint2: NSPoint(x: 402, y: 508))
knight.curve(to: NSPoint(x: 264, y: 534), controlPoint1: NSPoint(x: 320, y: 506), controlPoint2: NSPoint(x: 279, y: 505))
knight.curve(to: NSPoint(x: 239, y: 585), controlPoint1: NSPoint(x: 239, y: 549), controlPoint2: NSPoint(x: 226, y: 571))
knight.curve(to: NSPoint(x: 273, y: 624), controlPoint1: NSPoint(x: 252, y: 608), controlPoint2: NSPoint(x: 263, y: 617))
knight.line(to: NSPoint(x: 427, y: 751))
knight.line(to: NSPoint(x: 465, y: 717))
knight.line(to: NSPoint(x: 524, y: 768))
knight.curve(to: NSPoint(x: 643, y: 686), controlPoint1: NSPoint(x: 582, y: 762), controlPoint2: NSPoint(x: 625, y: 733))
knight.curve(to: NSPoint(x: 679, y: 575), controlPoint1: NSPoint(x: 660, y: 651), controlPoint2: NSPoint(x: 674, y: 616))
knight.curve(to: NSPoint(x: 617, y: 455), controlPoint1: NSPoint(x: 682, y: 523), controlPoint2: NSPoint(x: 652, y: 486))
knight.curve(to: NSPoint(x: 658, y: 295), controlPoint1: NSPoint(x: 594, y: 397), controlPoint2: NSPoint(x: 628, y: 338))
knight.close()
gold.setFill()
knight.fill()

// A restrained darker mane cutout; no gradients, fake bevels, or noise.
let mane = NSBezierPath()
mane.move(to: NSPoint(x: 552, y: 738))
mane.curve(to: NSPoint(x: 630, y: 583), controlPoint1: NSPoint(x: 622, y: 702), controlPoint2: NSPoint(x: 632, y: 638))
mane.curve(to: NSPoint(x: 566, y: 484), controlPoint1: NSPoint(x: 633, y: 541), controlPoint2: NSPoint(x: 603, y: 507))
mane.curve(to: NSPoint(x: 586, y: 630), controlPoint1: NSPoint(x: 592, y: 523), controlPoint2: NSPoint(x: 598, y: 579))
mane.close()
darkCutout.setFill()
mane.fill()

let eye = NSBezierPath(ovalIn: NSRect(x: 365, y: 628, width: 24, height: 13))
darkCutout.setFill()
eye.fill()

let smile = NSBezierPath()
smile.move(to: NSPoint(x: 284, y: 561))
smile.curve(to: NSPoint(x: 379, y: 560), controlPoint1: NSPoint(x: 316, y: 536), controlPoint2: NSPoint(x: 349, y: 541))
smile.lineWidth = 12
smile.lineCapStyle = .round
darkCutout.setStroke()
smile.stroke()

// Small distinct crown, as in the approved brand icon.
let crown = NSBezierPath()
crown.move(to: NSPoint(x: 390, y: 782))
crown.line(to: NSPoint(x: 413, y: 844))
crown.line(to: NSPoint(x: 465, y: 805))
crown.line(to: NSPoint(x: 508, y: 862))
crown.line(to: NSPoint(x: 551, y: 805))
crown.line(to: NSPoint(x: 603, y: 844))
crown.line(to: NSPoint(x: 621, y: 782))
crown.close()
lightGold.setFill()
crown.fill()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render 1024px app icon")
}
try png.write(to: URL(fileURLWithPath: output))
