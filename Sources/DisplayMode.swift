import Foundation

enum DisplayMode: String, CaseIterable {
    case menuBar
    case centeredWindow

    var title: String {
        switch self {
        case .menuBar: return "菜单栏弹窗"
        case .centeredWindow: return "居中窗口"
        }
    }
}
