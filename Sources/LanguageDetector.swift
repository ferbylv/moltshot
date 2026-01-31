import NaturalLanguage

enum LanguageDetector {
    static func isChinese(_ text: String) -> Bool {
        // 快速判断：含汉字
        if text.range(of: #"\p{Script=Han}"#, options: .regularExpression) != nil {
            return true
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let lang = recognizer.dominantLanguage
        return lang == .simplifiedChinese || lang == .traditionalChinese
    }
}
