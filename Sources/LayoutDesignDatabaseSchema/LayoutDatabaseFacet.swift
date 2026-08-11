import CircuiteFoundation
import DesignDatabaseCore

public enum LayoutDatabaseFacet: String, Sendable, Hashable, Codable, CaseIterable {
    case layout = "layout.physical"

    public var designFacetID: DesignFacetID {
        get throws {
            try DesignFacetID(rawValue: rawValue)
        }
    }
}
