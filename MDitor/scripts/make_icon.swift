import AppKit

// 生成应用图标：indigo 圆角底 + 白色 "MD"，输出 1024x1024 PNG
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedRed: 0.35, green: 0.42, blue: 0.95, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 200, yRadius: 200).fill()

let text = "MD" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 400, weight: .heavy),
    .foregroundColor: NSColor.white,
]
let textSize = text.size(withAttributes: attrs)
let point = NSPoint(x: (1024 - textSize.width) / 2, y: (1024 - textSize.height) / 2)
text.draw(at: point, withAttributes: attrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("icon generation failed\n", stderr)
    exit(1)
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("icon written: \(outPath)")
