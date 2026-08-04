import SwiftUI

struct QuickActionsDashboardView: View {
    @EnvironmentObject private var networkStore: NetworkStatsStore
    @State private var runningAction: QuickAction?
    @State private var feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Quick Actions", icon: "bolt.fill")

            VStack(spacing: 8) {
                actionRow(.speedTest, icon: "speedometer", title: "Run Speed Test")
                actionRow(.flushDNS, icon: "trash", title: "Flush DNS Cache")
                actionRow(.restartWiFi, icon: "wifi", title: "Restart Wi-Fi")
                actionRow(.copyIP, icon: "doc.on.doc", title: "Copy Public IP")
                actionRow(.openRouter, icon: "network", title: "Open Router Admin")
                actionRow(.exportReport, icon: "square.and.arrow.up", title: "Export Report")
            }

            if let feedback {
                Text(feedback)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            Spacer(minLength: 4)
        }
    }

    private func actionRow(_ action: QuickAction, icon: String, title: String) -> some View {
        let isRunning = runningAction == action
        return Button {
            perform(action)
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
        .disabled(runningAction != nil && !isRunning)
    }

    private func perform(_ action: QuickAction) {
        guard runningAction == nil else { return }
        runningAction = action
        feedback = nil

        Task {
            guard let manager = AppDelegate.shared?.moduleManager,
                  let quickActions = manager.findModule(ofType: QuickActionsModule.self) else {
                runningAction = nil
                return
            }

            await quickActions.executeAction(action)

            runningAction = nil
            feedback = actionFeedback(action)
            await networkStore.pollOnce()
        }
    }

    private func actionFeedback(_ action: QuickAction) -> String {
        switch action {
        case .speedTest: return "Speed test finished. Latency reported in a notification."
        case .flushDNS: return "DNS cache flushed."
        case .restartWiFi: return "Wi-Fi is being restarted."
        case .copyIP: return "Public IP copied to clipboard."
        case .openRouter: return "Opening router admin page."
        case .exportReport: return "Report exported."
        }
    }
}
