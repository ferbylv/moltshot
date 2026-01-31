import AppKit
import SwiftUI
import Combine

/// NSTextView wrapped for SwiftUI with:
/// - selection reporting
/// - synchronized vertical scrolling via ScrollSync (fraction-based)
struct SyncedTextView: NSViewRepresentable {
    let text: String
    let isEditable: Bool
    let sync: ScrollSync
    @Binding var selectedText: String

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: .zero)
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator
        textView.string = text

        // Make it behave like a normal scrollable, wrapping text view
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView

        // Observe scroll changes
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.contentViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView

        // Observe sync changes
        sync.$fraction
            .receive(on: RunLoop.main)
            .sink { [weak coord = context.coordinator] newFraction in
                coord?.applySyncFraction(newFraction)
            }
            .store(in: &context.coordinator.cancellables)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != text {
            tv.string = text
        }
        tv.isEditable = isEditable

        // Keep wrapping width in sync with the current scroll view width
        tv.textContainer?.containerSize = NSSize(width: nsView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: SyncedTextView
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?

        var cancellables: Set<AnyCancellable> = []

        init(parent: SyncedTextView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let range = tv.selectedRange()
            if range.length > 0, let str = tv.string as NSString? {
                parent.selectedText = str.substring(with: range)
            } else {
                parent.selectedText = ""
            }
        }

        @objc func contentViewBoundsDidChange(_ note: Notification) {
            guard let sv = scrollView,
                  let doc = sv.documentView else { return }

            if parent.sync.isProgrammaticUpdate { return }

            let visible = sv.contentView.bounds
            let docH = doc.bounds.height
            let visH = visible.height
            let maxOffset = max(1, docH - visH)
            let offsetY = visible.origin.y
            let fraction = max(0, min(1, offsetY / maxOffset))

            parent.sync.isProgrammaticUpdate = true
            parent.sync.fraction = fraction
            parent.sync.isProgrammaticUpdate = false
        }

        func applySyncFraction(_ fraction: CGFloat) {
            guard let sv = scrollView,
                  let doc = sv.documentView else { return }

            // Avoid fighting the scroll that triggered the sync update.
            if parent.sync.isProgrammaticUpdate { return }

            let docH = doc.bounds.height
            let visH = sv.contentView.bounds.height
            let maxOffset = max(0, docH - visH)
            let targetY = max(0, min(maxOffset, maxOffset * fraction))

            parent.sync.isProgrammaticUpdate = true
            sv.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            sv.reflectScrolledClipView(sv.contentView)
            parent.sync.isProgrammaticUpdate = false
        }
    }
}
