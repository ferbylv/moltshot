import SwiftUI
import AppKit

#if canImport(Translation)
import Translation
#endif

struct ResultPopoverView: View {
    let original: String
    let translated: String
    let sourceIsChinese: Bool

    @StateObject private var translator = Translator()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OCR").font(.headline)
            Text(original.isEmpty ? "(empty)" : original)
                .font(.system(size: 12))
                .textSelection(.enabled)
                .frame(maxWidth: 360, alignment: .leading)

            Divider()

            Text("Translation").font(.headline)

            Group {
                if let err = translator.lastError {
                    Text("翻译失败：\(err)")
                } else if translator.isTranslating {
                    Text("翻译中…")
                } else if !translator.translated.isEmpty {
                    Text(translator.translated)
                } else {
                    Text(translated)
                }
            }
            .font(.system(size: 12))
            .textSelection(.enabled)
            .frame(maxWidth: 360, alignment: .leading)

            HStack {
                Button("Copy Translation") {
                    let textToCopy = translator.translated.isEmpty ? translated : translator.translated
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 380)
        .onAppear {
            // 如果 OCR 为空，直接提示，不触发翻译（否则会得到 Translation Request Empty）。
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
}

// MARK: - TranslationTask bridge

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
                            // translate single string
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
