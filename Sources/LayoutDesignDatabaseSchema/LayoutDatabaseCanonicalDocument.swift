import CircuiteFoundation
import DatabaseTypes
import DatabaseTypesFoundation
import Foundation

public struct LayoutDatabaseCanonicalDocument: Sendable {
    public static let defaultPageByteCount = 64 * 1_024

    public let state: LayoutDatabaseState
    public let canonicalData: Data
    public let facetRootDigest: ContentDigest
    public let pages: [LayoutDatabaseFacetPage]

    public init(
        state: LayoutDatabaseState,
        pageByteCount: Int = Self.defaultPageByteCount
    ) throws(LayoutDatabaseSchemaError) {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let data = try LayoutDatabaseCanonicalCodec.encode(state)
        let digest: ContentDigest
        do {
            digest = try LayoutDatabaseDigesting.sha256(Array(data))
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
        let byteCount = data.count
        let pageCount = max(1, (byteCount + pageByteCount - 1) / pageByteCount)
        guard let persistedPageCount = UInt64(exactly: pageCount),
              let persistedByteCount = UInt64(exactly: byteCount) else {
            throw .pageCountOverflow
        }
        let owner = ByteString(retaining: data)
        var pages: [LayoutDatabaseFacetPage] = []
        pages.reserveCapacity(pageCount)
        for index in 0..<pageCount {
            let lower = index * pageByteCount
            let upper = min(byteCount, lower + pageByteCount)
            guard let ordinal = UInt64(exactly: index) else {
                throw .pageCountOverflow
            }
            pages.append(
                LayoutDatabaseFacetPage(
                    id: Self.pageID(ordinal),
                    facetID: LayoutDatabaseFacet.layout.rawValue,
                    ordinal: ordinal,
                    pageCount: persistedPageCount,
                    documentByteCount: persistedByteCount,
                    documentDigest: digest.hexadecimalValue,
                    payload: owner[lower..<upper]
                )
            )
        }
        self.state = state
        canonicalData = data
        facetRootDigest = digest
        self.pages = pages
    }

    public static func pageCount(
        forByteCount byteCount: Int,
        pageByteCount: Int = defaultPageByteCount
    ) throws(LayoutDatabaseSchemaError) -> UInt64 {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let count = max(1, (byteCount + pageByteCount - 1) / pageByteCount)
        guard let result = UInt64(exactly: count) else {
            throw .pageCountOverflow
        }
        return result
    }

    /// Materializes pages from a Runtime-authenticated validation capsule.
    /// This method intentionally does not repeat domain semantic validation.
    public static func materializeValidated(
        canonicalData: Data,
        pageByteCount: Int = defaultPageByteCount
    ) throws(LayoutDatabaseSchemaError) -> (
        facetRootDigest: ContentDigest,
        pages: [LayoutDatabaseFacetPage]
    ) {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let digest: ContentDigest
        do {
            digest = try LayoutDatabaseDigesting.sha256(Array(canonicalData))
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
        let pageCount = max(
            1,
            (canonicalData.count + pageByteCount - 1) / pageByteCount
        )
        guard let persistedPageCount = UInt64(exactly: pageCount),
              let persistedByteCount = UInt64(exactly: canonicalData.count) else {
            throw .pageCountOverflow
        }
        let owner = ByteString(retaining: canonicalData)
        var pages: [LayoutDatabaseFacetPage] = []
        pages.reserveCapacity(pageCount)
        for index in 0..<pageCount {
            guard let ordinal = UInt64(exactly: index) else {
                throw .pageCountOverflow
            }
            let lower = index * pageByteCount
            let upper = min(canonicalData.count, lower + pageByteCount)
            pages.append(
                LayoutDatabaseFacetPage(
                    id: pageID(ordinal),
                    facetID: LayoutDatabaseFacet.layout.rawValue,
                    ordinal: ordinal,
                    pageCount: persistedPageCount,
                    documentByteCount: persistedByteCount,
                    documentDigest: digest.hexadecimalValue,
                    payload: owner[lower..<upper]
                )
            )
        }
        return (digest, pages)
    }

    private static func pageID(_ ordinal: UInt64) -> String {
        let value = String(ordinal)
        return String(repeating: "0", count: 20 - value.count) + value
    }
}
