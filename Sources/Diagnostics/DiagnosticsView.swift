import SwiftUI

public struct DiagnosticsView: View {
    @State private var entries: [DiagnosticEntry] = []

    public init() {}

    public var body: some View {
        List(entries) { entry in
            HStack {
                Text(entry.name)
                    .font(.headline)
                Spacer()
                Text(entry.value)
                    .font(.subheadline)
                    .foregroundColor(entry.status.color)
                StatusIndicator(status: entry.status)
            }
        }
        .navigationTitle("Diagnostics")
        .task {
            await DiagnosticsManager.shared.collect()
            entries = DiagnosticsManager.shared.diagnostics
        }
    }
}

private struct StatusIndicator: View {
    let status: DiagnosticStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}

extension DiagnosticStatus {
    var color: Color {
        switch self {
        case .ok: return .green
        case .warning: return .yellow
        case .error: return .red
        case .unknown: return .gray
        }
    }
}