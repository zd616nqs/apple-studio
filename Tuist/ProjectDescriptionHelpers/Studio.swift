import ProjectDescription

/// 全仓工程工厂:新 app = 调一次 Studio.app() + 填空。
/// 约定优先于配置:Sources/**、Resources/**、Tests/** 目录结构固定。
public enum Studio {
    /// 部署目标策略:最新-2 个大版本。per-app 可用 deploymentTargets 参数覆盖。
    public static let iOSDeploymentTarget = "18.0"
    public static let macOSDeploymentTarget = "15.0"
    public static let bundleIDPrefix = "com.yourstudio"

    /// 混编质量检查(app 与共享模块共用一份,防两处漂移):
    /// nullability 不规范 —— 包括头文件整体缺注解 —— 直接编译失败,不靠自觉
    private static let objcQualityGate: SettingsDictionary = [
        "CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION": "YES_ERROR",
        "OTHER_CFLAGS": ["$(inherited)", "-Werror=nullability-completeness"],
    ]

    /// 共享模块依赖的唯一写法(路径集中,app 侧不散落相对路径)
    public static func sharedModule(_ name: String) -> TargetDependency {
        .project(target: name, path: .relativeToRoot("Modules"))
    }

    /// 在既有 OTHER_LDFLAGS(无论 string/array/未设置)上追加 -ObjC,绝不覆盖丢弃
    private static func appendingObjCLinkerFlag(to current: SettingValue?) -> SettingValue {
        switch current {
        case .array(let flags):
            return flags.contains("-ObjC") ? .array(flags) : .array(flags + ["-ObjC"])
        case .string(let flags):
            return flags.contains("-ObjC") ? .string(flags) : .array([flags, "-ObjC"])
        default:
            return .array(["$(inherited)", "-ObjC"])
        }
    }

    /// 只为 destinations 里实际存在的平台声明部署目标(声明多余平台会被 Tuist lint 拦下)
    private static func defaultDeploymentTargets(for destinations: Destinations) -> DeploymentTargets {
        let wantsIOS = !destinations.isDisjoint(with: [.iPhone, .iPad, .macCatalyst, .macWithiPadDesign])
        let wantsMacOS = destinations.contains(.mac)
        return .multiplatform(
            iOS: wantsIOS ? iOSDeploymentTarget : nil,
            macOS: wantsMacOS ? macOSDeploymentTarget : nil
        )
    }

    public static func app(
        name: String,
        destinations: Destinations = [.iPhone, .iPad],
        dependencies: [TargetDependency] = [],
        hasObjC: Bool = false,
        extensions: [Target] = [],
        infoPlist: [String: Plist.Value] = [:],
        entitlements: Entitlements? = nil,
        deploymentTargets: DeploymentTargets? = nil,
        includeUITests: Bool = false,
        settings: SettingsDictionary = [:]
    ) -> Project {
        let bundleID = "\(bundleIDPrefix).\(name)"
        let resolvedDeploymentTargets = deploymentTargets ?? defaultDeploymentTargets(for: destinations)

        var basePlist: [String: Plist.Value] = [
            "UILaunchScreen": ["UIColorName": "", "UIImageName": ""],
        ]
        basePlist.merge(infoPlist) { _, custom in custom }

        // ObjC 密集 target 先走 Swift 5 语言模式渐进迁移;纯 Swift 新代码一律 6
        let languageMode: SettingValue = hasObjC ? "5.0" : "6.0"
        var baseSettings: SettingsDictionary = [
            "SWIFT_VERSION": languageMode,
        ]
        if hasObjC {
            baseSettings.merge(objcQualityGate) { _, gate in gate }
            // app target 内混编约定:Swift 看本 target 的 ObjC 靠桥接头(固定路径);
            // 消费共享 ObjC 模块仍走 module import,与桥接头无关
            baseSettings["SWIFT_OBJC_BRIDGING_HEADER"] = "Sources/BridgingHeader.h"
        }
        baseSettings.merge(settings) { _, custom in custom }
        if hasObjC {
            // SPM 静态库里的 ObjC category 不被显式引用就会被 linker 丢弃,
            // 缺 -ObjC 时编译全绿、运行期 unrecognized selector。
            // 放在 custom merge 之后追加:app 自带 OTHER_LDFLAGS 也不许丢掉 -ObjC
            baseSettings["OTHER_LDFLAGS"] = appendingObjCLinkerFlag(to: baseSettings["OTHER_LDFLAGS"])
        }

        let appTarget = Target.target(
            name: name,
            destinations: destinations,
            product: .app,
            bundleId: bundleID,
            deploymentTargets: resolvedDeploymentTargets,
            infoPlist: .extendingDefault(with: basePlist),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: entitlements,
            dependencies: dependencies,
            settings: .settings(base: baseSettings)
        )

        // 单元测试默认开(Swift Testing);UI 测试 opt-in
        var testSettings: SettingsDictionary = ["SWIFT_VERSION": languageMode]
        if hasObjC {
            // 测试 target 经自己的桥接头看 app 内 ObjC 类(符号运行时由宿主 app 提供)
            testSettings["SWIFT_OBJC_BRIDGING_HEADER"] = "Tests/BridgingHeader.h"
        }
        let unitTests = Target.target(
            name: "\(name)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "\(bundleID).Tests",
            deploymentTargets: resolvedDeploymentTargets,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: name)],
            settings: .settings(base: testSettings)
        )

        var uiTests: [Target] = []
        if includeUITests {
            uiTests.append(Target.target(
                name: "\(name)UITests",
                destinations: destinations,
                product: .uiTests,
                bundleId: "\(bundleID).UITests",
                deploymentTargets: resolvedDeploymentTargets,
                infoPlist: .default,
                sources: ["UITests/**"],
                dependencies: [.target(name: name)]
            ))
        }

        return Project(
            name: name,
            targets: [appTarget, unitTests] + uiTests + extensions
        )
    }

    public enum ModuleLang {
        case swift
        case objc
    }

    /// 共享层模块工厂(一个共享工程,集中声明多个 framework)。
    /// 语言隔离:ObjC 与 Swift 分 target,消费方走 module import 而非桥接头。
    public static func module(
        name: String,
        lang: ModuleLang,
        destinations: Destinations = [.iPhone, .iPad],
        dependencies: [TargetDependency] = [],
        hasResources: Bool = false,
        deploymentTargets: DeploymentTargets? = nil,
        settings: SettingsDictionary = [:]
    ) -> Target {
        var baseSettings: SettingsDictionary = [:]
        var headers: Headers?
        switch lang {
        case .swift:
            baseSettings["SWIFT_VERSION"] = "6.0"
        case .objc:
            baseSettings.merge(objcQualityGate) { _, gate in gate }
            baseSettings["DEFINES_MODULE"] = "YES"
            headers = .headers(public: "\(name)/Sources/**/*.h")
        }
        baseSettings.merge(settings) { _, custom in custom }

        return Target.target(
            name: name,
            destinations: destinations,
            product: .framework,
            bundleId: "\(bundleIDPrefix).module.\(name)",
            deploymentTargets: deploymentTargets ?? defaultDeploymentTargets(for: destinations),
            infoPlist: .default,
            sources: ["\(name)/Sources/**"],
            resources: hasResources ? ["\(name)/Resources/**"] : nil,
            headers: headers,
            dependencies: dependencies,
            settings: .settings(base: baseSettings)
        )
    }
}
