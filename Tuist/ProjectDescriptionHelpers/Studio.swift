import ProjectDescription

/// 全仓工程工厂:新 app = 调一次 Studio.app() + 填空。
/// 约定优先于配置:Sources/**、Resources/**、Tests/** 目录结构固定。
public enum Studio {
    /// 部署目标策略:最新-2 个大版本。per-app 可用 deploymentTargets 参数覆盖。
    public static let iOSDeploymentTarget = "18.0"
    public static let macOSDeploymentTarget = "15.0"
    public static let bundleIDPrefix = "com.yourstudio"

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
        var baseSettings: SettingsDictionary = [
            "SWIFT_VERSION": hasObjC ? "5.0" : "6.0",
        ]
        if hasObjC {
            // 混编质量门禁:nullability 不规范直接编译失败,不靠自觉
            baseSettings["CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION"] = "YES_ERROR"
        }
        baseSettings.merge(settings) { _, custom in custom }

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
        let unitTests = Target.target(
            name: "\(name)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "\(bundleID).Tests",
            deploymentTargets: resolvedDeploymentTargets,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: name)]
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
}
