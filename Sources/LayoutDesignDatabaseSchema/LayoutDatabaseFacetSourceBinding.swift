import CircuiteFoundation

public struct LayoutDatabaseFacetSourceBinding: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let sourceRevision: DesignRevisionReference
    public let sourceFacet: LayoutDatabaseFacet
    public let sourceRootDigest: ContentDigest

    public init(
        sourceRevision: DesignRevisionReference,
        sourceFacet: LayoutDatabaseFacet = .layout,
        sourceRootDigest: ContentDigest
    ) throws(LayoutDatabaseSchemaError) {
        guard sourceFacet == .layout else {
            throw .invalidSourceArtifactDescriptor
        }
        schemaVersion = Self.currentSchemaVersion
        self.sourceRevision = sourceRevision
        self.sourceFacet = sourceFacet
        self.sourceRootDigest = sourceRootDigest
    }

    public func validate() throws(LayoutDatabaseSchemaError) {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw .unsupportedSchemaVersion(schemaVersion)
        }
        guard sourceFacet == .layout else {
            throw .invalidSourceArtifactDescriptor
        }
    }
}
