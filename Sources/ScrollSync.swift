import Foundation
import CoreGraphics

final class ScrollSync: ObservableObject {
    /// 0...1
    @Published var fraction: CGFloat = 0

    /// Prevent feedback loops while programmatically scrolling.
    var isProgrammaticUpdate = false
}
