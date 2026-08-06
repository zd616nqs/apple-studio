import DesignKit
import SwiftUI

struct ContentView: View {
    @State private var store: NotesStore = {
        var seeded = NotesStore()
        seeded.add("买牛奶")
        seeded.add("给 LegacyCore 写移植笔记")
        return seeded
    }()
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.notes, id: \.self) { note in
                        HStack {
                            Text(note)
                            Spacer()
                            TagChip("demo")
                        }
                    }
                    .onDelete { offsets in
                        for note in offsets.map({ store.notes[$0] }) {
                            store.remove(note)
                        }
                    }
                }
                Section {
                    SnapKitBannerView(text: "SnapKit + Alamofire 已接线(见 PingRequestBuilder)")
                        .frame(height: 36)
                }
            }
            .navigationTitle("DemoNotes")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("新笔记", text: $draft)
                        .textFieldStyle(.roundedBorder)
                    Button("添加") {
                        if store.add(draft) { draft = "" }
                    }
                }
                .padding()
                .background(.bar)
            }
        }
    }
}

#Preview {
    ContentView()
}
