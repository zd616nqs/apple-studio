import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("DemoNotes — apple-studio 纯 Swift 活范例")
            }
            .navigationTitle("DemoNotes")
        }
    }
}

#Preview {
    ContentView()
}
