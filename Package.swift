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
        .package(url: "https://github.com/1amageek/DesignDatabase.git", revision: "78f1c2e28e804e7c750014827e9f18c88c2272e3"),
        .package(url: "https://github.com/1amageek/PDKKit.git", revision: "06212417a47d8dec4a3c541a0612a1ac08e66b45"),
        .package(url: "https://github.com/1amageek/semiconductor-layout.git", revision: "3782d80a8038118ec0e4d18d550391d4e6587da1"),
        .package(url: "https://github.com/1amageek/PDKDesignDatabaseIntegration.git", revision: "51518f4100bb4b6f739c01d6c324fc1a4c0c6523"),
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
