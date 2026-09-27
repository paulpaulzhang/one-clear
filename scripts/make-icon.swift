// 生成 Resources/AppIcon.icns：swift scripts/make-icon.swift（在项目根目录跑）
import AppKit

func renderIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 512)
    transform.concat()

    NSGradient(
        starting: NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1),
        ending: NSColor(red: 0.1, green: 0.35, blue: 0.8, alpha: 1)
    )!.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512), angle: 45)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 100, y: 100, width: 312, height: 312)).fill()
    NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 180, y: 180, width: 152, height: 152)).fill()
    NSColor(red: 1, green: 1, blue: 0.3, alpha: 0.9).setFill()
    for (x, y) in [(80.0, 80.0), (450, 100), (420, 420), (100, 400)] {
        NSBezierPath(ovalIn: NSRect(x: x - 15, y: y - 15, width: 30, height: 30)).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! renderIcon(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try! renderIcon(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Resources/AppIcon.icns 已生成" : "iconutil 失败")
