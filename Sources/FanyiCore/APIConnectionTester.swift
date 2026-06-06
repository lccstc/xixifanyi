import Foundation

public enum APIConnectionTester {
    public static func test(
        configuration: AppConfiguration,
        apiKey: String,
        client: TranslationClient
    ) async throws -> TranslationResult {
        try await client.translate(
            TranslationRequest(
                text: "Hello, this is a connection test.",
                targetLanguage: configuration.targetLanguage,
                scene: .selection,
                context: "API connection test. Return only a short translation."
            ),
            configuration: configuration,
            apiKey: apiKey
        )
    }
}
