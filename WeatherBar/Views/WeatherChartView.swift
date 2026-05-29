import SwiftUI
import Charts

struct WeatherChartView: View {
    let hourlyData: [HourlyWeather]
    let unit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prévisions heure par heure")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(hourlyData) { hour in
                    // Precipitation bars
                    BarMark(
                        x: .value("Heure", hour.date, unit: .hour),
                        y: .value("Précipitations", hour.precipitationProbability * 100)
                    )
                    .foregroundStyle(Color.blue.opacity(0.3))

                    // Temperature line
                    LineMark(
                        x: .value("Heure", hour.date, unit: .hour),
                        y: .value("Température", hour.temperature)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.orange)

                    PointMark(
                        x: .value("Heure", hour.date, unit: .hour),
                        y: .value("Température", hour.temperature)
                    )
                    .foregroundStyle(Color.orange)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisValueLabel {
                        if let temp = value.as(Double.self) {
                            Text("\(Int(temp))\(unit.symbol)")
                        }
                    }
                    AxisGridLine()
                }

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
