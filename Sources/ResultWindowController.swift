import AppKit
import SwiftUI

@MainActor
final class ResultWindowController {
    private var window: NSWindow?

    func show(original: String, translated: String, sourceIsChinese: Bool, screen: NSScreen?) {
        let view = ResultWindowView(original: original, translated: translated, sourceIsChinese: sourceIsChinese) {
            self.close()
        }

        let host = NSHostingController(rootView: view)

        let w: NSWindow
        if let existing = window {
            w = existing
            w.contentViewController = host
        } else {
            w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.title = "熔译"
            w.isReleasedWhenClosed = false
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.contentViewController = host
            self.window = w
        }

        // 居中到指定屏幕（默认跟随框选所在屏幕）
        if let screen {
            let vf = screen.visibleFrame
            let size = w.frame.size
            let origin = CGPoint(
                x: vf.midX - size.width / 2,
                y: vf.midY - size.height / 2
            )
            w.setFrameOrigin(origin)
        } else {
            w.center()
        }

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.orderOut(nil)
    }
}

private struct ResultWindowView: View {
    let original: String
    let translated: String
    let sourceIsChinese: Bool
    let onClose: () -> Void

    @StateObject private var translator = Translator()
    @StateObject private var sync = ScrollSync()

    @State private var selectedOriginal: String = ""
    @State private var selectedTranslated: String = ""

    private var translationText: String {
        if let err = translator.lastError {
            return "翻译失败：\(err)"
        }
        if translator.isTranslating {
            return "翻译中…"
        }
        if !translator.translated.isEmpty {
            return translator.translated
        }
        return translated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("熔译").font(.headline)
                Spacer()
                Button("关闭") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            // 双栏对照 + 联动滚动
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OCR").font(.headline)
                    SyncedTextView(
                        text: original.isEmpty ? "(empty)" : original,
                        isEditable: false,
                        sync: sync,
                        selectedText: $selectedOriginal
                    )
                    .frame(minHeight: 260)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Translation").font(.headline)
                    SyncedTextView(
                        text: translationText,
                        isEditable: false,
                        sync: sync,
                        selectedText: $selectedTranslated
                    )
                    .frame(minHeight: 260)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button("复制译文") { copyTranslation() }
                    .keyboardShortcut("c", modifiers: [.command])
                Button("复制原文") { copyOriginal() }
                Button("全部复制") { copyAll() }
                Spacer()
            }
        }
        .padding(16)
        .frame(minWidth: 860, minHeight: 420)
        .onAppear {
            if original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                translator.isTranslating = false
                translator.translated = "未识别到文字（请重新框选包含清晰文字的区域）"
                translator.lastError = nil
                return
            }
            if #available(macOS 15.0, *) {
                translator.isTranslating = true
            } else {
                translator.translated = "需要 macOS 15+ 才支持系统离线翻译"
            }
        }
        .moltTranslationTask(original: original, sourceIsChinese: sourceIsChinese, translator: translator)
    }

    private func copyTranslation() {
        let textToCopy = translator.translated.isEmpty ? translated : translator.translated
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)
    }

    private func copyOriginal() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(original, forType: .string)
    }

    private func copyAll() {
        let t = translator.translated.isEmpty ? translated : translator.translated
        let combined = original.isEmpty ? t : (original + "\n\n" + t)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(combined, forType: .string)
    }
}

private extension View {
    @ViewBuilder
    func moltTranslationTask(original: String, sourceIsChinese: Bool, translator: Translator) -> some View {
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                self
            } else {
                self
                    .translationTask(translator.makeConfig(sourceIsChinese: sourceIsChinese)) { session in
                        do {
                            let response = try await session.translate(trimmed)
                            translator.setResult(response.targetText)
                        } catch {
                            translator.setError(error)
                        }
                    }
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
