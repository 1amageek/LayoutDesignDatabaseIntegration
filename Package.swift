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
        .package(url: "https://github.com/1amageek/PDKKit.git", revision: "c2b143f566b1e92308dfdebb2764067a141da75a"),
        .package(url: "https://github.com/1amageek/semiconductor-layout.git", revision: "aada7526e4408c75f1940d3aa7372aaf523e2a42"),
        .package(url: "https://github.com/1amageek/PDKDesignDatabaseIntegration.git", revision: "443d42b5d6495f4dd43054606d069f3ed66fcdda"),
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
