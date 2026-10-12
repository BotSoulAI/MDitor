import CoreGraphics
import Foundation

// 无权限的窗口冒烟测试：列出 MDitor 进程在屏窗口
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var found = 0
for w in list {
    guard let owner = w[kCGWindowOwnerName as String] as? String, owner == "MDitor" else { continue }
    let pid = w[kCGWindowOwnerPID as String] as? Int ?? -1
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    let number = w[kCGWindowNumber as String] as? Int ?? -1
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Double ?? 0
    let height = bounds["Height"] as? Double ?? 0
    let name = w[kCGWindowName as String] as? String ?? "(名称需录屏权限)"
    print("WINDOW #\(number) pid=\(pid) layer=\(layer) size=\(Int(width))x\(Int(height)) title=\(name)")
    found += 1
}
print(found > 0 ? "RESULT: \(found) window(s) found" : "RESULT: no window found")
exit(found > 0 ? 0 : 1)
