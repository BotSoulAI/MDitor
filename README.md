# MDitor

一个小巧、原生的 macOS Markdown 编辑器：左侧编辑、右侧实时预览，**编辑与预览滚动同步**，零第三方依赖，纯 SwiftUI 编写。

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## 特性

- 左右分栏：编辑 + 实时预览，同时显示时**各占一半窗口**，可一键隐藏任意一侧
- **编辑与预览滚动同步**：滚动任意一侧，另一侧跟随滚动，始终保持差不多的行位
- **打开默认是纯预览模式**，点击工具栏"编辑"按钮（或 `⌘⇧D`）打开编辑区
- 双击 Finder 中的 `.md` 文件直接打开（系统正规文档类型声明，Launch Services 认可）
- 自研 Markdown 解析器：标题、列表、任务清单、引用、代码块、表格、分隔线、粗体、斜体、行内代码、删除线、链接
- 工具栏一键插入 Markdown 语法；完整撤销/重做、`⌘F` 查找
- 一键导出排版好的 HTML；自动适配深色/浅色模式

## 截图

> TODO：添加截图

## 快速开始

### 直接运行

1. 下载 `MDitor-app.zip`，解压得到 `MDitor.app`；
2. 双击运行；拷贝到其他 Mac 若提示「无法验证开发者」，右键点图标 →「打开」→ 再次点击「打开」即可。

### 从源码构建

源码要求 Swift 5.9+ / macOS 13+。一键构建（编译 + 图标 + .app 打包 + 签名 + 测试）：

```bash
bash MDitor/scripts/build.sh
```

只运行解析器单元测试：

```bash
cd MDitor
swiftc -swift-version 5 Sources/MDitorCore/*.swift Tests/MDitorCoreTests/main.swift -o .build/tests && ./.build/tests
```

> 说明：`swift build` 在仅安装 CommandLineTools 的环境可能因清单库版本不匹配不可用，构建脚本走 `swiftc` 直编；`Package.swift` 已保留，装有完整 Xcode 的环境可直接打开构建。

## 目录结构

```
MDitor/
├── Package.swift                      # SPM 清单（供 Xcode 环境使用）
├── Sources/
│   ├── MDitorCore/                    # 纯逻辑：Markdown 块级/行内解析、HTML 导出
│   └── MDitor/                        # SwiftUI 应用层：编辑器、预览、文件读写、菜单
├── Tests/MDitorCoreTests/main.swift   # 独立断言测试（28 项，不依赖 XCTest）
├── scripts/
│   ├── build.sh                       # 一键构建脚本
│   ├── make_icon.swift                # 图标生成
│   ├── window_check.swift             # 窗口冒烟自检
│   ├── preview_scroll_check.swift      # 预览区滚动回归自检（滚到底 + 代码块上滚轮）
│   ├── lshandler.swift                # 文件类型默认应用查看/设置工具
│   └── Info.plist                     # .app 配置模板
└── resources/                         # 图标产物
```

详细使用说明见 [使用说明.md](使用说明.md)。

## 验证情况

- 编译：零错误（swiftc `-O` 发行模式，arm64）
- 单元测试：28 / 28 通过（标题、代码块、列表、任务清单、表格、引用、分隔线、段落、行内格式、HTML 导出）
- 双击打开专项验证：应用未运行时双击 → 正确加载目标文件；运行中双击 → 正确切换内容，全程单窗口
- 预览区滚动回归自检：`bash MDitor/scripts/build.sh` 后可运行 `.build/preview_check`
  （校验「连续滚轮能滚到文档底部」与「滚轮打在代码块上预览仍能滚动」两个历史 bug 不再复现）

## 许可证

[MIT](LICENSE)
