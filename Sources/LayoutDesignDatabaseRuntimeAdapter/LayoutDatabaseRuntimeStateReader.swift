import CircuiteFoundation
import CircuiteFoundationCrypto
import Database
import DatabaseTypesFoundation
import DesignDatabaseRuntime
import Foundation
import LayoutDesignDatabaseSchema

public struct LayoutDatabaseRuntimeStateReader: Sendable {
    public init() {}

    public func read(
        expectedRoot: ContentDigest,
        from reads: DesignDatabaseRuntimeReadSnapshot,
        budget: LayoutDatabaseReadBudget
    ) async throws -> LayoutDatabaseState {
        var partition = DirectoryPath<LayoutDatabaseFacetPage>()
        partition.set(
            LayoutDatabaseFacetPage.fields.facetID,
            to: LayoutDatabaseFacet.layout.rawValue
        )
        partition.set(
            LayoutDatabaseFacetPage.fields.documentDigest,
            to: expectedRoot.hexadecimalValue
        )
        var pages: [LayoutDatabaseFacetPage] = []
        pages.reserveCapacity(min(budget.maximumPageCount, budget.pageFetchLimit))
        var continuation: DatabaseScanContinuation?
        repeat {
            let page = try await reads.scan(
                LayoutDatabaseFacetPage.self,
                in: partition,
                after: continuation,
                limit: budget.pageFetchLimit
            )
            pages.append(contentsOf: page.items)
            guard pages.count <= budget.maximumPageCount else {
                throw LayoutDatabaseReadError.pageBudgetExceeded(
                    limit: budget.maximumPageCount
                )
            }
            continuation = page.continuation
        } while continuation != nil
        return try decode(pages: pages, expectedRoot: expectedRoot)
    }

    private func decode(
        pages: [LayoutDatabaseFacetPage],
        expectedRoot: ContentDigest
    ) throws -> LayoutDatabaseState {
        guard let first = pages.first else {
            throw LayoutDatabaseReadError.missingFacetPages
        }
        let ordered = pages.sorted { $0.ordinal < $1.ordinal }
        guard first.pageCount == UInt64(ordered.count),
              ordered.allSatisfy({ page in
                  page.facetID == LayoutDatabaseFacet.layout.rawValue
                      && page.pageCount == first.pageCount
                      && page.documentByteCount == first.documentByteCount
                      && page.documentDigest == first.documentDigest
              }) else {
            throw LayoutDatabaseReadError.inconsistentPageMetadata
        }
        for (index, page) in ordered.enumerated() {
            guard page.ordinal == UInt64(index) else {
                throw LayoutDatabaseReadError.nonContiguousPages
            }
        }
        guard let capacity = Int(exactly: first.documentByteCount) else {
            throw LayoutDatabaseReadError.inconsistentPageMetadata
        }
        var data = Data()
        data.reserveCapacity(capacity)
        for page in ordered {
            page.payload.withUnsafeBytes { bytes in
                data.append(bytes.bindMemory(to: UInt8.self))
            }
        }
        guard let actualByteCount = UInt64(exactly: data.count),
              actualByteCount == first.documentByteCount else {
            throw LayoutDatabaseReadError.byteCountMismatch(
                expected: first.documentByteCount,
                actual: UInt64(data.count)
            )
        }
        let actualRoot = try SHA256ContentDigester().digest(data: data)
        guard actualRoot == expectedRoot else {
            throw LayoutDatabaseReadError.facetRootMismatch(
                expected: expectedRoot,
                actual: actualRoot
            )
        }
        do {
            return try LayoutDatabaseCanonicalCodec.decode(data)
        } catch let error {
            throw LayoutDatabaseReadError.decodeFailed(error)
        }
    }
}
