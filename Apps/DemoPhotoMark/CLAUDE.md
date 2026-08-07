# DemoPhotoMark — 混编示例工程

定位:Swift + ObjC 混编(含 ObjC 三方库)的标准做法,新混编 app 照抄这里。

- 语言模式:Swift 5(hasObjC 档位,ADR-0004);工厂 `hasObjC: true`
- 依赖:LegacyCore(共享 ObjC,`import LegacyCore` **不走桥接头**)、SDWebImage、MBProgressHUD
- 混编三件套(docs/standards/objc-swift-interop.md 必读):
  `Sources/BridgingHeader.h`(本 target ObjC → Swift 可见)、
  `Tests/BridgingHeader.h`(测试直测 app 内 ObjC 类)、
  nullability 检查(头文件缺注解 = 编译失败)
- 可抄的模式:PMWatermarkRenderer(ObjC 调共享层)、PMRemotePhotoView(ObjC 调三方库)
- 行为文档:本目录 openspec/;术语见 CONTEXT.md
