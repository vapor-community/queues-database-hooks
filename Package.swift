// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "queues-database-hooks",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "QueuesDatabaseHooks",
            targets: ["QueuesDatabaseHooks"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/queues.git", .branch("hooks")),
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.7.0")
    ],
    targets: [
        .target(
            name: "QueuesDatabaseHooks",
            dependencies: [
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "Queues", package: "queues")
            ]),
        .testTarget(
            name: "QueuesDatabaseHooksTests",
            dependencies: ["QueuesDatabaseHooks"]),
    ]
)
