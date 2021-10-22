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
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.7.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.7.0"),
        
        // Test-only dependencies
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "QueuesDatabaseHooks",
            dependencies: [
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "Queues", package: "queues")
            ]),
        .testTarget(
            name: "QueuesDatabaseHooksTests",
            dependencies: [
                .target(name: "QueuesDatabaseHooks"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "XCTQueues", package: "queues"),
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
            ]),
    ]
)
