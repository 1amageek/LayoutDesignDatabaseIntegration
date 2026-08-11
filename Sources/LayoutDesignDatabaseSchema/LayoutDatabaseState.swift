import CircuiteFoundation
import Foundation
import LayoutCore
import PDKDesignDatabaseSchema

public struct LayoutDatabaseState: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let pdkProcessID: String
    public let pdkVersion: String
    public let sourcePDK: PDKDatabaseFacetSourceBinding
    public let sourceArtifact: ArtifactReference
    public let document: LayoutDocument
    public let metadata: [String: String]

    public init(
        pdk: PDKDatabaseProcessState,
        sourcePDK: PDKDatabaseFacetSourceBinding,
        sourceArtifact: ArtifactReference,
        document: LayoutDocument,
        metadata: [String: String] = [:]
    ) throws(LayoutDatabaseSchemaError) {
        schemaVersion = Self.currentSchemaVersion
        pdkProcessID = pdk.processID
        pdkVersion = pdk.version
        self.sourcePDK = sourcePDK
        self.sourceArtifact = sourceArtifact
        self.document = Self.canonical(document)
        self.metadata = metadata
        try validate()
    }

    public func validate() throws(LayoutDatabaseSchemaError) {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw .unsupportedSchemaVersion(schemaVersion)
        }
        guard !pdkProcessID.isEmpty, !pdkVersion.isEmpty else {
            throw .missingIdentity
        }
        do {
            try sourcePDK.validate()
        } catch {
            throw .invalidPDKSourceBinding(reason: String(describing: error))
        }
        guard [ArtifactRole.input, .output].contains(sourceArtifact.descriptor.role),
              sourceArtifact.descriptor.kind == .layout,
              Self.supportedFormats.contains(sourceArtifact.descriptor.format) else {
            throw .invalidSourceArtifactDescriptor
        }
        guard !document.cells.isEmpty else {
            throw .missingIdentity
        }
        guard document.topCellID != nil else {
            throw .missingTopCell
        }
        let report = LayoutDocumentValidator().validate(document)
        guard report.isValid else {
            throw .invalidDocument(report.findings)
        }
        guard document == Self.canonical(document) else {
            throw .nonCanonicalDocumentOrdering
        }
    }

    private static let supportedFormats: Set<ArtifactFormat> = [
        .gdsii,
        .oasis,
        .def,
    ]

    private static func canonical(_ source: LayoutDocument) -> LayoutDocument {
        var result = source
        result.cells = source.cells.map { sourceCell in
            var cell = sourceCell
            cell.shapes.sort(by: identityOrder)
            cell.vias.sort(by: identityOrder)
            cell.labels.sort(by: identityOrder)
            cell.pins.sort(by: identityOrder)
            cell.instances.sort(by: identityOrder)
            cell.nets.sort(by: identityOrder)
            return cell
        }.sorted(by: identityOrder)
        return result
    }

    private static func identityOrder<Value: Identifiable>(
        _ lhs: Value,
        _ rhs: Value
    ) -> Bool where Value.ID == UUID {
        lhs.id.uuidString < rhs.id.uuidString
    }
}
