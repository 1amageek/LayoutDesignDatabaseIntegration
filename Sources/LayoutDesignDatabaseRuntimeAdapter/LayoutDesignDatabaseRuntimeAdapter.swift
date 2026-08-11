import CircuiteFoundation
import CircuiteFoundationCrypto
import Database
import DesignDatabaseCore
import DesignDatabaseRuntime
import Foundation
import LayoutCore
import LayoutDesignDatabaseSchema
import PDKCore
import PDKDesignDatabaseRuntimeAdapter
import PDKDesignDatabaseSchema

public struct LayoutDesignDatabaseRuntimeAdapter:
    DesignDatabaseRuntimeMutationAdapter,
    Sendable
{
    public let schemaID: DesignSchemaID
    public let schemaVersion = SchemaVersion.v1
    public let adapterVersion = LayoutDesignDatabaseSchema.adapterVersion
    public let supportedFacets: Set<DesignFacetID>

    public init() throws {
        schemaID = try LayoutDesignDatabaseSchema.schemaID
        supportedFacets = [try LayoutDatabaseFacet.layout.designFacetID]
    }

    public func contribution() throws -> DesignDatabaseRuntimeContribution {
        let bindingBytes = Array(LayoutDesignDatabaseSchema.bindingManifest.utf8)
        let bindingDigest = try LayoutDatabaseDigesting.sha256(bindingBytes)
        return try DesignDatabaseRuntimeContribution(
            id: DesignDatabaseRuntimeContributionID("lsi.layout-design-database"),
            designSchemaMember: DesignSchemaBundleMember(
                schemaID: schemaID,
                version: schemaVersion,
                canonicalDigest: bindingDigest
            ),
            bindingDigest: bindingDigest,
            entities: [try LayoutDatabaseFacetPage.schemaEntity],
            entityRuntimes: [
                try DatabaseFrameworkRuntime.entity(LayoutDatabaseFacetPage.self),
            ],
            mutationAdapter: self,
            physicalWriteReclaimers: [self]
        )
    }

    public func validate(
        _ segment: DesignMutationPlanSegment,
        in context: DesignDatabaseRuntimeMutationValidation
    ) async throws(DesignDatabaseRuntimeMutationAdapterError)
        -> DesignDatabaseRuntimeValidatedMutation {
        let layoutFacetID: DesignFacetID
        do {
            layoutFacetID = try LayoutDatabaseFacet.layout.designFacetID
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard segment.schemaID == schemaID,
              segment.schemaVersion == schemaVersion,
              segment.adapterVersion == adapterVersion,
              segment.targetFacet == layoutFacetID else {
            throw .invalidPayload(
                reason: "The layout segment binding is not registered."
            )
        }
        let state: LayoutDatabaseState
        do {
            state = try LayoutDatabaseCanonicalCodec.decode(Data(segment.payload))
        } catch LayoutDatabaseSchemaError.invalidDocument(let findings) {
            throw .validationFailed(
                diagnostics: findings.map(Self.diagnostic),
                diagnosticsDigest: segment.payloadDigest
            )
        } catch let error {
            throw .invalidPayload(reason: String(describing: error))
        }
        try validateSourcePDK(
            state.sourcePDK,
            context: context,
            diagnosticsDigest: segment.payloadDigest
        )
        let pdkState: PDKDatabaseProcessState
        do {
            pdkState = try await PDKDatabaseRuntimeProcessReader().read(
                expectedRoot: state.sourcePDK.sourceRootDigest,
                from: context.reads,
                budget: PDKDatabaseReadBudget()
            )
        } catch DesignDatabaseRuntimeReadError.budgetExceeded(
            let limit,
            let requested
        ) {
            throw .budgetExceeded(limit: limit, requested: requested)
        } catch {
            throw .invalidPayload(
                reason: "The exact base PDK process state could not be read: \(error)"
            )
        }
        guard state.pdkProcessID == pdkState.processID,
              state.pdkVersion == pdkState.version else {
            throw .validationFailed(
                diagnostics: [
                    DesignDiagnostic(
                        code: .trusted("LAYOUT_PDK_IDENTITY_MISMATCH"),
                        severity: .error,
                        summary: "The layout PDK identity does not match the exact base PDK state.",
                        detail: "Expected \(state.pdkProcessID)@\(state.pdkVersion), actual \(pdkState.processID)@\(pdkState.version)."
                    ),
                ],
                diagnosticsDigest: segment.payloadDigest
            )
        }
        try validateLayers(
            in: state.document,
            against: pdkState,
            diagnosticsDigest: segment.payloadDigest
        )
        let document: LayoutDatabaseCanonicalDocument
        do {
            document = try LayoutDatabaseCanonicalDocument(state: state)
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard document.pages.count == segment.expectedWriteCount else {
            throw .invalidPayload(
                reason: "The declared write count does not match the canonical page count."
            )
        }
        let observedPayloadDigest: ContentDigest
        do {
            observedPayloadDigest = try DesignMutationPlanDigest.payload(
                segment.payload,
                using: SHA256ContentDigester()
            )
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard observedPayloadDigest == segment.payloadDigest,
              document.facetRootDigest == segment.payloadDigest else {
            throw .invalidPayload(
                reason: "The canonical layout payload digest does not match the segment."
            )
        }
        return DesignDatabaseRuntimeValidatedMutation(
            segmentID: segment.id,
            materializationPayload: segment.payload
        )
    }

    public func materializeValidatedMutation(
        _ validation: DesignDatabaseRuntimeValidatedMutationRecord,
        for segment: DesignMutationPlanSegment,
        in context: DesignDatabaseRuntimeMutationRestoration
    ) throws(DesignDatabaseRuntimeMutationAdapterError)
        -> any DesignDatabaseRuntimePreparedMutation {
        _ = context
        do {
            guard validation.materializationPayloadDigest
                    == validation.segmentPayloadDigest else {
                throw DesignDatabaseRuntimeMutationAdapterError.invalidPayload(
                    reason: "The validated layout capsule is not the canonical segment payload."
                )
            }
            let materialization = try LayoutDatabaseCanonicalDocument
                .materializeValidated(
                    canonicalData: Data(validation.materializationPayload)
                )
            guard UInt64(materialization.pages.count) == segment.expectedWriteCount,
                  materialization.facetRootDigest == segment.payloadDigest else {
                throw DesignDatabaseRuntimeMutationAdapterError.invalidPayload(
                    reason: "The materialized layout pages do not match the validated segment."
                )
            }
            return LayoutPreparedMutation(
                segmentID: validation.segmentID,
                pages: materialization.pages,
                facetRootDigest: materialization.facetRootDigest,
                changeContributionDigest: materialization.facetRootDigest
            )
        } catch let error as DesignDatabaseRuntimeMutationAdapterError {
            throw error
        } catch {
            throw .invalidPayload(
                reason: "The validated layout input could not be materialized: \(error)"
            )
        }
    }

    private func validateSourcePDK(
        _ binding: PDKDatabaseFacetSourceBinding,
        context: DesignDatabaseRuntimeMutationValidation,
        diagnosticsDigest: ContentDigest
    ) throws(DesignDatabaseRuntimeMutationAdapterError) {
        guard binding.sourceRevision == context.baseRevision else {
            throw .validationFailed(
                diagnostics: [
                    DesignDiagnostic(
                        code: .trusted("LAYOUT_PDK_REVISION_MISMATCH"),
                        severity: .error,
                        summary: "The layout is not bound to the exact base revision."
                    ),
                ],
                diagnosticsDigest: diagnosticsDigest
            )
        }
        let pdkFacetID: DesignFacetID
        do {
            pdkFacetID = try PDKDatabaseFacet.process.designFacetID
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard let actualRoot = context.baseFacetRoots.first(where: {
            $0.facetID == pdkFacetID
        })?.digest else {
            throw .validationFailed(
                diagnostics: [
                    DesignDiagnostic(
                        code: .trusted("LAYOUT_PDK_SOURCE_MISSING"),
                        severity: .error,
                        summary: "The exact base revision has no canonical PDK process facet."
                    ),
                ],
                diagnosticsDigest: diagnosticsDigest
            )
        }
        guard actualRoot == binding.sourceRootDigest else {
            throw .validationFailed(
                diagnostics: [
                    DesignDiagnostic(
                        code: .trusted("LAYOUT_PDK_ROOT_MISMATCH"),
                        severity: .error,
                        summary: "The layout is stale for the exact PDK process root.",
                        detail: "Expected \(binding.sourceRootDigest.hexadecimalValue), actual \(actualRoot.hexadecimalValue)."
                    ),
                ],
                diagnosticsDigest: diagnosticsDigest
            )
        }
    }

    private func validateLayers(
        in document: LayoutDocument,
        against pdk: PDKDatabaseProcessState,
        diagnosticsDigest: ContentDigest
    ) throws(DesignDatabaseRuntimeMutationAdapterError) {
        var knownNames = Set<String>()
        for layer in pdk.layers {
            knownNames.insert(layer.name)
            knownNames.formUnion(layer.aliases)
        }
        var diagnostics: [DesignDiagnostic] = []
        var reported = Set<String>()
        for cell in document.cells {
            let layers = cell.shapes.map(\.layer)
                + cell.labels.map(\.layer)
                + cell.pins.map(\.layer)
            for layer in layers where !knownNames.contains(layer.name) {
                guard reported.insert(layer.name).inserted else { continue }
                diagnostics.append(
                    DesignDiagnostic(
                        code: .trusted("LAYOUT_PDK_LAYER_MISSING"),
                        severity: .error,
                        summary: "A layout layer name does not resolve in the exact PDK process state.",
                        detail: layer.name
                    )
                )
            }
        }
        guard diagnostics.isEmpty else {
            throw .validationFailed(
                diagnostics: diagnostics,
                diagnosticsDigest: diagnosticsDigest
            )
        }
    }

    private static func diagnostic(
        _ finding: LayoutDocumentValidationFinding
    ) -> DesignDiagnostic {
        DesignDiagnostic(
            code: .trusted(finding.code),
            severity: finding.severity == .warning ? .warning : .error,
            summary: finding.summary,
            detail: finding.entityID
        )
    }
}
