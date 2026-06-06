import AppKit
import FanyiCore
import SwiftUI

@main
struct FanyiBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.store) {
                appDelegate.reloadHotKeys()
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppSettingsStore()
    private let client = OpenAITranslationClient()
    private let ocrService = OCRService()
    private let selectionService = ClipboardSelectionService()
    private let hotKeyManager = HotKeyManager()
    private let screenshotSelectionController = ScreenshotSelectionController()
    private let resultWindow = FloatingResultWindowController()
    private var draftWindow: DraftWindowController?
    private var settingsWindow: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        draftWindow = DraftWindowController(store: store, client: client)
        settingsWindow = SettingsWindowController(store: store, client: client) { [weak self] in
            self?.reloadHotKeys()
        }
        setupMenu()
        reloadHotKeys()
    }

    func reloadHotKeys() {
        hotKeyManager.register(configuration: store.configuration) { [weak self] action in
            self?.handle(action)
        }
        setupMenu()
    }

    private func setupMenu() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        statusItem?.button?.title = "译"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "截图 OCR 翻译 (\(store.configuration.screenshotHotKey.displayName))", action: #selector(triggerScreenshotOCR), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "划词翻译 (\(store.configuration.selectionHotKey.displayName))", action: #selector(triggerSelectionTranslation), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "聊天草稿 (\(store.configuration.draftHotKey.displayName))", action: #selector(triggerDraft), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        statusItem?.menu = menu
    }

    private func handle(_ action: HotKeyAction) {
        switch action {
        case .screenshot:
            triggerScreenshotOCR()
        case .selection:
            triggerSelectionTranslation()
        case .draft:
            triggerDraft()
        }
    }

    @objc private func triggerScreenshotOCR() {
        guard PermissionService.hasScreenCapturePermission() else {
            resultWindow.show(title: "需要权限", body: "截图 OCR 需要开启“屏幕录制”权限。如果你已经授权，请完全退出 FanyiBar 后重新打开；如果刚重新打包过 app，请在系统设置中移除旧的 FanyiBar 项后重新授权。")
            PermissionService.requestScreenCapturePermission()
            return
        }
        screenshotSelectionController.beginSelection { [weak self] image in
            guard let self else { return }
            guard let image else {
                self.resultWindow.show(title: "截图 OCR", body: "没有选择有效的屏幕区域。")
                return
            }
            Task {
                await self.translateImage(image)
            }
        }
    }

    @objc private func triggerSelectionTranslation() {
        guard PermissionService.hasAccessibilityPermission() else {
            resultWindow.show(title: "需要权限", body: "划词翻译需要开启“辅助功能”权限。如果你已经授权，请完全退出 FanyiBar 后重新打开；如果刚重新打包过 app，请在系统设置中移除旧的 FanyiBar 项后重新授权。")
            PermissionService.requestAccessibilityPermission()
            return
        }
        Task {
            let text = await selectionService.currentSelectedText() ?? ""
            await translateText(text, scene: .selection, title: "划词翻译")
        }
    }

    @objc private func triggerDraft() {
        draftWindow?.show()
    }

    @objc private func openSettings() {
        settingsWindow?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func translateImage(_ image: NSImage) async {
        do {
            let text = try await ocrService.recognizeText(in: image)
            await translateText(text, scene: .screenshotOCR, title: "截图翻译")
        } catch {
            resultWindow.show(title: "OCR 失败", body: error.localizedDescription)
        }
    }

    private func translateText(_ text: String, scene: TranslationScene, title: String) async {
        do {
            let request = TranslationRequest(
                text: text,
                targetLanguage: store.configuration.targetLanguage,
                scene: scene
            )
            let result = try await client.translate(request, configuration: store.configuration, apiKey: store.apiKey)
            resultWindow.show(title: title, body: result.translatedText)
        } catch {
            resultWindow.show(title: title, body: error.localizedDescription)
        }
    }
}
