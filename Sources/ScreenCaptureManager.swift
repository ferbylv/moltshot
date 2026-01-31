import ScreenCaptureKit
import CoreMedia
import CoreImage
import AppKit

enum CaptureError: Error {
    case noDisplay
    case noFrame
    case cannotCreateImage
}

/// 使用 ScreenCaptureKit 抓取框选区域。
/// macOS 15 开始系统强制使用 ScreenCaptureKit（CoreGraphics 的 CGDisplayCreateImage/CGWindowListCreateImage 已不可用）。
actor ScreenCaptureManager {

    func captureRegion(selectionRectInScreen: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // 找到框选所在的 NSScreen
        let center = CGPoint(x: selectionRectInScreen.midX, y: selectionRectInScreen.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
        guard let screen else { throw CaptureError.noDisplay }

        // 将 NSScreenNumber 映射到 SCDisplay.displayID
        let screenNumber = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        let display = content.displays.first(where: { d in
            guard let screenNumber else { return false }
            return d.displayID == screenNumber
        }) ?? content.displays.first

        guard let display else { throw CaptureError.noDisplay }

        // selectionRectInScreen（全局 points）→ 该屏幕局部 points
        let screenFrame = screen.frame
        let localX = selectionRectInScreen.minX - screenFrame.minX
        let localY = selectionRectInScreen.minY - screenFrame.minY
        let localW = selectionRectInScreen.width
        let localH = selectionRectInScreen.height

        // 注意：在 macOS 15 的 ScreenCaptureKit 中，sourceRect 使用「以显示器为坐标系的点(point)」更符合实际表现；
        // stream 的 width/height 再用像素控制输出分辨率。
        let scale = screen.backingScaleFactor

        var cropX = localX
        var cropW = localW
        var cropH = localH

        // ScreenCaptureKit 的 sourceRect 以左上为原点（points），需要做 Y 翻转
        let cropYFromTop = screenFrame.height - (localY + localH)
        var cropY = cropYFromTop

        // clamp 到屏幕 points 范围
        let maxW = screenFrame.width
        let maxH = screenFrame.height
        cropX = max(0, min(cropX, maxW))
        cropY = max(0, min(cropY, maxH))
        cropW = max(1, min(cropW, maxW - cropX))
        cropH = max(1, min(cropH, maxH - cropY))

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.scalesToFit = false

        // 关键：直接用 sourceRect 让系统裁剪（避免我们再二次裁剪导致偏移）
        config.sourceRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        // 输出分辨率用像素控制（points * backingScaleFactor）
        config.width = Int(cropW * scale)
        config.height = Int(cropH * scale)

        let collector = FrameCollector()
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(collector, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))

        try await stream.startCapture()
        let pixelBuffer = try await collector.nextPixelBuffer(timeoutNanoseconds: 1_000_000_000)
        try await stream.stopCapture()

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw CaptureError.cannotCreateImage
        }
        return cg
    }
}

final class FrameCollector: NSObject, SCStreamOutput {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CVPixelBuffer, Error>?

    func nextPixelBuffer(timeoutNanoseconds: UInt64) async throws -> CVPixelBuffer {
        try await withThrowingTaskGroup(of: CVPixelBuffer.self) { group in
            group.addTask { [weak self] in
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CVPixelBuffer, Error>) in
                    guard let self else { return }
                    self.lock.lock(); self.continuation = cont; self.lock.unlock()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw CaptureError.noFrame
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let imageBuffer = sampleBuffer.imageBuffer else { return }
        let pb = imageBuffer as CVPixelBuffer

        lock.lock(); let cont = continuation; continuation = nil; lock.unlock()
        cont?.resume(returning: pb)
    }
}
