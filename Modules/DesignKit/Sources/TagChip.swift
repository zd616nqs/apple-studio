import FoundationKit
import SwiftUI

/// 标签胶囊:DesignKit → FoundationKit 模块间依赖的示例
public struct TagChip: View {
    private let text: String

    public init(_ raw: String) {
        self.text = raw.normalizedOrNil ?? "—"
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(StudioTheme.accent.opacity(0.15), in: Capsule())
    }
}
