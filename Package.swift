// swift-tools-version: 6.4
import PackageDescription

func releasedDependency(named name: String, exactVersion: Version) -> Package.Dependency {
    .package(
        url: "https://github.com/1amageek/\(name).git",
        exact: exactVersion
    )
}

let package = Package(
    name: "LayoutDesignDatabaseIntegration",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "LayoutDesignDatabaseSchema",
            targets: ["LayoutDesignDatabaseSchema"]
        ),
        .library(
            name: "LayoutDesignDatabaseRuntimeAdapter",
            targets: ["LayoutDesignDatabaseRuntimeAdapter"]
        ),
    ],
    dependencies: [
        releasedDependency(
            named: "CircuiteFoundation",
            exactVersion: "26.812.0"
        ),
        releasedDependency(
            named: "DesignDatabase",
            exactVersion: "26.812.1"
        ),
        .package(url: "https://github.com/1amageek/PDKKit.git", revision: "9b42202a120b2174d0d0e88aa5edbcef53f81405"),
        .package(url: "https://github.com/1amageek/semiconductor-layout.git", revision: "7ca3dc4ac2fd821a5cabc321597ffd7fe8138b46"),
        .package(url: "https://github.com/1amageek/PDKDesignDatabaseIntegration.git", revision: "2999c238abf072466f021ba97dc5cc157b128a9d"),
        .package(
            url: "https://github.com/1amageek/database-kit.git",
            exact: "26.0809.4"
        ),
        .package(
            url: "https://github.com/1amageek/database-types.git",
            exact: "26.0730.0"
        ),
        .package(
            url: "https://github.com/1amageek/database-framework.git",
            exact: "26.0809.1",
            traits: ["SQLite"]
        ),
    ],
    targets: [
        .target(
            name: "LayoutDesignDatabaseSchema",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "PDKCore", package: "PDKKit"),
                .product(name: "PDKDesignDatabaseSchema", package: "PDKDesignDatabaseIntegration"),
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "DatabaseKit", package: "database-kit"),
                .product(name: "DatabaseTypes", package: "database-types"),
                .product(name: "DatabaseTypesFoundation", package: "database-types"),
            ]
        ),
        .target(
            name: "LayoutDesignDatabaseRuntimeAdapter",
            dependencies: [
                "LayoutDesignDatabaseSchema",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "DesignDatabaseRuntime", package: "DesignDatabase"),
                .product(name: "PDKCore", package: "PDKKit"),
                .product(name: "PDKDesignDatabaseSchema", package: "PDKDesignDatabaseIntegration"),
                .product(name: "PDKDesignDatabaseRuntimeAdapter", package: "PDKDesignDatabaseIntegration"),
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "Database", package: "database-framework"),
            ]
        ),
        .testTarget(
            name: "LayoutDesignDatabaseIntegrationTests",
            dependencies: [
                "LayoutDesignDatabaseSchema",
                "LayoutDesignDatabaseRuntimeAdapter",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "DesignDatabaseRuntime", package: "DesignDatabase"),
                .product(name: "PDKCore", package: "PDKKit"),
                .product(name: "PDKDesignDatabaseSchema", package: "PDKDesignDatabaseIntegration"),
                .product(name: "PDKDesignDatabaseRuntimeAdapter", package: "PDKDesignDatabaseIntegration"),
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "Database", package: "database-framework"),
            ]
        ),
    ]
)
