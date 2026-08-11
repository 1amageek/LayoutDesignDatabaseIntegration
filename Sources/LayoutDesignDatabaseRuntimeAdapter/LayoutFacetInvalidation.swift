import CircuiteFoundation
import PDKDesignDatabaseSchema

public struct LayoutFacetInvalidation: Sendable, Hashable, Codable {
    public enum Reason: String, Sendable, Hashable, Codable {
        case sourceFacetMissing
        case sourceRootChanged
    }

    public let observedRevision: DesignRevisionReference
    public let sourceBinding: PDKDatabaseFacetSourceBinding
    public let actualSourceRootDigest: ContentDigest?
    public let reason: Reason

    public init(
        observedRevision: DesignRevisionReference,
        sourceBinding: PDKDatabaseFacetSourceBinding,
        actualSourceRootDigest: ContentDigest?,
        reason: Reason
    ) {
        self.observedRevision = observedRevision
        self.sourceBinding = sourceBinding
        self.actualSourceRootDigest = actualSourceRootDigest
        self.reason = reason
    }
}
