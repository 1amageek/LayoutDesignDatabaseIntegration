import DesignDatabaseCore

public struct LayoutDatabaseImportPlanner: LayoutDesignImportPlanning, Sendable {
    public init() {}

    public func compileImport(
        _ request: LayoutDatabaseImportRequest
    ) throws(LayoutDatabaseImportPlanningError) -> DesignMutationPlan {
        guard request.sourcePDK.sourceRevision == request.baseRevision else {
            throw .sourceRevisionMismatch(
                expected: request.baseRevision,
                actual: request.sourcePDK.sourceRevision
            )
        }
        let state: LayoutDatabaseState
        do {
            state = try LayoutDatabaseState(
                pdk: request.pdk,
                sourcePDK: request.sourcePDK,
                sourceArtifact: request.sourceArtifact,
                document: request.document,
                metadata: request.metadata
            )
        } catch {
            throw .invalidCanonicalState(reason: String(describing: error))
        }
        do {
            return try LayoutDatabaseMutationPlanCompiler().compile(
                state,
                segmentID: request.segmentID,
                databaseID: request.databaseID,
                baseRevision: request.baseRevision,
                designSchemaBundleDigest: request.designSchemaBundleDigest,
                dependencyRootDigest: request.dependencyRootDigest,
                semanticDependencyGraphDigest: request.semanticDependencyGraphDigest,
                sourceEvidenceDigest: request.sourceEvidenceDigest
            )
        } catch {
            throw .mutationPlanCompilationFailed(reason: String(describing: error))
        }
    }
}
