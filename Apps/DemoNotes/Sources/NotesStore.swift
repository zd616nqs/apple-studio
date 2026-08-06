import Foundation

/// 内存笔记存储:demo 里可测业务逻辑的最小样例
struct NotesStore {
    private(set) var notes: [String] = []

    /// 去首尾空白后追加;空白串与重复串忽略。返回是否真的加入
    @discardableResult
    mutating func add(_ raw: String) -> Bool {
        let note = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, !notes.contains(note) else { return false }
        notes.append(note)
        return true
    }
}
