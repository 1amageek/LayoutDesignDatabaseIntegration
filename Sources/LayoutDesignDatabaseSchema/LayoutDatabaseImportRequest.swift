import CircuiteFoundation
import DesignDatabaseCore
import LayoutCore
import PDKDesignDatabaseSchema

public struct LayoutDatabaseImportRequest: Sendable, Hashable {
    public let pdk: PDKDatabaseProcessState
    public let sourcePDK: PDKDatabaseFacetSourceBinding
    public let sourceArtifact: ArtifactReference
    public let document: LayoutDocument
    public let metadata: [String: String]
    public let segmentID: DesignMutationPlanSegmentID
    public let databaseID: DesignDatabaseID
    public let baseRevision: DesignRevisionReference
    public let designSchemaBundleDigest: ContentDigest
    public let dependencyRootDigest: ContentDigest
    public let semanticDependencyGraphDigest: ContentDigest
    public let sourceEvidenceDigest: ContentDigest

    public init(
        pdk: PDKDatabaseProcessState,
        sourcePDK: PDKDatabaseFacetSourceBinding,
        sourceArtifact: ArtifactReference,
        document: LayoutDocument,
        metadata: [String: String] = [:],
        segmentID: DesignMutationPlanSegmentID,
        databaseID: DesignDatabaseID,
        baseRevision: DesignRevisionReference,
        designSchemaBundleDigest: ContentDigest,
        dependencyRootDigest: ContentDigest,
        semanticDependencyGraphDigest: ContentDigest,
        sourceEvidenceDigest: ContentDigest
    ) {
        self.pdk = pdk
        self.sourcePDK = sourcePDK
        self.sourceArtifact = sourceArtifact
        self.document = document
        self.metadata = metadata
        self.segmentID = segmentID
        self.databaseID = databaseID
        self.baseRevision = baseRevision
        self.designSchemaBundleDigest = designSchemaBundleDigest
        self.dependencyRootDigest = dependencyRootDigest
        self.semanticDependencyGraphDigest = semanticDependencyGraphDigest
        self.sourceEvidenceDigest = sourceEvidenceDigest
    }
}
