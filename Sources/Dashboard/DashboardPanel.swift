import AppKit
import SwiftUI

@MainActor
final class DashboardPanel {
    static let shared = DashboardPanel()

    private var popover: NSPopover?

    private init() {}

    var isShown: Bool {
        popover?.isShown ?? false
    }

    func toggle(from button: NSStatusBarButton) {
        if popover?.isShown == true {
            close()
        } else {
            show(from: button)
        }
    }

    func show(from button: NSStatusBarButton) {
        if popover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.contentSize = NSSize(width: 460, height: 520)
            self.popover = popover

            let dashboardView = DashboardView()
                .environmentObject(SystemStatsStore.shared)
                .environmentObject(NetworkStatsStore.shared)
            let hostingView = NSHostingView(rootView: AnyView(dashboardView))

            let controller = NSViewController()
            controller.view = hostingView
            popover.contentViewController = controller
        }

        SystemStatsStore.shared.startPolling()
        NetworkStatsStore.shared.startPolling()

        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func close() {
        popover?.close()
        SystemStatsStore.shared.stopPolling()
        NetworkStatsStore.shared.stopPolling()
    }

    func quit() {
        close()
        NSApp.terminate(nil)
    }
}
