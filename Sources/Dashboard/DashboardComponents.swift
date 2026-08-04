import SwiftUI

struct MetricRow: View {
    let icon: String
    let label: String
    var value: String
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 3)
    }
}

struct CopyableMetricRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .secondary
    var copyValue: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
            if !value.isEmpty, value != "—" {
                Button {
                    copyToClipboard(copyValue ?? value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(color)
                }
                .buttonStyle(.plain)
                .help("Copy \(label)")
            }
        }
        .padding(.vertical, 3)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct ProgressBar: View {
    let value: Double
    var color: Color = .accentColor
    var height: CGFloat = 8

    private var ratio: CGFloat { CGFloat(min(max(value, 0), 1)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: height)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * ratio, height: height)
                    .shadow(color: color.opacity(0.35), radius: 1, y: 0.5)
            }
            .frame(height: height)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

struct SectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 1, 1)
            let step = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : geo.size.width

            Path { path in
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * step
                    let y = geo.size.height - (geo.size.height * CGFloat(value / maxValue))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }
}

struct GaugeCircle: View {
    let value: Double
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 60, height: 60)
    }
}

struct SpeedView: View {
    let download: Double
    let upload: Double
    var valueSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 14) {
            speedItem(direction: "arrow.down", color: .green, value: download)
            speedItem(direction: "arrow.up", color: .orange, value: upload)
        }
    }

    private func speedItem(direction: String, color: Color, value: Double) -> some View {
        let parts = Self.split(DashboardFormatter.speed(value))
        return HStack(spacing: 3) {
            Image(systemName: direction)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .frame(width: 12)
            Text(parts.number)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 46, alignment: .leading)
            if !parts.unit.isEmpty {
                Text(parts.unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .baselineOffset(2)
            }
        }
    }

    private static func split(_ speed: String) -> (number: String, unit: String) {
        if let idx = speed.firstIndex(of: " ") {
            return (String(speed[..<idx]), String(speed[speed.index(after: idx)...]))
        }
        return (speed, "")
    }
}

struct SpeedBarsView: View {
    let download: Double
    let upload: Double
    var barCount: Int = 10
    var maxReference: Double = 50 * 1024 * 1024

    private var barHeights: [CGFloat] {
        (0..<barCount).map { i in
            let p = Double(i + 1) / Double(barCount)
            return CGFloat(4 + p * 11)
        }
    }

    private func filled(_ value: Double) -> Int {
        let fraction = min(max(value / maxReference, 0), 1)
        return Int(ceil(Double(barCount) * fraction))
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
                .frame(width: 10)
            barRow(color: .green, value: download)
            Spacer(minLength: 4)
            Image(systemName: "arrow.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .frame(width: 10)
            barRow(color: .orange, value: upload)
        }
    }

    private func barRow(color: Color, value: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .frame(width: 3, height: barHeights[i])
                    .foregroundColor(i < filled(value) ? color : color.opacity(0.18))
            }
        }
    }
}
