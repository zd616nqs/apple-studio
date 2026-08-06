# DemoNotes — 纯 Swift 活范例

定位:SwiftUI + 共享层 + Swift 三方库的标准姿势,新纯 Swift app 照抄这里。

- 语言模式:Swift 6(严格并发)
- 依赖:DesignKit(经 `Studio.sharedModule`)、Alamofire、SnapKit(`.external`)
- 可抄的模式:NotesStore(可测业务逻辑)、PingRequestBuilder(构造请求不发网络,可测)、
  SnapKitBannerView(SwiftUI 内嵌 UIKit 约束 DSL)
- 行为文档:本目录 openspec/(命令在本目录下执行);术语见 CONTEXT.md
- 本 app 规则之外的一切(红线/混编/依赖/测试)见根 CLAUDE.md 与 docs/standards/
