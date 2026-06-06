import Foundation

public enum TranslationScene: String, Codable, CaseIterable, Sendable {
    case screenshotOCR
    case selection
    case chatDraft
}

public struct TranslationRequest: Equatable, Sendable {
    public var text: String
    public var targetLanguage: String
    public var scene: TranslationScene
    public var context: String?

    public init(text: String, targetLanguage: String, scene: TranslationScene, context: String? = nil) {
        self.text = text
        self.targetLanguage = targetLanguage
        self.scene = scene
        self.context = context
    }
}

public struct TranslationResult: Equatable, Sendable {
    public var translatedText: String
    public var detectedSourceLanguage: String?

    public init(translatedText: String, detectedSourceLanguage: String? = nil) {
        self.translatedText = translatedText
        self.detectedSourceLanguage = detectedSourceLanguage
    }
}

public enum TranslationClientError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidBaseURL
    case emptyInput
    case emptyResponse
    case httpError(Int, String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "尚未配置 API Key。"
        case .invalidBaseURL:
            "API Base URL 无效。"
        case .emptyInput:
            "没有可翻译的文本。"
        case .emptyResponse:
            "翻译接口返回为空。"
        case let .httpError(statusCode, body):
            "翻译接口返回 HTTP \(statusCode)：\(body)"
        case let .decodingError(message):
            "无法解析翻译接口返回：\(message)"
        }
    }
}

public struct HotKeyConfig: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var displayName: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayName = displayName
    }

    public func normalized() -> HotKeyConfig {
        if carbonModifiers == 0x0500, displayName.contains("Control"), displayName.contains("Option") {
            return HotKeyConfig(keyCode: keyCode, carbonModifiers: 0x1800, displayName: displayName.replacingOccurrences(of: "Control + Option", with: "⌃ + ⌥"))
        }
        if displayName.contains("Control") || displayName.contains("Option") || displayName.contains("Command") || displayName.contains("Shift") {
            let normalizedName = displayName
                .replacingOccurrences(of: "Control", with: "⌃")
                .replacingOccurrences(of: "Option", with: "⌥")
                .replacingOccurrences(of: "Command", with: "⌘")
                .replacingOccurrences(of: "Shift", with: "⇧")
            return HotKeyConfig(keyCode: keyCode, carbonModifiers: carbonModifiers, displayName: normalizedName)
        }
        return self
    }
}

public struct PromptTemplateSet: Codable, Equatable, Sendable {
    public var screenshotOCR: String
    public var selection: String
    public var chatDraft: String

    public init(screenshotOCR: String, selection: String, chatDraft: String) {
        self.screenshotOCR = screenshotOCR
        self.selection = selection
        self.chatDraft = chatDraft
    }

    public func template(for scene: TranslationScene) -> String {
        switch scene {
        case .screenshotOCR:
            screenshotOCR
        case .selection:
            selection
        case .chatDraft:
            chatDraft
        }
    }

    public static let `default` = PromptTemplateSet(
        screenshotOCR: """
        You are a concise game translation engine.
        Translate the user's OCR text into {targetLanguage}.
        The text may come from game UI, quests, dialogue, item descriptions, menus, or subtitles.
        Preserve game terms, item names, character names, numbers, hotkeys, and UI labels when appropriate.
        If OCR text is fragmented, infer the most likely meaning without adding extra explanation.
        Output only the translation.
        """,
        selection: """
        You are a concise translation engine.
        Translate the user's selected text into {targetLanguage}.
        Keep meaning, formatting, names, URLs, numbers, and code-like tokens intact.
        Do not explain. Output only the translation.
        """,
        chatDraft: """
        You help the user communicate naturally in chat apps.
        Translate the user's draft into natural {targetLanguage}.
        Keep the tone casual, direct, and friendly unless the source text is formal.
        Do not explain. Output only the translated message.
        """
    )
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var apiBaseURL: String
    public var model: String
    public var targetLanguage: String
    public var requestTimeoutSeconds: Double
    public var screenshotHotKey: HotKeyConfig
    public var selectionHotKey: HotKeyConfig
    public var draftHotKey: HotKeyConfig
    public var promptTemplates: PromptTemplateSet

    public init(
        apiBaseURL: String,
        model: String,
        targetLanguage: String,
        requestTimeoutSeconds: Double,
        screenshotHotKey: HotKeyConfig,
        selectionHotKey: HotKeyConfig,
        draftHotKey: HotKeyConfig,
        promptTemplates: PromptTemplateSet = .default
    ) {
        self.apiBaseURL = apiBaseURL
        self.model = model
        self.targetLanguage = targetLanguage
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.screenshotHotKey = screenshotHotKey
        self.selectionHotKey = selectionHotKey
        self.draftHotKey = draftHotKey
        self.promptTemplates = promptTemplates
    }

    private enum CodingKeys: String, CodingKey {
        case apiBaseURL
        case model
        case targetLanguage
        case requestTimeoutSeconds
        case screenshotHotKey
        case selectionHotKey
        case draftHotKey
        case promptTemplates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.apiBaseURL = try container.decode(String.self, forKey: .apiBaseURL)
        self.model = try container.decode(String.self, forKey: .model)
        self.targetLanguage = try container.decode(String.self, forKey: .targetLanguage)
        self.requestTimeoutSeconds = try container.decode(Double.self, forKey: .requestTimeoutSeconds)
        self.screenshotHotKey = try container.decode(HotKeyConfig.self, forKey: .screenshotHotKey)
        self.selectionHotKey = try container.decode(HotKeyConfig.self, forKey: .selectionHotKey)
        self.draftHotKey = try container.decode(HotKeyConfig.self, forKey: .draftHotKey)
        self.promptTemplates = try container.decodeIfPresent(PromptTemplateSet.self, forKey: .promptTemplates) ?? .default
    }

    public static let `default` = AppConfiguration(
        apiBaseURL: "https://api.openai.com/v1",
        model: "gpt-4o-mini",
        targetLanguage: "中文",
        requestTimeoutSeconds: 30,
        screenshotHotKey: HotKeyConfig(keyCode: 19, carbonModifiers: 0x1800, displayName: "⌃ + ⌥ + 2"),
        selectionHotKey: HotKeyConfig(keyCode: 20, carbonModifiers: 0x1800, displayName: "⌃ + ⌥ + 3"),
        draftHotKey: HotKeyConfig(keyCode: 21, carbonModifiers: 0x1800, displayName: "⌃ + ⌥ + 4"),
        promptTemplates: .default
    )
}
