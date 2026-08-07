import ProjectDescription
import ProjectDescriptionHelpers

// 共享层工程(集中声明多个 framework):多 framework target,语言隔离(红线 3:改动只走 change/modules-* 分支)
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
