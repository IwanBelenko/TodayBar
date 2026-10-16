// Combine native UI test captures into a README GIF. No personal data or app launch.
// Usage: swift scripts/make-demo.swift <frame-directory> <output.gif>
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct Frame: Decodable {
    let file: String
    let title: String
    let detail: String
    let seconds: Double
    let pointer: Pointer
    let move: Double
    let click: Bool
}

struct Pointer: Decodable {
    let x: Double
    let y: Double
}

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift scripts/make-demo.swift <frame-directory> <output.gif>")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let frames = try JSONDecoder().decode([Frame].self, from: Data(contentsOf: directory.appendingPathComponent("frames.json")))
precondition(!frames.isEmpty && frames.allSatisfy {
    $0.seconds.isFinite && $0.seconds >= 0.1 && $0.seconds <= 1.2 &&
    $0.move.isFinite && $0.move >= 0 && $0.move <= 1 &&
    (0...420).contains($0.pointer.x) && (0...590).contains($0.pointer.y)
})
// Expand only pointer motion/clicks to 20 fps; still holds need one GIF frame.
// No interpolation of the application itself: every UI state is a native capture.
struct Sample {
    let capture: Int
    let caption: Int
    let pointer: Pointer
    let pulse: Double?
    let seconds: Double
}
var samples: [Sample] = []
for (index, frame) in frames.enumerated() {
    let previous = frames[max(0, index - 1)].pointer
    let steps = Int((frame.move / 0.05).rounded())
    for step in 0..<steps {
        let t = Double(step + 1) / Double(steps)
        let eased = t * t * (3 - 2 * t)
        samples.append(Sample(capture: max(0, index - 1), caption: index,
            pointer: Pointer(x: previous.x + (frame.pointer.x - previous.x) * eased,
                             y: previous.y + (frame.pointer.y - previous.y) * eased),
            pulse: nil, seconds: 0.05))
    }
    let pulseSteps = frame.click ? 4 : 0
    precondition(!frame.click || frame.seconds >= 0.2)
    for step in 0..<pulseSteps {
        samples.append(Sample(capture: index, caption: index, pointer: frame.pointer,
                              pulse: Double(step) / 4, seconds: 0.05))
    }
    let hold = frame.seconds - Double(pulseSteps) * 0.05
    if hold > 0.001 {
        samples.append(Sample(capture: index, caption: index, pointer: frame.pointer, pulse: nil, seconds: hold))
    }
}
let duration = samples.reduce(0) { $0 + $1.seconds }
precondition((7...11).contains(duration), "Keep the demo short and readable")
precondition(abs(duration - frames.reduce(0) { $0 + $1.seconds + $1.move }) < 0.001)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let gif = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, samples.count, nil) else {
    fatalError("Cannot create GIF")
}
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)

let captures = frames.map { frame -> NSImage in
    guard let image = NSImage(contentsOf: directory.appendingPathComponent(frame.file)) else {
        fatalError("Missing frame: \(frame.file)")
    }
    return image
}
for (index, sample) in samples.enumerated() {
    let frame = frames[sample.caption]
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 460, pixelsHigh: 680,
              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Missing frame: \(frame.file)") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 460, height: 680)).fill()
    captures[sample.capture].draw(in: NSRect(x: 20, y: 70, width: 420, height: 590))
    let tip = NSPoint(x: 20 + sample.pointer.x, y: 660 - sample.pointer.y)
    if let pulse = sample.pulse {
        let radius = 7 + 13 * pulse
        let ring = NSBezierPath(ovalIn: NSRect(x: tip.x - radius, y: tip.y - radius,
                                              width: radius * 2, height: radius * 2))
        NSColor(calibratedWhite: 0.18, alpha: 0.12 * (1 - pulse)).setFill()
        ring.fill()
        NSColor(calibratedWhite: 1, alpha: 1 - pulse).setStroke()
        ring.lineWidth = 4
        ring.stroke()
        NSColor(calibratedWhite: 0.18, alpha: 0.8 * (1 - pulse)).setStroke()
        ring.lineWidth = 2
        ring.stroke()
    }
    // NSCursor.arrow.image can be empty in command-line AppKit. A small vector
    // pointer stays visible without a live cursor session or external assets.
    let arrow = NSBezierPath()
    arrow.move(to: tip)
    for (x, y) in [(0.0, -22.0), (6, -17), (10, -26), (14, -24), (10, -16), (18, -16)] {
        arrow.line(to: NSPoint(x: tip.x + x, y: tip.y + y))
    }
    arrow.close()
    NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
    arrow.fill()
    NSColor.white.setStroke()
    arrow.lineWidth = 1.5
    arrow.lineJoinStyle = .round
    arrow.stroke()
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    for (text, y, size, weight, gray) in [
        (frame.title, 37.0, 17.0, NSFont.Weight.medium, 0.16),
        (frame.detail, 14.0, 12.0, NSFont.Weight.regular, 0.43)
    ] {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(calibratedWhite: gray, alpha: 1),
            .paragraphStyle: paragraph
        ]).draw(in: NSRect(x: 12, y: y, width: 436, height: 24))
    }
    NSGraphicsContext.restoreGraphicsState()
    let cursorPixel = bitmap.colorAt(x: Int(tip.x) + 4, y: 680 - Int(tip.y) + 10)!
    precondition(cursorPixel.redComponent < 0.3, "The cursor must be visible in every frame")
    guard let image = bitmap.cgImage else { fatalError("Cannot render frame") }
    CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: sample.seconds,
        kCGImagePropertyGIFUnclampedDelayTime: sample.seconds
    ]] as CFDictionary)
    if index == 0, let poster = bitmap.representation(using: .png, properties: [:]) {
        try poster.write(to: output.deletingPathExtension().appendingPathExtension("png"))
    }
}
precondition(CGImageDestinationFinalize(gif), "GIF encoding failed")
let check = CGImageSourceCreateWithURL(output as CFURL, nil)!
precondition(CGImageSourceGetCount(check) == samples.count, "GIF lost frames")
print("Created \(output.lastPathComponent): \(samples.count) frames, \(duration) seconds, \(try Data(contentsOf: output).count) bytes")
