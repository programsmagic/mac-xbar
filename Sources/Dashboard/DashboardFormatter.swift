import Foundation

enum DashboardFormatter {
    static func speed(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        if value < 1024 {
            return String(format: "%.2f B/s", value)
        } else if value < 1024 * 1024 {
            return String(format: "%.1f KB/s", value / 1024)
        } else if value < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", value / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", value / (1024 * 1024 * 1024))
        }
    }

    static func bytes(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        if bytes < 1024 * 1024 * 1024 * 1024 { return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024)) }
        return String(format: "%.2f TB", Double(bytes) / (1024 * 1024 * 1024 * 1024))
    }

    static func bytes(_ byteCount: Int64) -> String {
        byteCount >= 0 ? bytes(UInt64(byteCount)) : "\u{2014}"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func timeInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
