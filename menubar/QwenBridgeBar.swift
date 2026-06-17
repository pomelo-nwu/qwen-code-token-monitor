//  QwenBridgeBar — macOS menu bar dashboard for Qwen Code token usage.
//  Shows the same data as the ESP32 e-ink display, plus BLE/Bridge controls.
//  Build: see build.sh

import Cocoa
import SwiftUI

// MARK: - Constants

let LABEL = "com.pomelo.qwen-token-bridge"
let PLIST = "\(NSHomeDirectory())/Library/LaunchAgents/com.pomelo.qwen-token-bridge.plist"
let LOG_FILE = "/tmp/qwen-token-bridge-stdout.log"
let STATUS_FILE = "/tmp/qwen-token-status.json"
let GOAL_TARGET: Double = 100_000_000

// MARK: - Shell helpers

func shell(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    do { try p.run() } catch { return "" }
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

func getPID() -> Int {
    let out = shell(["list", LABEL])
    if out.isEmpty { return -1 }
    let pidStr = out.split(separator: "\t").first ?? ""
    return Int(pidStr) ?? -1
}

// MARK: - Data Model

struct TokenStatus: Codable {
    var todayTotal: Int64 = 0
    var todayInput: Int64 = 0
    var todayOutput: Int64 = 0
    var cacheRate: Int = 0
    var activeMinutes: Int = 0
    var sessionsToday: Int = 0
    var weekTotal: Int64 = 0
    var models: [ModelEntry] = []
    var updatedAt: String = "--:--"
    var ageSec: Int = 0
    var bleConnected: Bool = false
    var bleDevice: String = ""

    struct ModelEntry: Codable {
        var model: String = "--"
        var pct: Int = 0
    }
}

// MARK: - Formatting

func fmtTokens(_ t: Int64) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return f.string(from: NSNumber(value: t)) ?? "\(t)"
}

func fmtShort(_ t: Int64) -> String {
    if t >= 1_000_000_000 { return String(format: "%.1fB", Double(t) / 1e9) }
    if t >= 10_000_000 { return String(format: "%.0fM", Double(t) / 1e6) }
    if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1e6) }
    if t >= 1_000 { return String(format: "%.0fk", Double(t) / 1e3) }
    return "\(t)"
}

func fmtActive(_ mins: Int) -> String {
    if mins < 60 { return "\(mins)m" }
    let h = mins / 60
    let m = mins % 60
    return m > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(h)h"
}

func greetingText() -> String {
    let h = Calendar.current.component(.hour, from: Date())
    if h >= 5 && h < 12 { return "早上好～" }
    if h < 18 { return "下午好～" }
    return "晚上好～"
}

// MARK: - Status Manager

class StatusManager: ObservableObject {
    @Published var status = TokenStatus()
    @Published var bridgeRunning = false
    @Published var bridgePID: Int = -1
    @Published var fileExists = false

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in self.refresh() }
    }

    func stop() { timer?.invalidate() }

    private func refresh() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: STATUS_FILE)) {
            fileExists = true
            if let decoded = try? JSONDecoder().decode(TokenStatus.self, from: data) {
                DispatchQueue.main.async {
                    self.status = decoded
                }
            }
        } else {
            DispatchQueue.main.async {
                self.fileExists = false
            }
        }
        let pid = getPID()
        DispatchQueue.main.async {
            self.bridgeRunning = pid > 0
            self.bridgePID = pid
        }
    }

    func doStart() {
        shell(["load", PLIST])
        Thread.sleep(forTimeInterval: 0.5)
        refresh()
    }

    func doStop() {
        shell(["unload", PLIST])
        Thread.sleep(forTimeInterval: 0.5)
        refresh()
    }

    func doRestart() {
        shell(["unload", PLIST])
        Thread.sleep(forTimeInterval: 1)
        shell(["load", PLIST])
        refresh()
    }
}

// MARK: - SwiftUI Components

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, design: .rounded).weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct StatusDot: View {
    let on: Bool

    var body: some View {
        Circle()
            .fill(on ? Color.green : Color.orange)
            .frame(width: 7, height: 7)
    }
}

struct DashboardView: View {
    @ObservedObject var manager: StatusManager

    private var s: TokenStatus { manager.status }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──
            HStack(spacing: 8) {
                if let path = Bundle.main.path(forResource: "avatar", ofType: "png"),
                   let img = NSImage(contentsOfFile: path) {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(greetingText())
                    .font(.system(size: 15))
                Spacer()
                Text(s.updatedAt)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            Divider()

            // ── Today Tokens + Progress ──
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY TOKENS")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fmtTokens(s.todayTotal))
                        .font(.system(size: 30, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Text("tokens")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // Progress bar toward 100M goal
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary.opacity(0.5))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor)
                                .frame(width: max(2, geo.size.width * min(1, CGFloat(s.todayTotal) / GOAL_TARGET)))
                        }
                    }
                    .frame(height: 7)

                    Text(String(format: "%.1f%%", Double(s.todayTotal) / GOAL_TARGET * 100))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 10)

            // ── Top Models ──
            if !s.models.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TOP MODELS")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    ForEach(Array(s.models.prefix(3).enumerated()), id: \.offset) { _, m in
                        HStack {
                            Text(m.model)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Text("\(m.pct)%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 10)
            }

            Divider()

            // ── Stats Grid ──
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                StatCard(title: "Sessions", value: "\(s.sessionsToday)")
                StatCard(title: "Active", value: fmtActive(s.activeMinutes))
                StatCard(title: "Input", value: fmtShort(s.todayInput))
                StatCard(title: "Output", value: fmtShort(s.todayOutput))
                StatCard(title: "Cache Rate", value: "\(s.cacheRate)%")
                StatCard(title: "7 Days", value: fmtShort(s.weekTotal))
            }
            .padding(.vertical, 10)

            Divider()

            // ── Status Bar ──
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    StatusDot(on: s.bleConnected)
                    Text("BLE:")
                        .font(.system(size: 11))
                    Text(s.bleConnected ? (s.bleDevice.isEmpty ? "Connected" : s.bleDevice) : "Scanning…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    StatusDot(on: manager.bridgeRunning)
                    Text("Bridge:")
                        .font(.system(size: 11))
                    Text(manager.bridgeRunning ? "Running" : "Stopped")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)

            // ── Controls ──
            HStack(spacing: 8) {
                if manager.bridgeRunning {
                    Button("Stop") { manager.doStop() }
                    Button("Restart") { manager.doRestart() }
                } else {
                    Button("Start") { manager.doStart() }
                }
                Spacer()
                Button("Open Log") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: LOG_FILE))
                }
                Button("Quit") {
                    manager.stop()
                    NSApp.terminate(nil)
                }
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(width: 340)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let manager = StatusManager()
    private var iconTimer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.title = "QC"
            btn.action = #selector(togglePopover)
            btn.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DashboardView(manager: manager))

        manager.start()
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if let btn = statusItem.button {
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func applicationWillTerminate(_ n: Notification) {
        manager.stop()
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
