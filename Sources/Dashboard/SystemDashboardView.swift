import SwiftUI

struct SystemDashboardView: View {
    @EnvironmentObject private var systemStore: SystemStatsStore

    var body: some View {
        if let metrics = systemStore.metrics {
            VStack(alignment: .leading, spacing: 8) {
                cpuSection(metrics.cpu)
                memorySection(metrics.memory)
                diskSection(metrics.diskVolumes)
                if metrics.battery.isPresent {
                    batterySection(metrics.battery)
                }
                gpuSection(metrics.gpu)
                systemSection(metrics.system)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        }
    }

    // MARK: - CPU

    private func cpuSection(_ cpu: SystemMetrics.CPU) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Processor", icon: "cpu")

            HStack {
                GaugeCircle(value: cpu.overallUsage / 100.0, color: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DashboardFormatter.percent(cpu.overallUsage))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("\(cpu.activeCores) active of \(cpu.coreCount) cores")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !cpu.perCoreUsage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(cpu.perCoreUsage.enumerated()), id: \.offset) { index, usage in
                        HStack(spacing: 6) {
                            Text("Core \(index)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .leading)
                            ProgressBar(value: usage / 100.0, color: coreColor(usage))
                            Text(DashboardFormatter.percent(usage))
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func coreColor(_ usage: Double) -> Color {
        if usage > 85 { return .red }
        if usage > 60 { return .orange }
        return .blue
    }

    // MARK: - Memory

    private func memorySection(_ memory: SystemMetrics.Memory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Memory", icon: "memorychip")

            HStack {
                GaugeCircle(value: memory.usedPercent / 100.0, color: .purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(DashboardFormatter.bytes(memory.used)) used")
                        .font(.system(size: 15, weight: .semibold))
                    Text("of \(DashboardFormatter.bytes(memory.total))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(memory.pressure)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(pressureColor(memory.pressure).opacity(0.15))
                    .foregroundColor(pressureColor(memory.pressure))
                    .cornerRadius(4)
            }

            HStack {
                MetricRow(icon: "memorychip", label: "Active", value: DashboardFormatter.bytes(memory.active))
                MetricRow(icon: "speedometer", label: "Inactive", value: DashboardFormatter.bytes(memory.inactive))
            }
            HStack {
                MetricRow(icon: "lock.fill", label: "Wired", value: DashboardFormatter.bytes(memory.wired))
                MetricRow(icon: "rectangle.compress.vertical", label: "Compressed", value: DashboardFormatter.bytes(memory.compressed))
            }
            if memory.swapTotal > 0 {
                HStack {
                    ProgressBar(value: memory.swapTotal > 0 ? Double(memory.swapUsed) / Double(memory.swapTotal) : 0, color: .orange)
                    Text("Swap: \(DashboardFormatter.bytes(memory.swapUsed)) / \(DashboardFormatter.bytes(memory.swapTotal))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func pressureColor(_ pressure: String) -> Color {
        switch pressure {
        case "Critical": return .red
        case "High": return .orange
        case "Elevated": return .yellow
        default: return .green
        }
    }

    // MARK: - Disk

    private func diskSection(_ volumes: [SystemMetrics.DiskVolume]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Storage", icon: "internaldrive")

            ForEach(volumes, id: \.name) { volume in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(volume.isRoot ? "\(volume.name) (System)" : volume.name)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(DashboardFormatter.percent(volume.usedPercent)) used")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    ProgressBar(value: volume.usedPercent / 100.0, color: diskColor(volume.usedPercent))
                    Text("\(DashboardFormatter.bytes(volume.total - volume.used)) available of \(DashboardFormatter.bytes(volume.total))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func diskColor(_ percent: Double) -> Color {
        if percent > 90 { return .red }
        if percent > 75 { return .orange }
        return .teal
    }

    // MARK: - Battery

    private func batterySection(_ battery: SystemMetrics.Battery) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Battery", icon: "battery.100")

            HStack {
                GaugeCircle(value: battery.level ?? 0, color: batteryColor(battery))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int((battery.level ?? 0) * 100))%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(battery.charging ? "Charging" : "On Battery")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if let cycles = battery.cycleCount {
                        MetricRow(icon: "repeat", label: "Cycles", value: "\(cycles)", color: .secondary)
                    }
                    if let condition = battery.condition {
                        Text(condition)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(batteryConditionColor(condition))
                    }
                    if let temp = battery.temperature {
                        Text("\(String(format: "%.1f", temp))°C")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func batteryColor(_ battery: SystemMetrics.Battery) -> Color {
        if battery.charging { return .green }
        if let level = battery.level {
            if level < 0.2 { return .red }
            if level < 0.5 { return .orange }
        }
        return .green
    }

    private func batteryConditionColor(_ condition: String) -> Color {
        switch condition.lowercased() {
        case "normal", "good": return .green
        case "fair": return .orange
        case "poor", "replace": return .red
        default: return .secondary
        }
    }

    // MARK: - GPU

    private func gpuSection(_ gpu: SystemMetrics.GPU) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Graphics", icon: "display")

            HStack(spacing: 8) {
                Image(systemName: "display")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gpu.model ?? "Unknown GPU")
                        .font(.system(size: 12, weight: .medium))
                    if let vram = gpu.vram {
                        Text(DashboardFormatter.bytes(vram))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - System

    private func systemSection(_ system: SystemMetrics.System) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "System", icon: "info.circle")

            MetricRow(icon: "macwindow", label: "macOS", value: "\(system.osVersion) (\(system.buildNumber))")
            MetricRow(icon: "cpu", label: "Chip", value: system.chipName)
            MetricRow(icon: "cube", label: "Model", value: system.modelIdentifier)
            MetricRow(icon: "flame", label: "Thermal", value: system.thermalState, color: thermalColor(system.thermalState))
            if let serial = system.serialNumber {
                MetricRow(icon: "qrcode", label: "Serial", value: serial)
            }
            MetricRow(icon: "clock.arrow.circlepath", label: "Uptime", value: DashboardFormatter.timeInterval(system.uptime))
        }
    }

    private func thermalColor(_ state: String) -> Color {
        switch state {
        case "Critical": return .red
        case "Serious": return .orange
        case "Fair": return .yellow
        default: return .secondary
        }
    }
}
