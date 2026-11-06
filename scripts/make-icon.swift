import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var chunks = Data()
func bigEndian(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
let types = [16: ["icp4", "ic11"], 32: ["icp5", "ic12"], 128: ["ic07", "ic13"],
             256: ["ic08", "ic14"], 512: ["ic09", "ic10"]]
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 210, yRadius: 210)
        let gradient = NSGradient(starting: NSColor(srgbRed: 0.98, green: 0.55, blue: 0.24, alpha: 1),
                                  ending: NSColor(srgbRed: 0.84, green: 0.22, blue: 0.36, alpha: 1))!
        gradient.draw(in: background, angle: -60)
        // A keycap with caps lock's light and the hyper modifiers on it.
        let shadow = NSBezierPath(roundedRect: NSRect(x: 212, y: 200, width: 600, height: 600), xRadius: 96, yRadius: 96)
        NSColor(white: 0, alpha: 0.18).setFill()
        shadow.fill()
        let cap = NSBezierPath(roundedRect: NSRect(x: 212, y: 236, width: 600, height: 564), xRadius: 96, yRadius: 96)
        NSColor(white: 0.98, alpha: 1).setFill()
        cap.fill()
        context.setFillColor(NSColor(srgbRed: 0.35, green: 0.85, blue: 0.45, alpha: 1).cgColor)
        context.fillEllipse(in: CGRect(x: 282, y: 680, width: 52, height: 52))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let glyphs = NSAttributedString(string: "⌃⌥⌘", attributes: [
            .font: NSFont.systemFont(ofSize: 170, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0.2, green: 0.2, blue: 0.25, alpha: 1),
            .paragraphStyle: paragraph
        ])
        glyphs.draw(in: NSRect(x: 212, y: 330, width: 600, height: 230))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let png = bitmap.representation(using: .png, properties: [:])!
        try png.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
        // Modern ICNS entries contain PNG data. Write the container directly so the
        // build also works where iconutil's image conversion service is unavailable.
        chunks.append(Data(types[size]![scale - 1].utf8))
        chunks.append(bigEndian(png.count + 8))
        chunks.append(png)
    }
}
var icon = Data("icns".utf8)
icon.append(bigEndian(chunks.count + 8))
icon.append(chunks)
try icon.write(to: directory.deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))
