import CoreServices
import Foundation
import UniformTypeIdentifiers

// 查看 / 设置 md（及其他文件类型）的默认打开应用
// 用法：
//   lshandler <文件路径>            只查看当前默认应用
//   lshandler <文件路径> set        把该文件类型的默认应用设为 MDitor (com.mditor.app)
let args = CommandLine.arguments
guard args.count >= 2 else {
    print("用法: lshandler <文件路径> [set]")
    exit(2)
}

let url = URL(fileURLWithPath: args[1])

// 1. 按文件 URL 查当前默认应用
var appURL: Unmanaged<CFURL>?
let err = LSGetApplicationForURL(url as CFURL, .all, nil, &appURL)
if err == noErr, let app = appURL {
    print("URL默认应用: \((app.takeRetainedValue() as URL).path)")
} else {
    print("URL默认应用: 无 (err=\(err))")
}

// 2. 查 UTI 及该类型的默认 handler
if let uti = UTType(filenameExtension: url.pathExtension.lowercased()) {
    print("文件类型(UTI): \(uti.identifier)")
    if let handler = LSCopyDefaultRoleHandlerForContentType(uti.identifier as CFString, .editor) {
        print("该类型默认应用(bundle id): \(handler.takeRetainedValue())")
    } else {
        print("该类型默认应用: 无")
    }

    // 2.5 列出系统认为能打开该文件的所有应用（验证系统是否认可）
    if let apps = LSCopyApplicationURLsForURL(url as CFURL, .all)?.takeRetainedValue() as? [URL] {
        print("系统认可的打开应用:")
        for app in apps {
            print("  - \(app.path)")
        }
    } else {
        print("系统认可的打开应用: 无")
    }

    // 3. 设置默认应用为 MDitor
    if args.count >= 3, args[2] == "set" {
        let result = LSSetDefaultRoleHandlerForContentType(
            uti.identifier as CFString, .editor, "com.mditor.app" as CFString
        )
        print("设置结果: err=\(result) (\(result == noErr ? "成功" : "失败"))")
    }
} else {
    print("无法识别该文件的类型")
}
