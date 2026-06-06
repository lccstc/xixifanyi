import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var store: AppSettingsStore
    private let onSave: () -> Void
    private let client: TranslationClient
    @State private var isTestingAPI = false
    @State private var apiTestMessage = ""
    @State private var apiTestSucceeded: Bool?

    public init(store: AppSettingsStore, client: TranslationClient = OpenAITranslationClient(), onSave: @escaping () -> Void) {
        self.store = store
        self.client = client
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSection(title: "翻译接口") {
                    LabeledField(title: "接口地址") {
                        TextField("https://api.openai.com/v1", text: $store.configuration.apiBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(title: "模型") {
                        TextField("gpt-4o-mini / deepseek-chat / qwen...", text: $store.configuration.model)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(title: "密钥") {
                        SecureField("输入你的 API Key", text: $store.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(title: "默认目标语言") {
                        TextField("中文", text: $store.configuration.targetLanguage)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(title: "请求超时") {
                        HStack(spacing: 12) {
                            Slider(value: $store.configuration.requestTimeoutSeconds, in: 5...120, step: 5)
                            Text("\(Int(store.configuration.requestTimeoutSeconds)) 秒")
                                .frame(width: 56, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(isTestingAPI ? "测试中..." : "测试 API") {
                                testAPI()
                            }
                            .disabled(isTestingAPI)
                            Button("保存") {
                                save()
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                        if !apiTestMessage.isEmpty {
                            Text(apiTestMessage)
                                .foregroundStyle(apiTestSucceeded == true ? .green : .red)
                                .font(.callout)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                SettingsSection(title: "快捷键") {
                    HotKeyEditor(title: "截图 OCR 翻译", config: $store.configuration.screenshotHotKey)
                    HotKeyEditor(title: "划词翻译", config: $store.configuration.selectionHotKey)
                    HotKeyEditor(title: "聊天草稿", config: $store.configuration.draftHotKey)
                }

                SettingsSection(title: "提示词模板") {
                    Text("可用占位符：{targetLanguage}、{sourceText}、{context}、{scene}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PromptTemplateEditor(title: "截图 OCR 翻译", template: $store.configuration.promptTemplates.screenshotOCR)
                    PromptTemplateEditor(title: "划词翻译", template: $store.configuration.promptTemplates.selection)
                    PromptTemplateEditor(title: "聊天草稿", template: $store.configuration.promptTemplates.chatDraft)
                    Button("恢复默认提示词") {
                        store.configuration.promptTemplates = .default
                    }
                }

                SettingsSection(title: "系统权限") {
                    PermissionRow(title: "屏幕录制", description: "截图 OCR 翻译需要此权限。", granted: PermissionService.hasScreenCapturePermission()) {
                        PermissionService.requestScreenCapturePermission()
                    }
                    PermissionRow(title: "辅助功能", description: "划词翻译和复制兜底需要此权限。授权后请完全退出并重新打开 App。", granted: PermissionService.hasAccessibilityPermission()) {
                        PermissionService.requestAccessibilityPermission()
                    }
                }

                HStack {
                    Spacer()
                    Button("保存设置") {
                        save()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
        }
        .frame(minWidth: 720, minHeight: 760)
    }

    private func save() {
        store.save()
        onSave()
    }

    private func testAPI() {
        isTestingAPI = true
        apiTestMessage = ""
        apiTestSucceeded = nil
        save()

        Task {
            do {
                let result = try await APIConnectionTester.test(
                    configuration: store.configuration,
                    apiKey: store.apiKey,
                    client: client
                )
                await MainActor.run {
                    apiTestSucceeded = true
                    apiTestMessage = "测试成功：\(result.translatedText)"
                    isTestingAPI = false
                    onSave()
                }
            } catch {
                await MainActor.run {
                    apiTestSucceeded = false
                    apiTestMessage = error.localizedDescription
                    isTestingAPI = false
                }
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct LabeledField<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                Text(title)
                    .foregroundStyle(.secondary)
                    .frame(width: 116, alignment: .trailing)
                content
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct HotKeyEditor: View {
    var title: String
    @Binding var config: HotKeyConfig

    var body: some View {
        LabeledField(title: title) {
            HStack(spacing: 10) {
                HotKeyRecorderView(config: $config)
                    .frame(width: 240, height: 30)
                Text("点击按钮后直接按新的组合键，支持 F1-F19。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PromptTemplateEditor: View {
    var title: String
    @Binding var template: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            TextEditor(text: $template)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 118)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.28))
                )
        }
    }
}

private struct PermissionRow: View {
    var title: String
    var description: String
    var granted: Bool
    var request: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(granted ? "已授权" : "未授权")
                .foregroundStyle(granted ? .green : .red)
                .frame(width: 56, alignment: .trailing)
            Button("请求权限", action: request)
        }
    }
}
