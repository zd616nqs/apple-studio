// swift-tools-version: 6.0
// 全仓唯一的三方依赖声明点(单一版本策略)。
// app / 模块侧只允许用 .external(name:) 引用这里声明的产物。
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings(
    productTypes: [:]
)
#endif

let package = Package(
    name: "AppleStudioDependencies",
    dependencies: [
        // ticket 02: Alamofire / SnapKit(Swift)、SDWebImage / MBProgressHUD(ObjC)
    ]
)
