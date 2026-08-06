import ProjectDescription
import ProjectDescriptionHelpers

let project = Studio.app(
    name: "DemoNotes",
    destinations: [.iPhone, .iPad],
    dependencies: [
        Studio.sharedModule("DesignKit"),
        .external(name: "Alamofire"),
        .external(name: "SnapKit"),
    ]
)
