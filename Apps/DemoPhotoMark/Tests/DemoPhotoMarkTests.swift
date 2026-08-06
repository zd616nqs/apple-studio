import LegacyCore
import Testing
import UIKit
@testable import DemoPhotoMark

/// Swift Testing 测共享 ObjC 模块(module import 链路)
struct LegacyCoreFromSwiftTests {
    @Test func sanitizeCollapsesWhitespace() {
        #expect(LGCStringSanitizer.sanitize("  hello   world ") == "hello world")
    }

    @Test func sanitizeReturnsEmptyForBlank() {
        #expect(LGCStringSanitizer.sanitize("   ") == "")
    }
}

/// Swift Testing 测 app 内 ObjC 类(测试 target 桥接头链路)
struct WatermarkRendererTests {
    @Test func normalizedCaptionUsesSharedSanitizer() {
        #expect(PMWatermarkRenderer.normalizedCaption("  Demo   PhotoMark ") == "Demo PhotoMark")
    }

    @Test func imageIsNilForBlankText() {
        #expect(PMWatermarkRenderer.image(withText: "   ", size: CGSize(width: 10, height: 10)) == nil)
    }

    @Test func imageRendersAtRequestedSize() throws {
        let size = CGSize(width: 120, height: 40)
        let image = try #require(PMWatermarkRenderer.image(withText: "mark", size: size))
        #expect(image.size == size)
    }
}
