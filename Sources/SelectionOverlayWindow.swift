import AppKit

final class SelectionOverlayWindowController: NSWindowController {

    private var windows: [NSWindow] = []

    func present(onSelection: @escaping (CGRect) -> Void) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        // 覆盖所有屏幕（多屏必需）
        windows = screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let view = SelectionOverlayView(frame: window.contentView?.bounds ?? .zero)
            view.autoresizingMask = [.width, .height]

            view.onComplete = { [weak self] rect in
                self?.dismissAll()
                onSelection(rect)
            }
            view.onCancel = { [weak self] in
                self?.dismissAll()
            }

            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            return window
        }

        // 兼容 NSWindowController 的 window 属性（随便挂一个）
        self.window = windows.first
    }

    private func dismissAll() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
