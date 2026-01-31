# MoltShot (截图 OCR 翻译)

功能：全局快捷键/菜单栏触发 → 框选截图 → OCR 识别 → 自动判断语言（中文→英文；其他→中文）→ 弹出结果并可一键复制。

> 你机器实际是 macOS **14.8.3**（不是 26）。下面按 macOS 14+（含 Translation 框架）实现。翻译可离线使用，但**首次可能需要系统下载离线语言包**。

## 依赖
- 需要安装 **Xcode**（当前机器只有 Command Line Tools，缺少 xcodebuild）。

## Xcode 创建工程（推荐）
1. Xcode → New Project → **App**
   - Interface: SwiftUI
   - Life Cycle: SwiftUI App
   - Deployment Target: macOS 14.0+
2. 将本目录 `Sources/` 下文件按同名分组拖进工程（勾选 Copy items）。
3. Signing & Capabilities：
   - App Sandbox ✅
     - Screen Recording ✅
     - Network (Outgoing) ✅（Translation 可能触发模型下载；离线使用时也建议保留）
4. 运行一次后在：系统设置 → 隐私与安全性 → **屏幕录制** → 勾选你的 App。

## 使用
- 默认全局热键：**⌘⇧2**
- 也可菜单栏图标 → Capture
- 框选区域后松开鼠标：弹出原文 + 译文，可复制译文。

## 下一步可增强
- 多显示器/Retina 坐标映射（现在是 MVP：主显示器为主，已做基础 scale 处理）
- 历史记录
- 自动复制译文到剪贴板/通知中心提示
- 选择翻译方向（强制中->英/英->中）
