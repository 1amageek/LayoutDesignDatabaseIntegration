import DesignDatabaseCore

public protocol LayoutDesignDatabaseReading: Sendable {
    func readState(
        from snapshot: any DesignReadSnapshot,
        budget: LayoutDatabaseReadBudget
    ) async throws -> LayoutSnapshotState
}
