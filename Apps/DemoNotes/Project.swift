import ProjectDescription
import ProjectDescriptionHelpers

let project = Studio.app(
    name: "DemoNotes",
    destinations: [.iPhone, .iPad]
    // ticket 02: dependencies: [.target 共享模块 + .external 三方库]
)
