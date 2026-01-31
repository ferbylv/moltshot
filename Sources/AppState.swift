import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let hotKey = HotKeyManager()
    let menuBar = MenuBarController()

    let selection = SelectionOverlayWindowController()
    let capturer = ScreenCaptureManager()
    let ocr = OCRManager()
    let translator = Translator()

    private let displayModeKey = "MoltShot.DisplayMode"
    private let resultWindow = ResultWindowController()

    init() {
        menuBar.onCapture = { [weak self] in self?.startFlow() }
        hotKey.onHotKey = { [weak self] in self?.startFlow() }
        hotKey.registerDefaultHotKey()

        menuBar.getDisplayMode = { [weak self] in
            guard let self else { return .menuBar }
            return self.currentDisplayMode()
        }
        menuBar.setDisplayMode = { [weak self] mode in
            guard let self else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: self.displayModeKey)
        }
    }

    func startFlow() {
        selection.present { [weak self] selectionRectInScreen in
            guard let self else { return }
            Task { await self.runPipeline(selectionRectInScreen: selectionRectInScreen) }
        }
    }

    private func runPipeline(selectionRectInScreen: CGRect) async {
        do {
            let cgImage = try await capturer.captureRegion(selectionRectInScreen: selectionRectInScreen)
            let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: selectionRectInScreen.midX, y: selectionRectInScreen.midY)) }) ?? NSScreen.main

            let ocrText = try await ocr.recognizeText(from: cgImage)

            let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                presentResult(original: "", translated: "未识别到文字（请重新框选包含清晰文字的区域）", sourceIsChinese: false, screen: targetScreen)
                return
            }

            let sourceIsChinese = LanguageDetector.isChinese(trimmed)
            presentResult(original: trimmed, translated: "（翻译中…）", sourceIsChinese: sourceIsChinese, screen: targetScreen)
        } catch {
            if let ocrErr = error as? OCRError, ocrErr == .noResult {
                presentResult(original: "", translated: "未识别到文字（请重新框选包含清晰文字的区域）", sourceIsChinese: false, screen: nil)
            } else {
                presentResult(original: "", translated: "错误：\(error.localizedDescription)", sourceIsChinese: false, screen: nil)
            }
        }
    }

    private func currentDisplayMode() -> DisplayMode {
        if let raw = UserDefaults.standard.string(forKey: displayModeKey), let mode = DisplayMode(rawValue: raw) {
            return mode
        }
        return .menuBar
    }

    private func presentResult(original: String, translated: String, sourceIsChinese: Bool, screen: NSScreen?) {
        switch currentDisplayMode() {
        case .menuBar:
            menuBar.showResult(original: original, translated: translated, sourceIsChinese: sourceIsChinese)
        case .centeredWindow:
            resultWindow.show(original: original, translated: translated, sourceIsChinese: sourceIsChinese, screen: screen)
        }
    }
}
