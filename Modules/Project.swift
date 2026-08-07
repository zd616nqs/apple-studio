import ProjectDescription
import ProjectDescriptionHelpers

// 共享层工程:集中声明多个 framework，并保持 Swift/Objective-C target 边界。
let project = Project(
    name: "Modules",
    targets: [
        Studio.module(name: "FoundationKit", lang: .swift),
        Studio.module(
            name: "DesignKit",
            lang: .swift,
            dependencies: [.target(name: "FoundationKit")]
        ),
        Studio.module(name: "LegacyCore", lang: .objc),
    ]
)
