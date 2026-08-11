import Database
import DesignDatabaseRuntime
import LayoutDesignDatabaseSchema

extension LayoutDesignDatabaseRuntimeAdapter:
    DesignDatabaseRuntimePhysicalWriteReclaimer
{
    static let physicalStorageType =
        "LayoutDesignDatabaseSchema.LayoutDatabaseFacetPage.v1"

    public var storageType: String { Self.physicalStorageType }

    public func deleteImmutableWrite(
        _ identity: DesignDatabaseRuntimeImmutableWriteIdentity,
        from transaction: any DatabaseTransactionWriting
    ) async throws(DesignDatabaseRuntimePhysicalWriteReclaimerError) {
        let components = try DesignDatabaseRuntimePhysicalWriteDeletion
            .requirePartitionComponents(identity, storageType: storageType, count: 2)
        var partition = DirectoryPath<LayoutDatabaseFacetPage>()
        partition.set(LayoutDatabaseFacetPage.fields.facetID, to: components[0])
        partition.set(LayoutDatabaseFacetPage.fields.documentDigest, to: components[1])
        try await DesignDatabaseRuntimePhysicalWriteDeletion.delete(
            identity,
            model: LayoutDatabaseFacetPage.self,
            identifiedBy: identity.modelID,
            in: partition,
            expectedIdentity: Self.physicalWriteIdentity,
            from: transaction
        )
    }

    static func physicalWriteIdentity(
        _ page: LayoutDatabaseFacetPage
    ) throws(DesignDatabaseRuntimePreparedMutationError)
        -> DesignDatabaseRuntimeImmutableWriteIdentity {
        try DesignDatabaseRuntimeImmutableWriteIdentity(
            storageType: physicalStorageType,
            partitionComponents: [page.facetID, page.documentDigest],
            modelID: page.id
        )
    }
}
