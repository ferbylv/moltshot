import Foundation

#if canImport(Translation)
import Translation
#endif

/// 仅在 macOS 15+ 使用 Apple Translation（离线可用，但首次可能下载语言包）。
@MainActor
final class Translator: ObservableObject {
    @Published var translated: String = ""
    @Published var isTranslating: Bool = false
    @Published var lastError: String? = nil

    @available(macOS 15.0, *)
    func makeConfig(sourceIsChinese: Bool) -> TranslationSession.Configuration {
        // Translation 使用 Foundation.Locale.Language
        let source: Locale.Language? = sourceIsChinese ? Locale.Language(identifier: "zh-Hans") : nil
        let target: Locale.Language? = sourceIsChinese ? Locale.Language(identifier: "en") : Locale.Language(identifier: "zh-Hans")
        return TranslationSession.Configuration(source: source, target: target)
    }

    func setResult(_ text: String) {
        self.translated = text
        self.isTranslating = false
        self.lastError = nil
    }

    func setError(_ err: Error) {
        self.lastError = err.localizedDescription
        self.isTranslating = false
    }
}
