import CircuiteFoundation
import CircuiteFoundationCrypto
import DesignDatabaseCore

public struct LayoutDatabaseMutationPlanCompiler: Sendable {
    public init() {}

    public func compile(
        _ state: LayoutDatabaseState,
        segmentID: DesignMutationPlanSegmentID,
        databaseID: DesignDatabaseID,
        baseRevision: DesignRevisionReference,
        designSchemaBundleDigest: ContentDigest,
        dependencyRootDigest: ContentDigest,
        semanticDependencyGraphDigest: ContentDigest,
        sourceEvidenceDigest: ContentDigest
    ) throws -> DesignMutationPlan {
        let canonicalData = try LayoutDatabaseCanonicalCodec.encode(state)
        let payload = Array(canonicalData)
        let digester = SHA256ContentDigester()
        let payloadDigest = try DesignMutationPlanDigest.payload(
            payload,
            using: digester
        )
        let writeCount = try LayoutDatabaseCanonicalDocument.pageCount(
            forByteCount: canonicalData.count
        )
        let segment = try DesignMutationPlanSegment(
            id: segmentID,
            schemaID: try LayoutDesignDatabaseSchema.schemaID,
            schemaVersion: .v1,
            adapterVersion: LayoutDesignDatabaseSchema.adapterVersion,
            targetFacet: try LayoutDatabaseFacet.layout.designFacetID,
            payload: payload,
            payloadDigest: payloadDigest,
            expectedWriteCount: writeCount
        )
        let budget = try DesignMutationPlanBudget(
            maximumSegmentCount: 1,
            maximumPayloadByteCount: UInt64(canonicalData.count),
            maximumPreparedWriteCount: writeCount,
            maximumValidationReadCount: 4_097
        )
        let planDigest = try DesignMutationPlanDigest.plan(
            databaseID: databaseID,
            baseRevision: baseRevision,
            designSchemaBundleDigest: designSchemaBundleDigest,
            dependencyRootDigest: dependencyRootDigest,
            semanticDependencyGraphDigest: semanticDependencyGraphDigest,
            sourceEvidenceDigest: sourceEvidenceDigest,
            budget: budget,
            segments: [segment],
            using: digester
        )
        return DesignMutationPlan(
            databaseID: databaseID,
            baseRevision: baseRevision,
            designSchemaBundleDigest: designSchemaBundleDigest,
            dependencyRootDigest: dependencyRootDigest,
            semanticDependencyGraphDigest: semanticDependencyGraphDigest,
            sourceEvidenceDigest: sourceEvidenceDigest,
            budget: budget,
            segments: [segment],
            planDigest: planDigest
        )
    }
}
