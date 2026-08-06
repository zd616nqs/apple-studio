import Foundation

public extension String {
    /// 去首尾空白;结果为空则返回 nil
    var normalizedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
