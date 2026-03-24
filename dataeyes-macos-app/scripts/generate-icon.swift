import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 2 else {
    fputs("usage: generate-icon.swift <output-directory>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: args[1], isDirectory: true)
let fileManager = FileManager.default
try? fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

let sizes = [16, 32, 64, 128, 256, 512, 1024]

func render(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04),
                          xRadius: CGFloat(size) * 0.22,
                          yRadius: CGFloat(size) * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.31, blue: 0.78, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.61, blue: 0.86, alpha: 1)
    ])!
    gradient.draw(in: bg, angle: -55)

    let glow = NSBezierPath(ovalIn: NSRect(
        x: CGFloat(size) * 0.14,
        y: CGFloat(size) * 0.52,
        width: CGFloat(size) * 0.72,
        height: CGFloat(size) * 0.28
    ))
    NSColor(calibratedWhite: 1, alpha: 0.14).setFill()
    glow.fill()

    let badgeRect = NSRect(
        x: CGFloat(size) * 0.18,
        y: CGFloat(size) * 0.18,
        width: CGFloat(size) * 0.64,
        height: CGFloat(size) * 0.64
    )
    let badge = NSBezierPath(roundedRect: badgeRect,
                             xRadius: CGFloat(size) * 0.16,
                             yRadius: CGFloat(size) * 0.16)
    NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
    badge.fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let text = "DE" as NSString
    let fontSize = CGFloat(size) * 0.28
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    let textRect = NSRect(
        x: badgeRect.origin.x,
        y: badgeRect.origin.y + CGFloat(size) * 0.13,
        width: badgeRect.width,
        height: fontSize * 1.4
    )
    text.draw(in: textRect, withAttributes: attributes)

    image.unlockFocus()
    return image
}

func writePNG(image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try data.write(to: url)
}

for size in sizes {
    let image = render(size: size)
    let base = outputDir.appendingPathComponent("icon_\(size)x\(size).png")
    try writePNG(image: image, to: base)
    if size <= 512 {
        let retina = outputDir.appendingPathComponent("icon_\(size)x\(size)@2x.png")
        try writePNG(image: render(size: size * 2), to: retina)
    }
}
