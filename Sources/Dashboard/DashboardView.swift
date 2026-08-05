import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview
    case network
    case system
    case analytics
    case actions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .network: return "Network"
        case .system: return "System"
        case .analytics: return "Analytics"
        case .actions: return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .network: return "network"
        case .system: return "desktopcomputer"
        case .analytics: return "chart.xyaxis.line"
        case .actions: return "bolt.fill"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var systemStore: SystemStatsStore
    @EnvironmentObject private var networkStore: NetworkStatsStore
    @State private var selectedTab: DashboardTab = .overview
    @State private var isCheckingUpdate = false

    @State private var toastMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .padding(.vertical, 6)

            content

            Divider()
            footer
        }
        .frame(width: 460, height: 520)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()
        .overlay(
            toastOverlay
        )
        .onAppear {
            systemStore.startPolling()
            networkStore.startPolling()
        }
        .onDisappear {
            systemStore.stopPolling()
            networkStore.stopPolling()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Picker("", selection: $selectedTab) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .labelStyle(.titleAndIcon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            switch selectedTab {
            case .overview:
                OverviewView()
            case .network:
                NetworkDashboardView()
            case .system:
                SystemDashboardView()
            case .analytics:
                AnalyticsDashboardView()
            case .actions:
                QuickActionsDashboardView()
            }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .padding(.horizontal, 18)
    }

    @Environment(\.openSettings) private var openSettings

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                openAppSettings()
            } label: {
                HStack {
                    Label("Open App", systemImage: "macwindow")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("Open the mac-xbar app window")
            .contextMenu {
                Button("Open Settings…") { openAppSettings() }
            }

            Divider()

            HStack {
                if isCheckingUpdate {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        checkForUpdates()
                    } label: {
                        Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }

                Spacer()

                Button {
                    DashboardPanel.shared.quit()
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        Task {
            let update = await UpdateChecker.shared.checkForUpdate()
            await MainActor.run {
                isCheckingUpdate = false
                if let update {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(update.version) is available."
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn {
                        UpdateChecker.shared.openDownloadPage(update)
                    }
                } else {
                    showToast("You're up to date")
                }
            }
        }
    }

    private var toastOverlay: some View {
        Group {
            if let message = toastMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundColor(.primary)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                    .onTapGesture { toastMessage = nil }
            }
        }
    }

    private func openAppSettings() {
        openSettings()
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { self.toastMessage = nil }
        }
    }
}
