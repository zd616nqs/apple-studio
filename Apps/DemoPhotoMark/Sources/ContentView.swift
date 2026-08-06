import LegacyCore
import SwiftUI

// Swift → 共享 ObjC 模块(module import,无桥接头):LGCStringSanitizer
// Swift → 本 target ObjC(桥接头):PMWatermarkRenderer / PMRemotePhotoView
struct ContentView: View {
    private let caption = LGCStringSanitizer.sanitize("  Demo   PhotoMark  ")

    var body: some View {
        NavigationStack {
            List {
                Section("水印(本 target ObjC 渲染,内部自清洗)") {
                    if let image = PMWatermarkRenderer.image(
                        withText: "  Demo   PhotoMark  ",
                        size: CGSize(width: 300, height: 80)
                    ) {
                        Image(uiImage: image)
                    }
                }
                Section("远程图(ObjC + SDWebImage + MBProgressHUD)") {
                    RemotePhotoView(url: URL(string: "https://picsum.photos/300/200")!)
                        .frame(height: 200)
                }
            }
            .navigationTitle(caption)
        }
    }
}

private struct RemotePhotoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PMRemotePhotoView {
        let view = PMRemotePhotoView()
        view.loadPhoto(with: url)
        return view
    }

    func updateUIView(_ uiView: PMRemotePhotoView, context: Context) {}
}
