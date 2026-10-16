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
}

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift scripts/make-demo.swift <frame-directory> <output.gif>")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let frames = try JSONDecoder().decode([Frame].self, from: Data(contentsOf: directory.appendingPathComponent("frames.json")))
precondition(!frames.isEmpty && frames.allSatisfy { $0.seconds >= 0.1 })
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let gif = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    fatalError("Cannot create GIF")
}
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)

for (index, frame) in frames.enumerated() {
    guard let capture = NSImage(contentsOf: directory.appendingPathComponent(frame.file)),
          let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 460, pixelsHigh: 680,
              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Missing frame: \(frame.file)") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 460, height: 680)).fill()
    capture.draw(in: NSRect(x: 20, y: 70, width: 420, height: 590))
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
    guard let image = bitmap.cgImage else { fatalError("Cannot render frame") }
    CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: frame.seconds,
        kCGImagePropertyGIFUnclampedDelayTime: frame.seconds
    ]] as CFDictionary)
    if index == 0, let poster = bitmap.representation(using: .png, properties: [:]) {
        try poster.write(to: output.deletingPathExtension().appendingPathExtension("png"))
    }
}
precondition(CGImageDestinationFinalize(gif), "GIF encoding failed")
let check = CGImageSourceCreateWithURL(output as CFURL, nil)!
precondition(CGImageSourceGetCount(check) == frames.count, "GIF lost frames")
print("Created \(output.lastPathComponent): \(frames.count) frames, \(frames.reduce(0) { $0 + $1.seconds }) seconds, \(try Data(contentsOf: output).count) bytes")
