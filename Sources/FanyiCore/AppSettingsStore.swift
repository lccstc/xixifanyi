import Foundation

@MainActor
public final class AppSettingsStore: ObservableObject {
    private enum Keys {
        static let configuration = "configuration"
        static let apiKeyAccount = "translation-api-key"
    }

    @Published public var configuration: AppConfiguration
    @Published public var apiKey: String

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
        if let data = defaults.data(forKey: Keys.configuration),
           let decoded = try? decoder.decode(AppConfiguration.self, from: data) {
            var normalized = decoded
            normalized.screenshotHotKey = normalized.screenshotHotKey.normalized()
            normalized.selectionHotKey = normalized.selectionHotKey.normalized()
            normalized.draftHotKey = normalized.draftHotKey.normalized()
            self.configuration = normalized
        } else {
            self.configuration = .default
        }
        self.apiKey = keychain.read(account: Keys.apiKeyAccount) ?? ""
    }

    public func save() {
        if let data = try? encoder.encode(configuration) {
            defaults.set(data, forKey: Keys.configuration)
        }
        keychain.write(apiKey, account: Keys.apiKeyAccount)
    }
}
