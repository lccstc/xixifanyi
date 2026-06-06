import FanyiCore
import AppKit
import Foundation

@discardableResult
@MainActor
func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        print("PASS: \(message)")
        return true
    } else {
        print("FAIL: \(message)")
        failures += 1
        return false
    }
}

var failures = 0

let screenshotPrompt = TranslationPromptBuilder.systemPrompt(for: .screenshotOCR, targetLanguage: "中文")
check(screenshotPrompt.contains("game"), "screenshot prompt mentions game context")
check(screenshotPrompt.contains("Output only the translation"), "screenshot prompt forbids explanations")
check(screenshotPrompt.contains("中文"), "screenshot prompt includes target language")

let chatPrompt = TranslationPromptBuilder.systemPrompt(for: .chatDraft, targetLanguage: "English")
check(chatPrompt.contains("chat apps"), "chat draft prompt targets chat apps")
check(chatPrompt.contains("natural English"), "chat draft prompt asks for natural English")

let request = TranslationRequest(
    text: "  Press E to interact  ",
    targetLanguage: "中文",
    scene: .screenshotOCR,
    context: "RPG dialogue"
)
let userPrompt = TranslationPromptBuilder.userPrompt(for: request)
check(userPrompt.contains("Context:"), "user prompt includes context label")
check(userPrompt.contains("RPG dialogue"), "user prompt includes context body")
check(userPrompt.contains("Press E to interact"), "user prompt trims selected text")

let endpoint = OpenAITranslationClient.chatCompletionsEndpoint(from: "https://example.com/v1")
check(endpoint?.absoluteString == "https://example.com/v1/chat/completions", "endpoint appends chat completions")

let existingEndpoint = OpenAITranslationClient.chatCompletionsEndpoint(from: "https://example.com/v1/chat/completions")
check(existingEndpoint?.absoluteString == "https://example.com/v1/chat/completions", "endpoint does not duplicate chat completions")

let configuration = AppConfiguration.default
check(configuration.targetLanguage == "中文", "default target language is Chinese")
check(configuration.screenshotHotKey.displayName == "⌃ + ⌥ + 2", "default screenshot hotkey is configured")
check(configuration.selectionHotKey.displayName == "⌃ + ⌥ + 3", "default selection hotkey is configured")
check(configuration.draftHotKey.displayName == "⌃ + ⌥ + 4", "default draft hotkey is configured")
check(configuration.screenshotHotKey.carbonModifiers == 0x1800, "default hotkeys use Carbon Control + Option modifiers")
check(configuration.promptTemplates.screenshotOCR.contains("{targetLanguage}"), "default screenshot prompt is configurable")

var customPromptConfiguration = configuration
customPromptConfiguration.promptTemplates.selection = "Translate into {targetLanguage}. Scene={scene}. Context={context}. Text={sourceText}"
let customPrompt = TranslationPromptBuilder.systemPrompt(
    for: TranslationRequest(text: "Hello", targetLanguage: "中文", scene: .selection, context: "chat"),
    configuration: customPromptConfiguration
)
check(customPrompt == "Translate into 中文. Scene=selection. Context=chat. Text=Hello", "custom prompt placeholders render")

customPromptConfiguration.promptTemplates.selection = "   "
let fallbackPrompt = TranslationPromptBuilder.systemPrompt(
    for: TranslationRequest(text: "Hello", targetLanguage: "中文", scene: .selection),
    configuration: customPromptConfiguration
)
check(fallbackPrompt.contains("Translate the user's selected text into 中文"), "blank custom prompt falls back to default")

do {
    _ = try await OpenAITranslationClient().translate(
        TranslationRequest(text: "   ", targetLanguage: "中文", scene: .selection),
        configuration: configuration,
        apiKey: "test-key"
    )
    check(false, "empty input throws before network")
} catch TranslationClientError.emptyInput {
    check(true, "empty input throws before network")
} catch {
    check(false, "empty input throws expected error")
}

do {
    _ = try await OpenAITranslationClient().translate(
        TranslationRequest(text: "Hello", targetLanguage: "中文", scene: .selection),
        configuration: configuration,
        apiKey: ""
    )
    check(false, "missing API key throws before network")
} catch TranslationClientError.missingAPIKey {
    check(true, "missing API key throws before network")
} catch {
    check(false, "missing API key throws expected error")
}

do {
    var invalidConfiguration = configuration
    invalidConfiguration.apiBaseURL = "not a url"
    _ = try await OpenAITranslationClient().translate(
        TranslationRequest(text: "Hello", targetLanguage: "中文", scene: .selection),
        configuration: invalidConfiguration,
        apiKey: "test-key"
    )
    check(false, "invalid API base URL throws before network")
} catch TranslationClientError.invalidBaseURL {
    check(true, "invalid API base URL throws before network")
} catch {
    check(false, "invalid API base URL throws expected error")
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var responseBody = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

let sessionConfiguration = URLSessionConfiguration.ephemeral
sessionConfiguration.protocolClasses = [MockURLProtocol.self]
let mockedClient = OpenAITranslationClient(session: URLSession(configuration: sessionConfiguration))

MockURLProtocol.statusCode = 200
MockURLProtocol.responseBody = Data("""
{"choices":[{"message":{"content":"开始任务"}}]}
""".utf8)
do {
    let result = try await mockedClient.translate(
        TranslationRequest(text: "Start Quest", targetLanguage: "中文", scene: .screenshotOCR),
        configuration: configuration,
        apiKey: "test-key"
    )
    check(result.translatedText == "开始任务", "OpenAI-compatible success response parses translated text")
    check(MockURLProtocol.lastRequest?.url?.absoluteString == "https://api.openai.com/v1/chat/completions", "OpenAI-compatible request uses chat completions endpoint")
    check(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-key", "OpenAI-compatible request sends bearer token")
} catch {
    check(false, "OpenAI-compatible success response should not throw")
}

MockURLProtocol.statusCode = 401
MockURLProtocol.responseBody = Data("""
{"error":{"message":"bad key"}}
""".utf8)
do {
    _ = try await mockedClient.translate(
        TranslationRequest(text: "Hello", targetLanguage: "中文", scene: .selection),
        configuration: configuration,
        apiKey: "test-key"
    )
    check(false, "HTTP API error throws")
} catch TranslationClientError.httpError(let statusCode, let body) {
    check(statusCode == 401 && body.contains("bad key"), "HTTP API error preserves status and body")
} catch {
    check(false, "HTTP API error throws expected error")
}

struct StubTranslationClient: TranslationClient {
    nonisolated(unsafe) static var lastRequest: TranslationRequest?
    var result: Result<TranslationResult, Error>

    func translate(_ request: TranslationRequest, configuration: AppConfiguration, apiKey: String) async throws -> TranslationResult {
        Self.lastRequest = request
        return try result.get()
    }
}

do {
    let result = try await APIConnectionTester.test(
        configuration: configuration,
        apiKey: "test-key",
        client: StubTranslationClient(result: .success(TranslationResult(translatedText: "连接测试")))
    )
    check(result.translatedText == "连接测试", "API tester returns successful translation")
    check(StubTranslationClient.lastRequest?.text.contains("connection test") == true, "API tester sends connection test text")
    check(StubTranslationClient.lastRequest?.scene == .selection, "API tester uses selection scene")
} catch {
    check(false, "API tester success should not throw")
}

do {
    _ = try await APIConnectionTester.test(
        configuration: configuration,
        apiKey: "",
        client: StubTranslationClient(result: .failure(TranslationClientError.missingAPIKey))
    )
    check(false, "API tester propagates client errors")
} catch TranslationClientError.missingAPIKey {
    check(true, "API tester propagates client errors")
} catch {
    check(false, "API tester propagates expected client error")
}

@MainActor
func makeOCRFixtureImage() -> NSImage {
    let size = NSSize(width: 900, height: 240)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 82),
        .foregroundColor: NSColor.black,
        .paragraphStyle: paragraph
    ]
    NSString(string: "START QUEST").draw(
        in: NSRect(x: 20, y: 70, width: 860, height: 110),
        withAttributes: attributes
    )
    image.unlockFocus()
    return image
}

do {
    let recognizedText = try await OCRService().recognizeText(in: makeOCRFixtureImage())
    let normalized = recognizedText.uppercased()
    check(normalized.contains("START") && normalized.contains("QUEST"), "Vision OCR recognizes generated English fixture")
} catch {
    check(false, "Vision OCR recognizes generated English fixture")
}

let quartzRect = ScreenshotSelectionController.quartzRect(
    from: CGRect(x: 100, y: 120, width: 300, height: 80),
    screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)
)
check(quartzRect == CGRect(x: 100, y: 600, width: 300, height: 80), "screenshot selection converts AppKit rect to Quartz rect")

let testPasteboardName = NSPasteboard.Name("FanyiCoreChecks.\(UUID().uuidString)")
let testPasteboard = NSPasteboard(name: testPasteboardName)
let customType = NSPasteboard.PasteboardType("local.fanyi.binary")
let item = NSPasteboardItem()
item.setString("original text", forType: .string)
item.setData(Data([1, 2, 3, 5, 8]), forType: customType)
testPasteboard.clearContents()
testPasteboard.writeObjects([item])

let snapshot = PasteboardSnapshot.capture(from: testPasteboard)
testPasteboard.clearContents()
testPasteboard.setString("temporary copied text", forType: .string)
snapshot.restore(to: testPasteboard)

check(testPasteboard.string(forType: .string) == "original text", "pasteboard snapshot restores original string")
check(testPasteboard.data(forType: customType) == Data([1, 2, 3, 5, 8]), "pasteboard snapshot restores non-string data")

if failures > 0 {
    exit(1)
}
