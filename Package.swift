// swift-tools-version: 6.2

import Foundation
import PackageDescription

struct Project {
    static let name: String = "HealthVaults"

    static let app: String = "\(Project.name)App"
    static let shared: String = "\(Project.name)Shared"
    static let widgets: String = "\(Project.name)Widgets"

    static func dependency(_ target: String) -> Target.Dependency {
        return Target.Dependency(stringLiteral: target)
    }
}

let package = Package(
    name: Project.name,
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],

    products: [
        .library(
            name: Project.shared,
            targets: [Project.shared]
        )
    ],

    targets: [
        .executableTarget(
            name: Project.app,
            dependencies: [Project.dependency(Project.shared)],
            path: "App",
        ),
        .target(
            name: Project.shared,
            path: "Shared",
        ),
        .executableTarget(
            name: Project.widgets,
            dependencies: [Project.dependency(Project.shared)],
            path: "Widgets",
        ),
    ]
)
