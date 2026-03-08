// swift-tools-version:6.0
import PackageDescription

let fluent = Target.Dependency.product(name: "Fluent", package: "fluent")
let vapor = Target.Dependency.product(name: "Vapor", package: "vapor")

let package = Package(
    name: "project-rulebook",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(url: "https://github.com/binarybirds/swift-html", from: "1.7.0"),
        .package(url: "https://github.com/dankinsoid/VaporToOpenAPI.git", from: "4.8.1"),
        .package(url: "https://github.com/apple/app-store-server-library-swift.git", "2.0.0"..<"3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                vapor, fluent,
                .product(name: "SwiftHtml", package: "swift-html"),
                .product(name: "SwiftSvg", package: "swift-html"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Redis", package: "redis"),
                .product(name: "VaporToOpenAPI", package: "VaporToOpenAPI"),
                .product(name: "AppStoreServerLibrary", package: "app-store-server-library-swift"),
            ]
        ),
        .testTarget(
            name: "AppTests", 
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "Fluent")
            ],
            exclude: [
            "Performance/PerformanceTestSuite.swift.disabled",
            "Performance/Load/APILoadTests.swift.disabled", 
            "Performance/Repository/RepositoryPerformanceTests.swift.disabled",
            "Performance/Cache/LLMCachePerformanceTests.swift.disabled"
        ])
    ]
)
