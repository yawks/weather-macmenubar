import SwiftUI
import Charts

struct WeatherChartView: View {
    let hourlyData: [HourlyWeather]
    let unit: TemperatureUnit

    @State private var hoveredHour: HourlyWeather? = nil

    private var todayData: [HourlyWeather] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let midnight = calendar.date(byAdding: .day, value: 1, to: today)!
        return hourlyData.filter { $0.date >= today && $0.date <= midnight }
    }

    private var tempMin: Double {
        (todayData.map { $0.temperature }.min() ?? 0) - 2
    }

    private var tempMax: Double {
        (todayData.map { $0.temperature }.max() ?? 30) + 2
    }

    private func isCurrentHour(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .hour)
    }

    private func scaledTemp(_ temp: Double) -> Double {
        guard tempMax > tempMin else { return 50 }
        return (temp - tempMin) / (tempMax - tempMin) * 100
    }

    private func tempForScale(_ scaled: Double) -> Double {
        tempMin + (scaled / 100) * (tempMax - tempMin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Aujourd'hui")
                    .font(.headline)
                Spacer()
                if let deviation = hourlyData.first?.tempDeviation {
                    let sign = deviation >= 0 ? "+" : ""
                    Text("Écart: \(sign)\(Int(deviation))°")
                        .font(.caption.bold())
                        .foregroundColor(deviation >= 0 ? .red : .blue)
                }
            }
            .padding(.horizontal)

            Chart {
                ForEach(todayData) { hour in
                    let isCurrent = isCurrentHour(hour.date)
                    let isHovered = hoveredHour?.id == hour.id

                    // Precipitation bars
                    BarMark(
                        x: .value("Heure", hour.date, unit: .hour),
                        y: .value("Précipitations", hour.precipitationProbability * 100)
                    )
                    .foregroundStyle(Color.blue.opacity(isCurrent ? 0.75 : 0.3))

                    // Temperature line (normalized to 0-100 scale)
                    LineMark(
                        x: .value("Heure", hour.date, unit: .hour),
                        y: .value("Température", scaledTemp(hour.temperature))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.orange)

                    PointMark(
                        x: .value("Heure", hour.date, unit: .hour),
                        y: .value("Température", scaledTemp(hour.temperature))
                    )
                    .foregroundStyle(isCurrent || isHovered ? Color.orange : Color.orange.opacity(0.5))
                    .symbolSize(isCurrent || isHovered ? 80 : 40)
                    .annotation(position: .top) {
                        VStack(spacing: 1) {
                            if isCurrent || isHovered {
                                Text("\(Int(hour.temperature.rounded()))\(unit.symbol)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color(NSColor.windowBackgroundColor))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            if let windSpeed = hour.windSpeed {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 8))
                                        .rotationEffect(.degrees(hour.windDirection ?? 0))
                                    Text("\(Int(windSpeed))")
                                        .font(.system(size: 7))
                                }
                                .foregroundColor(isCurrent ? .primary : .secondary)
                            }
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                // Left axis: actual temperature values at evenly spaced positions
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let scaled = value.as(Double.self) {
                            Text("\(Int(tempForScale(scaled).rounded()))\(unit.symbol)")
                        }
                    }
                    AxisGridLine()
                }

                // Right axis: precipitation percentage
                AxisMarks(position: .trailing, values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let pop = value.as(Double.self) {
                            Text("\(Int(pop))%")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let x = location.x - geometry[proxy.plotAreaFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    hoveredHour = todayData.min(by: {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    })
                                }
                            case .ended:
                                hoveredHour = nil
                            }
                        }
                }
            }
            .frame(height: 150)
            .padding(.horizontal)
        }
    }
}
