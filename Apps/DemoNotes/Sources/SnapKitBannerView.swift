import SnapKit
import SwiftUI
import UIKit

/// SnapKit 接线的活范例:SwiftUI 容器内用约束 DSL 摆 UIKit 视图
struct SnapKitBannerView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
