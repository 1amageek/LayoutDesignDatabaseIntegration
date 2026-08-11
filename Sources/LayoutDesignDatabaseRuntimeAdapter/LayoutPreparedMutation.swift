import CircuiteFoundation
import Database
import DesignDatabaseCore
import DesignDatabaseRuntime
import LayoutDesignDatabaseSchema

struct LayoutPreparedMutation: DesignDatabaseRuntimePreparedMutation {
    let segmentID: DesignMutationPlanSegmentID
    let pages: [LayoutDatabaseFacetPage]
    let facetRootDigest: ContentDigest
    let changeContributionDigest: ContentDigest

    var writeCount: UInt64 {
        UInt64(pages.count)
    }

    func immutableWriteIdentity(
        at index: UInt64
    ) throws(DesignDatabaseRuntimePreparedMutationError)
        -> DesignDatabaseRuntimeImmutableWriteIdentity {
        guard let pageIndex = Int(exactly: index),
              pages.indices.contains(pageIndex) else {
            throw .invalidImmutableWriteIndex(index: index, writeCount: writeCount)
        }
        let page = pages[pageIndex]
        return try LayoutDesignDatabaseRuntimeAdapter.physicalWriteIdentity(page)
    }

    func stageImmutableWrite(
        at index: UInt64,
        to transaction: any DatabaseTransactionWriting
    ) async throws {
        guard let pageIndex = Int(exactly: index),
              pages.indices.contains(pageIndex) else {
            throw DesignDatabaseRuntimePreparedMutationError
                .invalidImmutableWriteIndex(index: index, writeCount: writeCount)
        }
        let page = pages[pageIndex]
        var partition = DirectoryPath<LayoutDatabaseFacetPage>()
        partition.set(LayoutDatabaseFacetPage.fields.facetID, to: page.facetID)
        partition.set(
            LayoutDatabaseFacetPage.fields.documentDigest,
            to: page.documentDigest
        )
        if let existing = try await transaction.fetch(
            LayoutDatabaseFacetPage.self,
            identifiedBy: page.id,
            in: partition
        ) {
            guard Self.matches(existing, page) else {
                throw LayoutPreparedMutationError.contentAddressCollision(
                    facetID: page.facetID,
                    documentDigest: page.documentDigest,
                    ordinal: page.ordinal
                )
            }
            return
        }
        try await transaction.save(page, precondition: .none)
    }

    private static func matches(
        _ lhs: LayoutDatabaseFacetPage,
        _ rhs: LayoutDatabaseFacetPage
    ) -> Bool {
        lhs.id == rhs.id
            && lhs.facetID == rhs.facetID
            && lhs.ordinal == rhs.ordinal
            && lhs.pageCount == rhs.pageCount
            && lhs.documentByteCount == rhs.documentByteCount
            && lhs.documentDigest == rhs.documentDigest
            && lhs.payload == rhs.payload
    }
}
