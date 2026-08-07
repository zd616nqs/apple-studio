# ADR-0008 平台与产品目标支持边界

- 状态:accepted(2026-08-07)

平台与产品目标是两条独立维度，支持状态分为 verified、committed、recognized。只有具备工厂、示例、构建和测试证据才能标记 verified；路线图承诺但尚不可用的能力标记 committed；其余只标记 recognized。

当前 verified 是 iOS/iPadOS 的纯 Swift App 与 Swift/Objective-C 混编 App。Committed App 是 macOS、tvOS，以及作为 iPhone companion 交付的 watchOS App。Committed 产品目标是 WidgetKit、Share、Notification Service、Notification Content、App Intents、TV Top Shelf、AutoFill Credential Provider、Call Directory/Message Filter、Network Extension、Device Activity 和 iMessage。其他 Xcode Extension 类型只登记为 recognized，出现真实产品需求后再增加明确 factory，不提供掩盖平台差异的万能 `extension()` 接口。
