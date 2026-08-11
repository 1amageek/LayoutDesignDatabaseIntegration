import CircuiteFoundation
import CircuiteFoundationCrypto
import Database
import DesignDatabaseCore
import DesignDatabaseRuntime
import Foundation
import LayoutCore
import LayoutDesignDatabaseRuntimeAdapter
import LayoutDesignDatabaseSchema
import PDKCore
import PDKDesignDatabaseRuntimeAdapter
import PDKDesignDatabaseSchema
import Testing

@Suite("Layout DesignDatabase integration")
struct LayoutDatabaseIntegrationTests {
    @Test("canonical state round-trips independent of identity-keyed ordering")
    func canonicalRoundTrip() throws {
        let fixture = try makeFixture()
        var reordered = fixture.document
        reordered.cells.reverse()
        let state = try LayoutDatabaseState(
            pdk: fixture.pdk,
            sourcePDK: fixture.sourceBinding,
            sourceArtifact: fixture.layoutArtifact,
            document: reordered
        )
        let canonical = try LayoutDatabaseCanonicalCodec.encode(state)

        #expect(state.document.cells.map(\.id) == fixture.document.cells.map(\.id))
        #expect(try LayoutDatabaseCanonicalCodec.decode(canonical) == state)
    }

    @Test("decoded identity arrays must already be canonical")
    func decodedOrderingIsChecked() throws {
        let fixture = try makeFixture()
        let canonical = try LayoutDatabaseCanonicalCodec.encode(fixture.state)
        var object = try #require(
            JSONSerialization.jsonObject(with: canonical) as? [String: Any]
        )
        var document = try #require(object["document"] as? [String: Any])
        var cells = try #require(document["cells"] as? [[String: Any]])
        cells.reverse()
        document["cells"] = cells
        object["document"] = document
        let reordered = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: LayoutDatabaseSchemaError.self) {
            try LayoutDatabaseCanonicalCodec.decode(
                reordered,
                requireCanonicalEncoding: false
            )
        }
    }

    @Test("canonical state rejects structurally invalid layout")
    func invalidDocumentIsRejected() throws {
        let fixture = try makeFixture()
        var invalid = fixture.document
        invalid.cells[1].shapes[0].geometry = .rect(
            LayoutRect(
                origin: .zero,
                size: LayoutSize(width: 0, height: 1)
            )
        )

        #expect(throws: LayoutDatabaseSchemaError.self) {
            try LayoutDatabaseState(
                pdk: fixture.pdk,
                sourcePDK: fixture.sourceBinding,
                sourceArtifact: fixture.layoutArtifact,
                document: invalid
            )
        }
    }

    @Test("stage-produced standard layout is accepted as canonical source evidence")
    func stageOutputSourceArtifactIsAccepted() throws {
        let fixture = try makeFixture()
        let outputArtifact = ArtifactReference(
            id: fixture.layoutArtifact.id,
            descriptor: ArtifactDescriptor(
                role: .output,
                kind: .layout,
                format: .oasis
            )
        )
        let state = try LayoutDatabaseState(
            pdk: fixture.pdk,
            sourcePDK: fixture.sourceBinding,
            sourceArtifact: outputArtifact,
            document: fixture.document
        )

        #expect(state.sourceArtifact == outputArtifact)
    }

    @Test("layout import planner binds one exact base revision")
    func importPlannerRequiresExactBaseRevision() throws {
        let fixture = try makeFixture()
        let differentBase = DesignRevisionReference(
            databaseID: fixture.sourceBinding.sourceRevision.databaseID,
            revisionID: DesignRevisionID(high: 91, low: 92)
        )
        let request = LayoutDatabaseImportRequest(
            pdk: fixture.pdk,
            sourcePDK: fixture.sourceBinding,
            sourceArtifact: fixture.layoutArtifact,
            document: fixture.document,
            segmentID: try DesignMutationPlanSegmentID(
                rawValue: "layout-stage-import"
            ),
            databaseID: differentBase.databaseID,
            baseRevision: differentBase,
            designSchemaBundleDigest: try digest("layout-import-schema"),
            dependencyRootDigest: try digest("layout-import-dependency"),
            semanticDependencyGraphDigest: try digest("layout-import-graph"),
            sourceEvidenceDigest: try digest("layout-import-evidence")
        )

        #expect(throws: LayoutDatabaseImportPlanningError.self) {
            try LayoutDatabaseImportPlanner().compileImport(request)
        }
    }

    @Test("exact PDK binding controls admission and snapshot invalidation")
    func exactPDKBindingAndInvalidation() async throws {
        let fixture = try makeFixture()
        let harness = try await makeHarness()
        let handle = harness.handle
        let genesis = handle.genesisRevision

        let pdkReceipt = try await commitPDK(
            fixture.pdk,
            operation: "import-layout-pdk-v1",
            segment: "layout-pdk-v1",
            base: genesis,
            handle: handle
        )
        let boundState = try boundState(
            fixture,
            revision: pdkReceipt.candidateRevision,
            roots: pdkReceipt.facetRoots
        )
        var unknownLayerDocument = fixture.document
        unknownLayerDocument.cells[1].shapes[0].layer = LayoutLayerID(
            name: "UNKNOWN",
            purpose: "drawing"
        )
        let unknownLayerState = try LayoutDatabaseState(
            pdk: fixture.pdk,
            sourcePDK: boundState.sourcePDK,
            sourceArtifact: fixture.layoutArtifact,
            document: unknownLayerDocument
        )
        let rejected = try await submit(
            try await layoutPlan(
                unknownLayerState,
                segment: "unknown-layer",
                base: pdkReceipt.candidateRevision,
                handle: handle
            ),
            operation: "import-unknown-layout-layer",
            handle: handle,
            expectingCommit: false
        )
        #expect(rejected == nil)

        let layoutReceipt = try #require(
            try await submit(
                layoutPlan(
                    boundState,
                    segment: "layout-v1",
                    base: pdkReceipt.candidateRevision,
                    handle: handle
                ),
                operation: "import-layout-v1",
                handle: handle,
                expectingCommit: true
            )
        )
        let currentSnapshot = try await handle.openSnapshot(
            at: layoutReceipt.candidateRevision
        )
        let current = try await LayoutDesignDatabaseSnapshotReader().readState(
            from: currentSnapshot,
            budget: LayoutDatabaseReadBudget()
        )
        #expect(current.layout == boundState)
        #expect(current.invalidation == nil)
        #expect(current.isSemanticallyCurrent)
        #expect(await currentSnapshot.close() == .closed)

        var changedManifest = try fixture.pdk.validationManifest()
        changedManifest.version = "1.0.1"
        let changedPDK = try PDKDatabaseProcessState(
            manifest: changedManifest,
            manifestArtifact: try artifact(
                byte: "2f",
                kind: "pdk.technology",
                format: .json
            ),
            assetArtifacts: Dictionary(
                uniqueKeysWithValues: fixture.pdk.assets.map {
                    ($0.assetID, $0.content)
                }
            )
        )
        let changedReceipt = try await commitPDK(
            changedPDK,
            operation: "import-layout-pdk-v2",
            segment: "layout-pdk-v2",
            base: layoutReceipt.candidateRevision,
            handle: handle
        )
        let staleSnapshot = try await handle.openSnapshot(
            at: changedReceipt.candidateRevision
        )
        let stale = try await LayoutDesignDatabaseSnapshotReader().readState(
            from: staleSnapshot,
            budget: LayoutDatabaseReadBudget()
        )
        #expect(stale.layout == boundState)
        #expect(stale.invalidation?.reason == .sourceRootChanged)
        #expect(!stale.isSemanticallyCurrent)
        #expect(await staleSnapshot.close() == .closed)
        #expect(try await handle.resolve(.named(.main)) == genesis)
        #expect(await handle.close() == .closed)
        #expect(await harness.provider.close() == .closed)
    }

    private func makeHarness() async throws -> (
        provider: DesignDatabaseRuntimeProvider,
        handle: any DesignDatabaseHandle
    ) {
        let registration = try DesignDatabaseRuntimeRegistrationBuilder().build(
            schemaVersion: Schema.Version(1, 0, 0),
            contributions: [
                try PDKDesignDatabaseRuntimeAdapter().contribution(),
                try LayoutDesignDatabaseRuntimeAdapter().contribution(),
            ]
        )
        let locator = try DesignDatabaseLocator(
            namespace: "tests",
            segments: ["layout-integration"]
        )
        let databaseID = try DesignDatabaseID(high: 21, low: 22)
        let genesisRevisionID = DesignRevisionID(high: 0, low: 1)
        let subjectScopeID = try DesignAuthorizationSubjectScopeID(high: 23, low: 24)
        let operationID = try DesignDatabaseOperationID(rawValue: "create-layout")
        let capabilities = try DesignCapabilitySet([])
        let canonical = try DesignDatabaseRuntimeGenesisRequest(
            locator: locator,
            databaseID: databaseID,
            genesisRevisionID: genesisRevisionID,
            authorizationSubjectScopeID: subjectScopeID,
            operationID: operationID,
            declaredFeatureCapabilities: capabilities,
            initialSchemaBundle: registration.designSchemaBundle,
            registrationDigest: registration.registrationDigest
        )
        let provider = DesignDatabaseRuntimeProvider(
            registration: registration,
            containerProvider: LayoutDatabaseTestContainerProvider(),
            authorizationSubjectScopeID: subjectScopeID,
            creationRequestedAuthorization: DesignDatabaseAuthorizationGrantSet([
                .read,
                .proposeCandidate,
                .inspectOwnOperationOutcome,
            ]),
            authorizer: LayoutDatabaseTestAuthorizer()
        )
        let handle = try await provider.create(
            DesignDatabaseCreateRequest(
                locator: locator,
                databaseID: databaseID,
                genesisRevisionID: genesisRevisionID,
                operationID: operationID,
                initialSchemaBundle: registration.designSchemaBundle,
                declaredFeatureCapabilities: capabilities,
                requestDigest: canonical.requestDigest
            )
        )
        return (provider, handle)
    }

    private func commitPDK(
        _ state: PDKDatabaseProcessState,
        operation: String,
        segment: String,
        base: DesignRevisionReference,
        handle: any DesignDatabaseHandle
    ) async throws -> DesignCommitReceipt {
        let snapshot = try await handle.openSnapshot(at: base)
        let plan: DesignMutationPlan
        do {
            plan = try PDKDatabaseMutationPlanCompiler().compile(
                state,
                segmentID: DesignMutationPlanSegmentID(rawValue: segment),
                databaseID: handle.databaseID,
                baseRevision: base,
                designSchemaBundleDigest: snapshot.designSchemaBundleDigest,
                dependencyRootDigest: snapshot.dependencyRootDigest,
                semanticDependencyGraphDigest: snapshot.semanticDependencyGraphDigest,
                sourceEvidenceDigest: try digest("\(operation)-evidence")
            )
            _ = await snapshot.close()
        } catch {
            _ = await snapshot.close()
            throw error
        }
        return try #require(
            try await submit(
                plan,
                operation: operation,
                handle: handle,
                expectingCommit: true
            )
        )
    }

    private func layoutPlan(
        _ state: LayoutDatabaseState,
        segment: String,
        base: DesignRevisionReference,
        handle: any DesignDatabaseHandle
    ) async throws -> DesignMutationPlan {
        let snapshot = try await handle.openSnapshot(at: base)
        do {
            let plan = try LayoutDatabaseMutationPlanCompiler().compile(
                state,
                segmentID: DesignMutationPlanSegmentID(rawValue: segment),
                databaseID: handle.databaseID,
                baseRevision: base,
                designSchemaBundleDigest: snapshot.designSchemaBundleDigest,
                dependencyRootDigest: snapshot.dependencyRootDigest,
                semanticDependencyGraphDigest: snapshot.semanticDependencyGraphDigest,
                sourceEvidenceDigest: try digest("\(segment)-evidence")
            )
            _ = await snapshot.close()
            return plan
        } catch {
            _ = await snapshot.close()
            throw error
        }
    }

    private func submit(
        _ plan: DesignMutationPlan,
        operation: String,
        handle: any DesignDatabaseHandle,
        expectingCommit: Bool
    ) async throws -> DesignCommitReceipt? {
        let operationID = try DesignDatabaseOperationID(rawValue: operation)
        let submission = DesignCommitSubmission(
            operationID: operationID,
            plan: plan,
            requestDigest: try DesignMutationPlanDigest.request(
                operationID: operationID,
                planDigest: plan.planDigest,
                using: SHA256ContentDigester()
            )
        )
        switch try await handle.submit(submission) {
        case .committed(let receipt):
            if !expectingCommit {
                Issue.record("A rejected layout operation committed a candidate.")
            }
            return receipt
        case .rejected(let rejection):
            if expectingCommit {
                throw LayoutIntegrationTestFailure("Candidate rejected: \(rejection)")
            }
            guard case .validationFailed(let diagnostics, _) = rejection.reason else {
                Issue.record("The layout rejection lacked typed diagnostics.")
                return nil
            }
            #expect(diagnostics.contains {
                $0.code.rawValue == "LAYOUT_PDK_LAYER_MISSING"
            })
            return nil
        case .outcomeUnknown:
            throw LayoutIntegrationTestFailure("Candidate outcome was unknown.")
        }
    }

    private func boundState(
        _ fixture: LayoutFixture,
        revision: DesignRevisionReference,
        roots: [DesignFacetRoot]
    ) throws -> LayoutDatabaseState {
        let pdkFacetID = try PDKDatabaseFacet.process.designFacetID
        guard let root = roots.first(where: { $0.facetID == pdkFacetID })?.digest else {
            throw LayoutIntegrationTestFailure("The PDK facet root is missing.")
        }
        let binding = try PDKDatabaseFacetSourceBinding(
            sourceRevision: revision,
            sourceRootDigest: root
        )
        return try LayoutDatabaseState(
            pdk: fixture.pdk,
            sourcePDK: binding,
            sourceArtifact: fixture.layoutArtifact,
            document: fixture.document
        )
    }

    private func digest(_ value: String) throws -> ContentDigest {
        try LayoutDatabaseDigesting.sha256(Array(value.utf8))
    }
}

private struct LayoutIntegrationTestFailure: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

private struct LayoutFixture {
    let pdk: PDKDatabaseProcessState
    let sourceBinding: PDKDatabaseFacetSourceBinding
    let layoutArtifact: ArtifactReference
    let document: LayoutDocument
    let state: LayoutDatabaseState
}

private func makeFixture() throws -> LayoutFixture {
    let formats: [(String, PDKAssetRole, ArtifactKind, ArtifactFormat)] = [
        ("lef", .lef, .technology, .lef),
        ("gds", .gdsii, .layout, .gdsii),
        ("spice", .spice, .model, .spice),
        ("liberty", .liberty, .model, .liberty),
    ]
    let manifest = PDKManifest(
        processID: "fixture-process",
        version: "1.0.0",
        assets: formats.map { id, role, kind, format in
            PDKAssetReference(
                assetID: id,
                role: role,
                path: "\(id).\(format.rawValue)",
                kind: kind,
                format: format,
                cornerIDs: id == "spice" || id == "liberty" ? ["tt"] : []
            )
        },
        layers: [
            PDKLayerDefinition(
                layerID: "metal1",
                name: "M1",
                number: 10,
                purpose: .metal,
                isRoutingLayer: true,
                aliases: ["MET1"]
            ),
        ],
        devices: [
            PDKDeviceDefinition(
                deviceID: "nmos",
                modelName: "nmos_model",
                terminals: [
                    PDKDeviceTerminal(name: "D", role: .output, order: 0),
                ]
            ),
        ],
        corners: [
            PDKCornerDefinition(
                cornerID: "tt",
                pvt: PDKPVTCondition(
                    process: PDKProcessCorner(name: "tt", nominal: true),
                    voltage: 1.8,
                    temperatureCelsius: 25
                ),
                assetIDs: ["spice", "liberty"]
            ),
        ],
        crossViewMappings: [
            PDKCrossViewMapping(
                mappingID: "lef-map",
                view: .lef,
                assetID: "lef",
                deviceIDs: ["nmos"]
            ),
            PDKCrossViewMapping(
                mappingID: "gds-map",
                view: .gdsii,
                assetID: "gds",
                layerIDs: ["metal1"]
            ),
            PDKCrossViewMapping(
                mappingID: "spice-map",
                view: .spice,
                assetID: "spice",
                deviceIDs: ["nmos"],
                cornerIDs: ["tt"]
            ),
            PDKCrossViewMapping(
                mappingID: "liberty-map",
                view: .liberty,
                assetID: "liberty",
                deviceIDs: ["nmos"],
                cornerIDs: ["tt"]
            ),
        ]
    )
    var assetArtifacts: [String: ArtifactReference] = [:]
    for (index, item) in formats.enumerated() {
        assetArtifacts[item.0] = try artifact(
            byte: String(format: "%02x", index + 16),
            kind: "pdk.\(item.2.rawValue)",
            format: item.3
        )
    }
    let pdk = try PDKDatabaseProcessState(
        manifest: manifest,
        manifestArtifact: try artifact(
            byte: "0f",
            kind: "pdk.technology",
            format: .json
        ),
        assetArtifacts: assetArtifacts
    )
    let pdkDocument = try PDKDatabaseCanonicalDocument(state: pdk)
    let databaseID = try DesignDatabaseID(high: 1, low: 2)
    let sourceBinding = try PDKDatabaseFacetSourceBinding(
        sourceRevision: DesignRevisionReference(
            databaseID: databaseID,
            revisionID: DesignRevisionID(high: 3, low: 4)
        ),
        sourceRootDigest: pdkDocument.facetRootDigest
    )
    let childID = try #require(
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")
    )
    let topID = try #require(
        UUID(uuidString: "00000000-0000-0000-0000-000000000002")
    )
    let netID = try #require(
        UUID(uuidString: "00000000-0000-0000-0000-000000000003")
    )
    let shapeID = try #require(
        UUID(uuidString: "00000000-0000-0000-0000-000000000004")
    )
    let instanceID = try #require(
        UUID(uuidString: "00000000-0000-0000-0000-000000000005")
    )
    let child = LayoutCell(id: childID, name: "device")
    let top = LayoutCell(
        id: topID,
        name: "top",
        shapes: [
            LayoutShape(
                id: shapeID,
                layer: LayoutLayerID(name: "M1", purpose: "drawing"),
                netID: netID,
                geometry: .rect(
                    LayoutRect(
                        origin: .zero,
                        size: LayoutSize(width: 1, height: 1)
                    )
                )
            ),
        ],
        instances: [
            LayoutInstance(id: instanceID, cellID: childID, name: "X1"),
        ],
        nets: [LayoutNet(id: netID, name: "vdd")]
    )
    let document = LayoutDocument(
        name: "fixture",
        cells: [child, top],
        topCellID: topID
    )
    let layoutArtifact = try artifact(
        byte: "10",
        kind: "layout",
        format: .oasis
    )
    let state = try LayoutDatabaseState(
        pdk: pdk,
        sourcePDK: sourceBinding,
        sourceArtifact: layoutArtifact,
        document: document
    )
    return LayoutFixture(
        pdk: pdk,
        sourceBinding: sourceBinding,
        layoutArtifact: layoutArtifact,
        document: document,
        state: state
    )
}

private func artifact(
    byte: String,
    kind: String,
    format: ArtifactFormat
) throws -> ArtifactReference {
    try ArtifactReference(
        digest: ContentDigest(
            algorithm: .sha256,
            hexadecimalValue: String(repeating: byte, count: 32)
        ),
        byteCount: 100,
        descriptor: ArtifactDescriptor(
            role: .input,
            kind: ArtifactKind(rawValue: kind),
            format: format
        )
    )
}
