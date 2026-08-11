import Foundation

public enum LayoutDatabaseCanonicalCodec {
    public static func encode(
        _ state: LayoutDatabaseState
    ) throws(LayoutDatabaseSchemaError) -> Data {
        try state.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(state)
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
    }

    public static func decode(
        _ data: Data,
        requireCanonicalEncoding: Bool = true
    ) throws(LayoutDatabaseSchemaError) -> LayoutDatabaseState {
        let state: LayoutDatabaseState
        do {
            state = try JSONDecoder().decode(LayoutDatabaseState.self, from: data)
        } catch {
            throw .decodingFailed(reason: String(describing: error))
        }
        try state.validate()
        if requireCanonicalEncoding {
            let canonical = try encode(state)
            guard canonical == data else {
                throw .nonCanonicalPayload
            }
        }
        return state
    }
}
