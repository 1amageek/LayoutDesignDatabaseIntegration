import CircuiteFoundation
import DesignDatabaseCore
import DesignDatabaseRuntime
import LayoutDesignDatabaseSchema
import PDKDesignDatabaseSchema

public struct LayoutDesignDatabaseSnapshotReader:
    LayoutDesignDatabaseReading,
    Sendable
{
    public init() {}

    public func readState(
        from snapshot: any DesignReadSnapshot,
        budget: LayoutDatabaseReadBudget
    ) async throws -> LayoutSnapshotState {
        let layout = try await readLayout(from: snapshot, budget: budget)
        guard let layout else {
            return LayoutSnapshotState(layout: nil, invalidation: nil)
        }
        let pdkFacetID = try PDKDatabaseFacet.process.designFacetID
        let actualPDKRoot = snapshot.facetRoots.first(where: {
            $0.facetID == pdkFacetID
        })?.digest
        let invalidation: LayoutFacetInvalidation?
        if let actualPDKRoot {
            invalidation = actualPDKRoot == layout.sourcePDK.sourceRootDigest
                ? nil
                : LayoutFacetInvalidation(
                    observedRevision: snapshot.revision,
                    sourceBinding: layout.sourcePDK,
                    actualSourceRootDigest: actualPDKRoot,
                    reason: .sourceRootChanged
                )
        } else {
            invalidation = LayoutFacetInvalidation(
                observedRevision: snapshot.revision,
                sourceBinding: layout.sourcePDK,
                actualSourceRootDigest: nil,
                reason: .sourceFacetMissing
            )
        }
        return LayoutSnapshotState(layout: layout, invalidation: invalidation)
    }

    public func readLayout(
        from snapshot: any DesignReadSnapshot,
        budget: LayoutDatabaseReadBudget
    ) async throws -> LayoutDatabaseState? {
        let facetID = try LayoutDatabaseFacet.layout.designFacetID
        guard let expectedRoot = snapshot.facetRoots.first(where: {
            $0.facetID == facetID
        })?.digest else {
            return nil
        }
        guard let runtimeSnapshot = snapshot as? DesignDatabaseRuntimeSnapshot else {
            throw LayoutDatabaseReadError.unsupportedSnapshotImplementation
        }
        return try await runtimeSnapshot.withRuntimeReads(
            maximumReadCount: try budget.runtimeReadCount
        ) { reads in
            try await LayoutDatabaseRuntimeStateReader().read(
                expectedRoot: expectedRoot,
                from: reads,
                budget: budget
            )
        }
    }
}
