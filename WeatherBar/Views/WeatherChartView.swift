import SwiftUI
import Charts

struct WeatherChartView: View {
    let hourlyData: [HourlyWeather]
    let unit: TemperatureUnit

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
                    // Precipitation bars
                    BarMark(
                        x: .value("Heure", hour.date, unit: .hour),
                        y: .value("Précipitations", hour.precipitationProbability * 100)
                    )
                    .foregroundStyle(Color.blue.opacity(0.3))

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
                    .foregroundStyle(Color.orange)
                    .annotation(position: .top) {
                        if let windSpeed = hour.windSpeed {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 8))
                                    .rotationEffect(.degrees(hour.windDirection ?? 0))
                                Text("\(Int(windSpeed))")
                                    .font(.system(size: 7))
                            }
                            .foregroundColor(.secondary)
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
            .frame(height: 150)
            .padding(.horizontal)
        }
    }
}
