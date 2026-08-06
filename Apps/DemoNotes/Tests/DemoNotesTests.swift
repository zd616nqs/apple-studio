import Testing
@testable import DemoNotes

struct NotesStoreTests {
    // mutating 调用放 #expect 外:宏会把表达式包进不可变闭包
    @Test func addTrimsAndAppends() {
        var store = NotesStore()
        let added = store.add("  买牛奶  ")
        #expect(added)
        #expect(store.notes == ["买牛奶"])
    }

    @Test func rejectsBlankAndDuplicate() {
        var store = NotesStore()
        let blankAdded = store.add("   ")
        let firstAdded = store.add("A")
        let duplicateAdded = store.add("A")
        #expect(!blankAdded)
        #expect(firstAdded)
        #expect(!duplicateAdded)
        #expect(store.notes.count == 1)
    }
}

/// spec: note-management「删除笔记」三场景的可执行形式
struct NotesStoreDeletionTests {
    // 场景:左滑删除一条笔记(顺序不变)
    @Test func removeExistingNoteKeepsOrder() {
        var store = NotesStore()
        store.add("A")
        store.add("B")
        store.add("C")
        store.remove("B")
        #expect(store.notes == ["A", "C"])
    }

    // spec 要求:删除不存在的条目无副作用
    @Test func removeMissingNoteHasNoEffect() {
        var store = NotesStore()
        store.add("A")
        store.remove("X")
        #expect(store.notes == ["A"])
    }

    // 场景:删除后可重新添加同内容(去重只针对当前存在的笔记)
    @Test func reAddAfterRemoveSucceeds() {
        var store = NotesStore()
        store.add("买牛奶")
        store.remove("买牛奶")
        let reAdded = store.add("买牛奶")
        #expect(reAdded)
        #expect(store.notes == ["买牛奶"])
    }
}

struct PingRequestBuilderTests {
    @Test func buildsQueryEncodedRequest() throws {
        let request = try PingRequestBuilder.makeSearchRequest(query: "hello world")
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasPrefix("https://example.com/search?"))
        #expect(url.contains("q=hello%20world") || url.contains("q=hello+world"))
    }
}
