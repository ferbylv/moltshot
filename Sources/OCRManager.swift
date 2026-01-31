import Vision

enum OCRError: Error {
    case noResult
}

final class OCRManager {
    func recognizeText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                let text = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if text.isEmpty {
                    cont.resume(throwing: OCRError.noResult)
                } else {
                    cont.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // 中英混合优先（可按需再扩展）
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            // 过滤太小的“噪声文字”（按需要可调）
            request.minimumTextHeight = 0.015

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}
