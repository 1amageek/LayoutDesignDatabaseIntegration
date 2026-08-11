import LayoutDesignDatabaseSchema

public struct LayoutSnapshotState: Sendable, Hashable, Codable {
    public let layout: LayoutDatabaseState?
    public let invalidation: LayoutFacetInvalidation?

    public init(
        layout: LayoutDatabaseState?,
        invalidation: LayoutFacetInvalidation?
    ) {
        self.layout = layout
        self.invalidation = invalidation
    }

    public var isSemanticallyCurrent: Bool {
        invalidation == nil
    }
}
