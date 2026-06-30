import SwiftUI

struct AirQualityView: View {
    let readings: [AirQualityReading]

    private var pollutionReadings: [AirQualityReading] {
        readings
            .filter { $0.metric.category == .pollution }
            .sorted { $0.metric.rawValue < $1.metric.rawValue }
    }

    private var pollenReadings: [AirQualityReading] {
        readings
            .filter { $0.metric.category == .pollen }
            .sorted { $0.metric.rawValue < $1.metric.rawValue }
    }

    private var duplicatedMetrics: Set<AirMetric> {
        let counts = Dictionary(grouping: readings, by: \.metric).mapValues(\.count)
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    @ViewBuilder
    var body: some View {
        if !readings.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                if !pollutionReadings.isEmpty {
                    AirSectionHeader(icon: "aqi.medium", title: "Qualité de l'air")

                    VStack(spacing: 3) {
                        ForEach(pollutionReadings) { reading in
                            AirReadingRow(
                                reading: reading,
                                showProvider: duplicatedMetrics.contains(reading.metric)
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                if !pollenReadings.isEmpty {
                    AirSectionHeader(icon: "leaf.fill", title: "Pollens")

                    VStack(spacing: 5) {
                        ForEach(pollenReadings) { reading in
                            PollenReadingRow(reading: reading)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Section header

private struct AirSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.horizontal)
    }
}

// MARK: - Metric info popover

struct MetricInfoPopover: View {
    let metric: AirMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.displayName)
                    .font(.headline)
                Text(metric.fullName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Description
            Text(metric.metricDescription)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Thresholds
            let thresholds = metric.displayThresholds
            if !thresholds.isEmpty {
                Divider()

                Text("Niveaux")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(thresholds, id: \.0) { index, range in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(index.color)
                                .frame(width: 7, height: 7)
                            Text(index.rawValue)
                                .font(.caption2)
                                .frame(width: 88, alignment: .leading)
                            Text(range)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text(metric.thresholdSource)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}

// MARK: - Hoverable metric label

private struct HoverableMetricLabel: View {
    let metric: AirMetric
    let width: CGFloat

    @State private var showInfo = false

    var body: some View {
        Text(metric.displayName)
            .font(.footnote)
            .frame(width: width, alignment: .leading)
            .foregroundColor(.primary)
            .onHover { showInfo = $0 }
            .popover(isPresented: $showInfo, arrowEdge: .trailing) {
                MetricInfoPopover(metric: metric)
            }
    }
}

// MARK: - Pollution row

struct AirReadingRow: View {
    let reading: AirQualityReading
    var showProvider: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            HoverableMetricLabel(metric: reading.metric, width: 72)

            if let idx = reading.index {
                Circle()
                    .fill(idx.color)
                    .frame(width: 7, height: 7)
                Text(idx.rawValue)
                    .font(.caption)
                    .foregroundColor(idx.color)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let value = reading.value {
                Text(valueText(value, metric: reading.metric))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            if showProvider {
                Text(reading.providerName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(3)
            }
        }
        .padding(.vertical, 2)
    }

    private func valueText(_ v: Double, metric: AirMetric) -> String {
        let unit = metric.unit
        return unit.isEmpty ? "\(Int(v))" : "\(Int(v)) \(unit)"
    }
}

// MARK: - Pollen row

struct PollenReadingRow: View {
    let reading: AirQualityReading

    var body: some View {
        HStack(spacing: 8) {
            HoverableMetricLabel(metric: reading.metric, width: 72)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.08))
                    if let idx = reading.index {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(idx.color)
                            .frame(width: max(4, geo.size.width * idx.barFraction))
                    }
                }
            }
            .frame(height: 6)

            Text(reading.index?.rawValue ?? "—")
                .font(.caption2)
                .foregroundColor(reading.index?.color ?? .secondary)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}
