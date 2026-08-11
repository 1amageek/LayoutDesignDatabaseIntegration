import DatabaseKit
import DatabaseTypes

@Persistable
public struct LayoutDatabaseFacetPage {
    #Directory<LayoutDatabaseFacetPage>(
        "design-database",
        "layout-facets",
        \LayoutDatabaseFacetPage.facetID,
        \LayoutDatabaseFacetPage.documentDigest,
        "pages",
        layer: .partition
    )

    public var id: String = ""
    public var facetID: String = ""
    public var ordinal: UInt64 = 0
    public var pageCount: UInt64 = 0
    public var documentByteCount: UInt64 = 0
    public var documentDigest: String = ""
    public var payload: ByteString = ByteString()
}
