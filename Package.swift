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
        .package(url: "https://github.com/1amageek/DesignDatabase.git", revision: "11df4ff7d905d642b5935defb3bc1fbcfefda038"),
        .package(url: "https://github.com/1amageek/PDKKit.git", revision: "14f7b508dd8961ed4bfa6d6e29600fdc5c6ae9f5"),
        .package(url: "https://github.com/1amageek/semiconductor-layout.git", revision: "17278fb7340e98a7af5a960766083c0e0c39f69b"),
        .package(url: "https://github.com/1amageek/PDKDesignDatabaseIntegration.git", revision: "c641f8764e0185722e52561c3c0b1772b22f2c62"),
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
