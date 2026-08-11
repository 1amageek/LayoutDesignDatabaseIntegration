import DesignDatabaseCore

public protocol LayoutDesignImportPlanning: Sendable {
    func compileImport(
        _ request: LayoutDatabaseImportRequest
    ) throws(LayoutDatabaseImportPlanningError) -> DesignMutationPlan
}
