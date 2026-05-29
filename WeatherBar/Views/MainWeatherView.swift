import SwiftUI

struct MainWeatherView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        VStack(spacing: 0) {
            if !settings.isConfigured {
                VStack(spacing: 20) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 50))
                    Text("Bienvenue sur WeatherBar")
                        .font(.headline)
                    Text("Veuillez configurer l'application dans les réglages.")
                        .multilineTextAlignment(.center)
                    Button("Ouvrir les réglages") {
                        NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                    }
                }
                .padding(40)
            } else if weatherManager.isLoading && weatherManager.weather == nil {
                ProgressView("Chargement...")
                    .padding(40)
            } else if let weather = weatherManager.weather {
                ScrollView {
                    VStack(spacing: 20) {
                        // Main Block
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: WeatherIconMapper.symbol(for: weather.current.iconCode))
                                    .font(.system(size: 60))
                                    .symbolRenderingMode(.multicolor)

                                VStack(alignment: .leading) {
                                    Text("\(Int(weather.current.temperature))\(settings.unit.symbol)")
                                        .font(.system(size: 40, weight: .bold))
                                    Text("Ressenti : \(Int(weather.current.feelsLike))\(settings.unit.symbol)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(weather.current.conditionDescription)
                                .font(.title3)

                            HStack(spacing: 20) {
                                Label("\(Int(weather.current.tempMax))°", systemName: "arrow.up")
                                Label("\(Int(weather.current.tempMin))°", systemName: "arrow.down")
                                Label("\(Int(weather.current.windSpeed)) km/h", systemName: "wind")
                            }
                            .font(.footnote)
                        }
                        .padding(.top)

                        // 3 Small blocks
                        HStack(spacing: 15) {
                            MetricBlock(icon: "wind", title: "Vent", value: "\(Int(weather.current.windSpeed)) km/h", subtitle: "\(Int(weather.current.windDirection))°")
                            MetricBlock(icon: "drop.fill", title: "Humidité", value: "\(Int(weather.current.humidity))%", subtitle: "")
                            MetricBlock(icon: "sunset.fill", title: "Coucher", value: weather.current.sunset.formatted(date: .omitted, time: .shortened), subtitle: "")
                        }
                        .padding(.horizontal)

                        // Chart
                        WeatherChartView(hourlyData: weather.hourly, unit: settings.unit)

                        // Forecast
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Prévisions à 7 jours")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(weather.daily) { day in
                                HStack {
                                    Text(day.date.formatted(.dateTime.weekday(.wide)))
                                        .frame(width: 80, alignment: .leading)

                                    Image(systemName: WeatherIconMapper.symbol(for: day.iconCode))
                                        .symbolRenderingMode(.multicolor)
                                        .frame(width: 30)

                                    Text(day.conditionDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(Int(day.tempMax))°")
                                        .frame(width: 30, alignment: .trailing)
                                    Text("\(Int(day.tempMin))°")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom)
                    }
                }
                .refreshable {
                    weatherManager.refresh()
                }
            } else if let error = weatherManager.errorMessage {
                VStack {
                    Text("Erreur").font(.headline)
                    Text(error).multilineTextAlignment(.center)
                    Button("Réessayer") {
                        weatherManager.refresh()
                    }
                }
                .padding(40)
            }
        }
        .frame(width: 350, height: 600)
    }
}

struct MetricBlock: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}
