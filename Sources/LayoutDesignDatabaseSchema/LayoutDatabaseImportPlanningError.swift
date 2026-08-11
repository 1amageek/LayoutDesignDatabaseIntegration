import CircuiteFoundation

public enum LayoutDatabaseImportPlanningError: Error, Sendable, Hashable {
    case sourceRevisionMismatch(
        expected: DesignRevisionReference,
        actual: DesignRevisionReference
    )
    case invalidCanonicalState(reason: String)
    case mutationPlanCompilationFailed(reason: String)
}
