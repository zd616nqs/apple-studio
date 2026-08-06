import Testing
@testable import DemoNotes

struct DemoNotesSmokeTests {
    @Test func contentViewInstantiates() {
        _ = ContentView()
        #expect(true)
    }
}
