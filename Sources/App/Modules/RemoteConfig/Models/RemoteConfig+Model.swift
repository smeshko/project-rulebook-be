import Foundation

extension Array where Element == RemoteConfigModel {
    func toGetResponse() -> RemoteConfig.Get.Response {
        var featureFlags: [String: AnyCodableValue] = [:]
        var settings: [String: AnyCodableValue] = [:]

        for config in self {
            let value = config.parseValue()

            switch config.category {
            case .featureFlag:
                featureFlags[config.key] = value
            case .setting:
                settings[config.key] = value
            }
        }

        return RemoteConfig.Get.Response(
            featureFlags: featureFlags,
            settings: settings
        )
    }
}

extension RemoteConfigModel {
    func parseValue() -> AnyCodableValue {
        switch valueType {
        case .boolean:
            let boolValue = value.lowercased() == "true" || value == "1"
            return .bool(boolValue)
        case .integer:
            let intValue = Int(value) ?? 0
            return .int(intValue)
        case .string:
            return .string(value)
        }
    }

    func toCreateResponse() -> RemoteConfig.Create.Response {
        RemoteConfig.Create.Response(
            id: id!,
            key: key,
            value: value,
            valueType: valueType,
            category: category,
            createdAt: createdAt
        )
    }

    func toUpdateResponse() -> RemoteConfig.Update.Response {
        RemoteConfig.Update.Response(
            id: id!,
            key: key,
            value: value,
            valueType: valueType,
            category: category,
            updatedAt: updatedAt
        )
    }
}
