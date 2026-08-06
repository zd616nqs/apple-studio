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
        // Swift 库
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.10.2"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", exact: "5.7.1"),
        // ObjC 库
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", exact: "5.21.1"),
        .package(url: "https://github.com/jdg/MBProgressHUD.git", exact: "1.2.0"),
    ]
)
