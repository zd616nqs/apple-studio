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

struct PingRequestBuilderTests {
    @Test func buildsQueryEncodedRequest() throws {
        let request = try PingRequestBuilder.makeSearchRequest(query: "hello world")
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasPrefix("https://example.com/search?"))
        #expect(url.contains("q=hello%20world") || url.contains("q=hello+world"))
    }
}
