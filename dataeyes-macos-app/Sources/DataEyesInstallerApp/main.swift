import AppKit
import Foundation

final class PasteFriendlySecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let characters = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch characters {
        case "x":
            NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            return true
        case "c":
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            return true
        case "v":
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            return true
        case "a":
            NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

final class InstallerViewController: NSViewController {
    private let cardView = NSVisualEffectView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "DataEyes Installer")
    private let versionLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "安装 OpenClaw，支持同时配置国内站和国际站，并直接启动本地控制台。")
    private let pathHintLabel = NSTextField(labelWithString: "配置文件：~/.openclaw/openclaw.json")
    private let shuyanaiApiKeyLabel = NSTextField(labelWithString: "国内站 API Key（可选）")
    private let shuyanaiApiKeyField = PasteFriendlySecureTextField()
    private let dataeyesApiKeyLabel = NSTextField(labelWithString: "国际站 API Key（可选）")
    private let dataeyesApiKeyField = PasteFriendlySecureTextField()
    private let installButton = NSButton(title: "开始安装", target: nil, action: nil)
    private let retryButton = NSButton(title: "重新安装", target: nil, action: nil)
    private let openDashboardButton = NSButton(title: "打开控制台", target: nil, action: nil)
    private let openInstallDirButton = NSButton(title: "打开安装目录", target: nil, action: nil)
    private let refreshModelsButton = NSButton(title: "刷新模型", target: nil, action: nil)
    private let progressIndicator = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "准备就绪")
    private let stepLabel = NSTextField(labelWithString: "当前步骤：等待开始")
    private let installProgressBar = NSProgressIndicator()
    private let summaryLabel = NSTextField(labelWithString: "至少填写一个 API Key。安装器不会申请管理员权限，也不会修改 shell 配置。")
    private let logScrollView = NSScrollView()
    private let logTextView = NSTextView()

    private var installerTask: Process?
    private var refreshTask: Process?
    private var installSucceeded = false
    private let installHome = "\(NSHomeDirectory())/.dataeyes-openclaw"
    private var installHeartbeatTimer: Timer?
    private var installStartedAt: Date?
    private var lastLogAt: Date?
    private var pendingLogBuffer = ""

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 820, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        applyBundleMetadata()
    }

    private func buildUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1).cgColor

        cardView.material = .sidebar
        cardView.blendingMode = .withinWindow
        cardView.state = .active
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 22
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.7).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)

        versionLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        versionLabel.textColor = .secondaryLabelColor

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping

        pathHintLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        pathHintLabel.textColor = .secondaryLabelColor

        shuyanaiApiKeyLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        shuyanaiApiKeyField.placeholderString = "请输入国内站 API Key"
        shuyanaiApiKeyField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        dataeyesApiKeyLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        dataeyesApiKeyField.placeholderString = "请输入国际站 API Key"
        dataeyesApiKeyField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        installButton.bezelStyle = .rounded
        installButton.controlSize = .large
        installButton.target = self
        installButton.action = #selector(startInstall)
        installButton.keyEquivalent = "\r"

        retryButton.bezelStyle = .rounded
        retryButton.controlSize = .large
        retryButton.target = self
        retryButton.action = #selector(startInstall)
        retryButton.isHidden = true

        openDashboardButton.bezelStyle = .rounded
        openDashboardButton.controlSize = .large
        openDashboardButton.target = self
        openDashboardButton.action = #selector(openDashboard)
        openDashboardButton.isEnabled = false

        openInstallDirButton.bezelStyle = .rounded
        openInstallDirButton.controlSize = .large
        openInstallDirButton.target = self
        openInstallDirButton.action = #selector(openInstallDir)

        refreshModelsButton.bezelStyle = .rounded
        refreshModelsButton.controlSize = .large
        refreshModelsButton.target = self
        refreshModelsButton.action = #selector(refreshModels)
        refreshModelsButton.isEnabled = false

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false

        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor

        stepLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        stepLabel.textColor = .secondaryLabelColor

        installProgressBar.isIndeterminate = false
        installProgressBar.minValue = 0
        installProgressBar.maxValue = 4
        installProgressBar.doubleValue = 0
        installProgressBar.controlSize = .small

        summaryLabel.font = .systemFont(ofSize: 12, weight: .regular)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.maximumNumberOfLines = 2
        summaryLabel.lineBreakMode = .byWordWrapping

        logTextView.isEditable = false
        logTextView.isSelectable = true
        logTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.backgroundColor = NSColor(calibratedWhite: 0.985, alpha: 1)
        logTextView.textContainerInset = NSSize(width: 10, height: 10)

        logScrollView.documentView = logTextView
        logScrollView.hasVerticalScroller = true
        logScrollView.borderType = .bezelBorder

        let topRow = NSStackView(views: [iconView, titleBlock()])
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.spacing = 16

        let actionRow = NSStackView(views: [installButton, retryButton, openDashboardButton, openInstallDirButton, refreshModelsButton])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 10

        let statusRow = NSStackView(views: [progressIndicator, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 8

        let progressStack = NSStackView(views: [stepLabel, installProgressBar])
        progressStack.orientation = .vertical
        progressStack.alignment = .leading
        progressStack.spacing = 6

        let contentStack = NSStackView(views: [
            topRow,
            shuyanaiApiKeyLabel,
            shuyanaiApiKeyField,
            dataeyesApiKeyLabel,
            dataeyesApiKeyField,
            actionRow,
            statusRow,
            progressStack,
            summaryLabel,
            logScrollView
        ])
        contentStack.orientation = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(contentStack)
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 22),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22),

            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            shuyanaiApiKeyField.heightAnchor.constraint(equalToConstant: 34),
            dataeyesApiKeyField.heightAnchor.constraint(equalToConstant: 34),
            logScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
            installButton.widthAnchor.constraint(equalToConstant: 112),
            retryButton.widthAnchor.constraint(equalToConstant: 112),
            openDashboardButton.widthAnchor.constraint(equalToConstant: 112),
            installProgressBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        showLogPlaceholder()
    }

    private func titleBlock() -> NSStackView {
        let stack = NSStackView(views: [titleLabel, versionLabel, subtitleLabel, pathHintLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    private func applyBundleMetadata() {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        versionLabel.stringValue = "Version \(shortVersion) (\(buildVersion))"
    }

    @objc
    private func startInstall() {
        let shuyanaiApiKey = shuyanaiApiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let dataeyesApiKey = dataeyesApiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shuyanaiApiKey.isEmpty || !dataeyesApiKey.isEmpty else {
            showAlert(title: "缺少 API Key", message: "请至少填写一个平台的 API Key 后再开始安装。")
            return
        }
        guard installerTask == nil else {
            return
        }

        guard let payloadRoot = Bundle.main.resourceURL?.appendingPathComponent("payload"),
              let scriptURL = scriptURL(in: payloadRoot) else {
            showAlert(title: "安装资源缺失", message: "没有找到内置安装脚本，请重新构建安装器。")
            return
        }

        installSucceeded = false
        openDashboardButton.isEnabled = false
        refreshModelsButton.isEnabled = false
        retryButton.isHidden = true
        installButton.isHidden = false
        clearLogs()
        installProgressBar.doubleValue = 0
        stepLabel.stringValue = "当前步骤：准备启动安装"
        appendLog("准备执行安装脚本...\n")
        appendLog("安装目录: \(installHome)\n")
        appendLog("安装资源路径: \(payloadRoot.path)\n\n")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptURL.path]
        task.currentDirectoryURL = payloadRoot

        var env = ProcessInfo.processInfo.environment
        if !shuyanaiApiKey.isEmpty {
            env["SHUYANAI_API_KEY"] = shuyanaiApiKey
        }
        if !dataeyesApiKey.isEmpty {
            env["DATAEYES_API_KEY"] = dataeyesApiKey
        }
        env["OPENCLAW_HOME"] = env["OPENCLAW_HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? installHome
        env["PATH"] = "\(installHome)/npm/bin:\(installHome)/node/bin:" + (env["PATH"] ?? "")
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            DispatchQueue.main.async {
                self?.appendLogChunk(text)
            }
        }

        task.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            let trailingData = pipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                if !trailingData.isEmpty, let text = String(data: trailingData, encoding: .utf8) {
                    self?.appendLogChunk(text)
                }
                self?.finishInstall(with: process.terminationStatus)
            }
        }

        installerTask = task
        installButton.isEnabled = false
        retryButton.isEnabled = false
        shuyanaiApiKeyField.isEnabled = false
        dataeyesApiKeyField.isEnabled = false
        progressIndicator.startAnimation(nil)
        installStartedAt = Date()
        lastLogAt = Date()
        startHeartbeatTimer()
        setStatus("安装中...", color: .systemOrange)
        summaryLabel.stringValue = "正在准备本地运行环境，并按已填写的平台自动写入配置。"

        do {
            try task.run()
        } catch {
            installerTask = nil
            progressIndicator.stopAnimation(nil)
            stopHeartbeatTimer()
            installButton.isEnabled = true
            shuyanaiApiKeyField.isEnabled = true
            dataeyesApiKeyField.isEnabled = true
            setStatus("启动失败", color: .systemRed)
            summaryLabel.stringValue = "安装器未能成功启动，请检查当前环境后重试。"
            appendLog("无法启动安装脚本: \(error.localizedDescription)\n")
            showAlert(title: "无法启动安装", message: error.localizedDescription)
        }
    }

    private func finishInstall(with code: Int32) {
        installerTask = nil
        progressIndicator.stopAnimation(nil)
        stopHeartbeatTimer()
        installButton.isEnabled = true
        retryButton.isEnabled = true
        shuyanaiApiKeyField.isEnabled = true
        dataeyesApiKeyField.isEnabled = true
        installButton.isHidden = true
        retryButton.isHidden = false

        if code == 0 {
            installSucceeded = true
            openDashboardButton.isEnabled = true
            refreshModelsButton.isEnabled = true
            installProgressBar.doubleValue = installProgressBar.maxValue
            stepLabel.stringValue = "当前步骤：安装完成"
            setStatus("安装完成", color: .systemGreen)
            summaryLabel.stringValue = "OpenClaw 已安装完成，现在可以直接打开控制台并切换已配置的平台模型。"
            appendLog("\n安装流程已完成。\n")
        } else {
            installSucceeded = false
            openDashboardButton.isEnabled = false
            refreshModelsButton.isEnabled = FileManager.default.fileExists(atPath: refreshCommandURL().path)
            setStatus("安装失败", color: .systemRed)
            summaryLabel.stringValue = "安装没有完成。你可以检查上面的日志，确认 Key 或网络后重新执行安装。"
            appendLog("\n安装失败，退出码: \(code)\n")
        }
    }

    @objc
    private func openDashboard() {
        do {
            let url = try resolveDashboardURL()
            NSWorkspace.shared.open(url)
        } catch {
            showAlert(
                title: "无法打开控制台",
                message: "请稍后重试，或在终端执行 \(installHome)/npm/bin/openclaw dashboard --no-open 获取带令牌的控制台地址。\n\n\(error.localizedDescription)"
            )
        }
    }

    @objc
    private func openInstallDir() {
        NSWorkspace.shared.open(URL(fileURLWithPath: installHome))
    }

    @objc
    private func refreshModels() {
        guard refreshTask == nil else { return }

        let refreshURL = refreshCommandURL()
        guard FileManager.default.isExecutableFile(atPath: refreshURL.path) else {
            showAlert(title: "无法刷新模型", message: "没有找到刷新模型脚本，请先完成安装。")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [refreshURL.path]
        task.currentDirectoryURL = URL(fileURLWithPath: installHome)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            DispatchQueue.main.async {
                self?.appendLogChunk(text)
            }
        }

        task.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            let trailingData = pipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                if !trailingData.isEmpty, let text = String(data: trailingData, encoding: .utf8) {
                    self?.appendLogChunk(text)
                }
                self?.refreshTask = nil
                self?.refreshModelsButton.isEnabled = true
                if process.terminationStatus == 0 {
                    self?.setStatus("模型已刷新", color: .systemGreen)
                    self?.summaryLabel.stringValue = "已根据当前 API Key 重新同步可用模型列表。"
                } else {
                    self?.setStatus("刷新失败", color: .systemRed)
                    self?.summaryLabel.stringValue = "模型刷新没有完成，请检查网络或 API Key 后重试。"
                }
            }
        }

        refreshTask = task
        refreshModelsButton.isEnabled = false
        appendLog("\n开始刷新模型列表...\n")
        setStatus("刷新模型中...", color: .systemOrange)
        summaryLabel.stringValue = "正在根据当前配置重新拉取可用模型列表。"

        do {
            try task.run()
        } catch {
            refreshTask = nil
            refreshModelsButton.isEnabled = true
            setStatus("刷新失败", color: .systemRed)
            summaryLabel.stringValue = "刷新模型脚本未能启动。"
            appendLog("无法启动刷新脚本: \(error.localizedDescription)\n")
            showAlert(title: "无法刷新模型", message: error.localizedDescription)
        }
    }

    private func scriptURL(in payloadRoot: URL) -> URL? {
        let direct = payloadRoot.appendingPathComponent("内部文件/安装主程序.sh")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        return nil
    }

    private func refreshCommandURL() -> URL {
        URL(fileURLWithPath: installHome).appendingPathComponent("bin/dataeyes-refresh-models")
    }

    private func appendLog(_ text: String) {
        let attr = NSAttributedString(string: text)
        logTextView.textStorage?.append(attr)
        logTextView.scrollToEndOfDocument(nil)
    }

    private func appendLogChunk(_ text: String) {
        lastLogAt = Date()
        let cleaned = sanitizeLogText(text)
        guard !cleaned.isEmpty else { return }

        pendingLogBuffer.append(cleaned)
        let normalized = pendingLogBuffer.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\n")

        if let tail = parts.last {
            pendingLogBuffer = tail
        } else {
            pendingLogBuffer = ""
        }

        for line in parts.dropLast() {
            handleLogLine(String(line))
        }

        if text.contains("\n") && !pendingLogBuffer.isEmpty {
            handleLogLine(pendingLogBuffer)
            pendingLogBuffer = ""
        }
    }

    private func handleLogLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            updateProgress(using: trimmed)
            appendLog(trimmed + "\n")
        } else {
            appendLog("\n")
        }
    }

    private func updateProgress(using line: String) {
        let pattern = #"步骤\s*([0-9]+)\s*/\s*([0-9]+)\s*:\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let currentRange = Range(match.range(at: 1), in: line),
              let totalRange = Range(match.range(at: 2), in: line),
              let titleRange = Range(match.range(at: 3), in: line),
              let current = Double(line[currentRange]),
              let total = Double(line[totalRange]) else {
            return
        }

        installProgressBar.maxValue = max(total, 1)
        installProgressBar.doubleValue = min(current, installProgressBar.maxValue)
        let title = String(line[titleRange]).trimmingCharacters(in: .whitespaces)
        stepLabel.stringValue = "当前步骤：\(Int(current))/\(Int(total)) \(title)"
        summaryLabel.stringValue = "\(title) 正在执行中，请稍候。"
    }

    private func sanitizeLogText(_ text: String) -> String {
        let withoutANSI = text.replacingOccurrences(
            of: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#,
            with: "",
            options: .regularExpression
        )
        return withoutANSI.replacingOccurrences(of: "\u{0008}", with: "")
    }

    private func clearLogs() {
        pendingLogBuffer = ""
        logTextView.string = ""
    }

    private func showLogPlaceholder() {
        clearLogs()
        appendLog("安装日志会显示在这里。\n")
        appendLog("开始安装后，你会看到当前步骤、网络下载进度和模型同步结果。\n")
    }

    private func startHeartbeatTimer() {
        stopHeartbeatTimer()
        installHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateHeartbeatStatus()
        }
    }

    private func stopHeartbeatTimer() {
        installHeartbeatTimer?.invalidate()
        installHeartbeatTimer = nil
        installStartedAt = nil
        lastLogAt = nil
    }

    private func updateHeartbeatStatus() {
        guard installerTask != nil,
              let startedAt = installStartedAt else { return }
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let idleSeconds = Int(Date().timeIntervalSince(lastLogAt ?? startedAt))
        let statusText = idleSeconds >= 8 ? "安装中...（仍在执行，已 \(elapsed)s）" : "安装中...（\(elapsed)s）"
        setStatus(statusText, color: .systemOrange)
    }

    private func setStatus(_ text: String, color: NSColor) {
        statusLabel.stringValue = text
        statusLabel.textColor = color
    }

    private func resolveDashboardURL() throws -> URL {
        let configURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".openclaw/openclaw.json")
        let data = try Data(contentsOf: configURL)
        let rootObject = try JSONSerialization.jsonObject(with: data, options: [])

        guard
            let root = rootObject as? [String: Any],
            let gateway = root["gateway"] as? [String: Any],
            let auth = gateway["auth"] as? [String: Any],
            let token = auth["token"] as? String,
            !token.isEmpty,
            let url = URL(string: "http://localhost:18789/#token=\(token)")
        else {
            throw NSError(
                domain: "DataEyesInstaller",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "未能从 ~/.openclaw/openclaw.json 读取 gateway.auth.token。"]
            )
        }

        return url
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewController = InstallerViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "DataEyes Installer"
        window.contentViewController = viewController
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
