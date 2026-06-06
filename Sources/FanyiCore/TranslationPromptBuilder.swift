import Foundation

public enum TranslationPromptBuilder {
    public static func systemPrompt(for request: TranslationRequest, configuration: AppConfiguration) -> String {
        let rawTemplate = configuration.promptTemplates.template(for: request.scene)
        let fallbackTemplate = PromptTemplateSet.default.template(for: request.scene)
        let template = rawTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackTemplate : rawTemplate
        return render(
            template,
            request: request,
            targetLanguage: request.targetLanguage
        )
    }

    public static func systemPrompt(for scene: TranslationScene, targetLanguage: String) -> String {
        let request = TranslationRequest(text: "", targetLanguage: targetLanguage, scene: scene)
        return render(PromptTemplateSet.default.template(for: scene), request: request, targetLanguage: targetLanguage)
    }

    public static func userPrompt(for request: TranslationRequest) -> String {
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let context = request.context?.trimmingCharacters(in: .whitespacesAndNewlines), !context.isEmpty else {
            return trimmed
        }
        return """
        Context:
        \(context)

        Text:
        \(trimmed)
        """
    }

    public static func render(_ template: String, request: TranslationRequest, targetLanguage: String) -> String {
        let context = request.context?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sourceText = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return template
            .replacingOccurrences(of: "{targetLanguage}", with: targetLanguage)
            .replacingOccurrences(of: "{sourceText}", with: sourceText)
            .replacingOccurrences(of: "{context}", with: context)
            .replacingOccurrences(of: "{scene}", with: request.scene.rawValue)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
