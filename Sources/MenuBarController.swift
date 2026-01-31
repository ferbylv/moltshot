import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    var onCapture: (() -> Void)?

    // 由 AppState 注入：读取/切换显示模式
    var getDisplayMode: (() -> DisplayMode)?
    var setDisplayMode: ((DisplayMode) -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    private weak var modeMenu: NSMenu?

    override init() {
        super.init()

        if let button = statusItem.button {
            button.title = "熔"
        }

        let menu = NSMenu()
        menu.delegate = self

        let captureItem = NSMenuItem(title: "截图翻译", action: #selector(capture), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        // 显示模式子菜单
        let modeItem = NSMenuItem(title: "显示模式", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.addItem(NSMenuItem(title: DisplayMode.menuBar.title, action: #selector(setModeMenuBar), keyEquivalent: ""))
        sub.addItem(NSMenuItem(title: DisplayMode.centeredWindow.title, action: #selector(setModeWindow), keyEquivalent: ""))
        sub.items.forEach { $0.target = self }
        modeItem.submenu = sub
        menu.addItem(modeItem)
        self.modeMenu = sub

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        popover.behavior = .transient
    }

    func showResult(original: String, translated: String, sourceIsChinese: Bool) {
        let view = ResultPopoverView(original: original, translated: translated, sourceIsChinese: sourceIsChinese)
        popover.contentViewController = NSHostingController(rootView: view)

        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        let mode = getDisplayMode?() ?? .menuBar
        modeMenu?.items.forEach { $0.state = .off }
        switch mode {
        case .menuBar:
            modeMenu?.items.first?.state = .on
        case .centeredWindow:
            modeMenu?.items.dropFirst().first?.state = .on
        }
    }

    // MARK: - Actions

    @objc private func capture() { onCapture?() }

    @objc private func setModeMenuBar() {
        setDisplayMode?(.menuBar)
        menuWillOpen(statusItem.menu ?? NSMenu())
    }

    @objc private func setModeWindow() {
        setDisplayMode?(.centeredWindow)
        menuWillOpen(statusItem.menu ?? NSMenu())
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
