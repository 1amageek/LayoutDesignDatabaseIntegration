import LayoutCore

public enum LayoutDatabaseSchemaError: Error, Sendable, Hashable {
    case unsupportedSchemaVersion(Int)
    case missingIdentity
    case missingTopCell
    case invalidPDKSourceBinding(reason: String)
    case invalidSourceArtifactDescriptor
    case invalidDocument([LayoutDocumentValidationFinding])
    case nonCanonicalDocumentOrdering
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case nonCanonicalPayload
    case invalidPageByteCount(Int)
    case pageCountOverflow
}
