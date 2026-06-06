import Foundation

public protocol TranslationClient: Sendable {
    func translate(_ request: TranslationRequest, configuration: AppConfiguration, apiKey: String) async throws -> TranslationResult
}

public struct OpenAITranslationClient: TranslationClient {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func translate(_ request: TranslationRequest, configuration: AppConfiguration, apiKey: String) async throws -> TranslationResult {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationClientError.emptyInput }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationClientError.missingAPIKey
        }
        guard let endpoint = Self.chatCompletionsEndpoint(from: configuration.apiBaseURL) else {
            throw TranslationClientError.invalidBaseURL
        }

        var urlRequest = URLRequest(url: endpoint, timeoutInterval: configuration.requestTimeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try encoder.encode(OpenAIChatRequest(
            model: configuration.model,
            messages: [
                .init(role: "system", content: TranslationPromptBuilder.systemPrompt(for: request, configuration: configuration)),
                .init(role: "user", content: TranslationPromptBuilder.userPrompt(for: request))
            ],
            temperature: 0.2
        ))

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationClientError.emptyResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TranslationClientError.httpError(httpResponse.statusCode, body)
        }

        do {
            let decoded = try decoder.decode(OpenAIChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
                throw TranslationClientError.emptyResponse
            }
            return TranslationResult(translatedText: content, detectedSourceLanguage: nil)
        } catch let error as TranslationClientError {
            throw error
        } catch {
            throw TranslationClientError.decodingError(error.localizedDescription)
        }
    }

    public static func chatCompletionsEndpoint(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed), let scheme = components.scheme, !scheme.isEmpty else {
            return nil
        }
        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        if !path.hasSuffix("/chat/completions") {
            path += "/chat/completions"
        }
        components.path = path
        components.query = nil
        return components.url
    }
}

private struct OpenAIChatRequest: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    var model: String
    var messages: [Message]
    var temperature: Double
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String
        }

        var message: Message
    }

    var choices: [Choice]
}
