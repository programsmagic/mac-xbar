import Foundation
import AppKit

public final class AutomationModule {
    public static let shared = AutomationModule()

    public enum AutomationType: String, Codable, CaseIterable {
        case appleShortcuts
        case appleScript
        case urlScheme
        case cli
        case restAPI
        case webhooks
        case scheduledJobs
    }

    public struct AutomationRule {
        public let id: String
        public let type: AutomationType
        public let name: String
        public let enabled: Bool
        public let config: [String: String]
    }

    private var rules: [AutomationRule] = []

    public var allRules: [AutomationRule] {
        rules
    }

    public func register(rule: AutomationRule) {
        rules.append(rule)
    }

    public func removeRule(id: String) {
        rules.removeAll { $0.id == id }
    }

    public func execute(ruleId: String) async throws {
        guard let rule = rules.first(where: { $0.id == ruleId }) else {
            throw MacXbarError.executionFailed("Rule not found: \(ruleId)")
        }
        guard rule.enabled else { return }
        switch rule.type {
        case .appleShortcuts:
            try await executeAppleShortcut(rule)
        case .appleScript:
            try await executeAppleScript(rule)
        case .urlScheme:
            try await executeURLScheme(rule)
        case .cli:
            try await executeCLI(rule)
        case .restAPI:
            try await executeRESTAPI(rule)
        case .webhooks:
            try await executeWebhook(rule)
        case .scheduledJobs:
            try await executeScheduledJob(rule)
        }
    }

    private func executeAppleShortcut(_ rule: AutomationRule) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "tell application \"Shortcuts\" to run shortcut \"\(rule.name)\""]
        try task.run()
        task.waitUntilExit()
    }

    private func executeAppleScript(_ rule: AutomationRule) async throws {
        let script = rule.config["script"] ?? ""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try task.run()
        task.waitUntilExit()
    }

    private func executeURLScheme(_ rule: AutomationRule) async throws {
        guard let url = URL(string: rule.config["url"] ?? "") else { return }
        NSWorkspace.shared.open(url)
    }

    private func executeCLI(_ rule: AutomationRule) async throws {
        let command = rule.config["command"] ?? ""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        try task.run()
        task.waitUntilExit()
    }

    private func executeRESTAPI(_ rule: AutomationRule) async throws {
        guard let url = URL(string: rule.config["url"] ?? "") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = rule.config["method"] ?? "GET"
        let (_, _) = try await URLSession.shared.data(for: request)
    }

    private func executeWebhook(_ rule: AutomationRule) async throws {
        guard let url = URL(string: rule.config["url"] ?? "") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = rule.config["body"]?.data(using: .utf8) {
            request.httpBody = body
        }
        let (_, _) = try await URLSession.shared.data(for: request)
    }

    private func executeScheduledJob(_ rule: AutomationRule) async throws {
        let command = rule.config["command"] ?? ""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        try task.run()
        task.waitUntilExit()
    }
}