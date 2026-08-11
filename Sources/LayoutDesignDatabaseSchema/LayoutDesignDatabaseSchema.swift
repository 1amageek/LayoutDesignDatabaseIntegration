import CircuiteFoundation
import DesignDatabaseCore

public enum LayoutDesignDatabaseSchema {
    public static let adapterVersion = "1.0.0"
    public static let bindingManifest = """
    lsi.layout-design-database-schema/v1
    entity=LayoutDatabaseFacetPage
    directory=design-database/layout-facets/{facetID}/{documentDigest}/pages
    fields=id,facetID,ordinal,pageCount,documentByteCount,documentDigest,payload
    facets=layout.physical
    sourceBinding=exact-base-revision+pdk.process+facet-root
    canonicalState=layout-document-without-drc-or-release-verdict
    pageByteCount=65536
    """

    public static var schemaID: DesignSchemaID {
        get throws {
            try DesignSchemaID(rawValue: "lsi.layout")
        }
    }
}
