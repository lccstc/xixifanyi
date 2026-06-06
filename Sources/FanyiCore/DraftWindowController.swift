import AppKit
import SwiftUI

@MainActor
public final class DraftWindowController {
    private var window: NSWindow?
    private let store: AppSettingsStore
    private let client: TranslationClient

    public init(store: AppSettingsStore, client: TranslationClient) {
        self.store = store
        self.client = client
    }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = DraftView(store: store, client: client)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "聊天草稿翻译"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 520, height: 420))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct DraftView: View {
    @ObservedObject var store: AppSettingsStore
    let client: TranslationClient
    @State private var input = ""
    @State private var output = ""
    @State private var isTranslating = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("草稿")
                .font(.headline)
            TextEditor(text: $input)
                .frame(minHeight: 120)
                .border(Color.secondary.opacity(0.25))
            HStack {
                Button(isTranslating ? "翻译中..." : "翻译成英文") {
                    translate()
                }
                .disabled(isTranslating || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("复制结果") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
                .disabled(output.isEmpty)
            }
            Text("结果")
                .font(.headline)
            TextEditor(text: $output)
                .frame(minHeight: 120)
                .border(Color.secondary.opacity(0.25))
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(16)
    }

    private func translate() {
        isTranslating = true
        errorMessage = ""
        Task {
            do {
                var config = store.configuration
                config.targetLanguage = "English"
                let result = try await client.translate(
                    TranslationRequest(text: input, targetLanguage: "English", scene: .chatDraft),
                    configuration: config,
                    apiKey: store.apiKey
                )
                await MainActor.run {
                    output = result.translatedText
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isTranslating = false
                }
            }
        }
    }
}
