import ProjectDescription
import ProjectDescriptionHelpers

// 混编示例工程:hasObjC 开启桥接头约定;共享 ObjC(LegacyCore)走 module import
let project = Studio.app(
    name: "DemoPhotoMark",
    destinations: [.iPhone, .iPad],
    dependencies: [
        Studio.sharedModule("LegacyCore"),
        .external(name: "SDWebImage"),
        .external(name: "MBProgressHUD"),
    ],
    hasObjC: true
)
