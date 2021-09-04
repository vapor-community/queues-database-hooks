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
        .package(url: "https://github.com/vapor/queues.git", from: "1.5.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "QueuesDatabaseHooks",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Queues", package: "queues")
            ]),
        .testTarget(
            name: "QueuesDatabaseHooksTests",
            dependencies: ["QueuesDatabaseHooks"]),
    ]
)
