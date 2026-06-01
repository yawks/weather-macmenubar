import SwiftUI

struct WeatherIcon: View {
    let iconCode: String
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: WeatherIconMapper.symbol(for: iconCode))
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
            .padding(size * 0.35)
            .background(Circle().fill(Color.primary.opacity(0.08)))
    }
}

struct MainWeatherView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header — nom de la ville
            if let city = settings.selectedLocation?.name {
                Text(city)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Divider()
            }

            // MARK: Contenu principal
            Group {
                if !settings.isConfigured {
                    VStack(spacing: 20) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 50))
                        Text("Bienvenue sur WeatherBar")
                            .font(.headline)
                        Text("Configurez l'application dans les réglages.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .frame(maxHeight: .infinity)
                } else if weatherManager.isLoading && weatherManager.weather == nil {
                    ProgressView("Chargement...")
                        .padding(40)
                        .frame(maxHeight: .infinity)
                } else if let weather = weatherManager.weather {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Températures + condition
                            VStack(spacing: 10) {
                                HStack {
                                    WeatherIcon(iconCode: weather.current.iconCode, size: 44)

                                    VStack(alignment: .leading) {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("\(Int(weather.current.temperature))\(settings.unit.symbol)")
                                                .font(.system(size: 40, weight: .bold))

                                            if let deviation = weather.current.tempDeviation {
                                                let sign = deviation >= 0 ? "+" : ""
                                                Text("\(sign)\(Int(deviation))°")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(deviation >= 0 ? .red : .blue)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(deviation >= 0 ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text("Ressenti : \(Int(weather.current.feelsLike))\(settings.unit.symbol)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text(weather.current.conditionDescription)
                                    .font(.title3)

                                HStack(spacing: 20) {
                                    Label("\(Int(weather.current.tempMax))°", systemImage: "arrow.up")
                                    Label("\(Int(weather.current.tempMin))°", systemImage: "arrow.down")
                                    Label("\(Int(weather.current.windSpeed)) km/h", systemImage: "wind")
                                }
                                .font(.footnote)
                            }
                            .padding(.top)

                            // Métriques
                            HStack(spacing: 15) {
                                MetricBlock(icon: "wind", title: "Vent", value: "\(Int(weather.current.windSpeed)) km/h", subtitle: "\(Int(weather.current.windDirection))°")
                                MetricBlock(icon: "drop.fill", title: "Humidité", value: "\(Int(weather.current.humidity))%", subtitle: "")
                                MetricBlock(icon: "sunset.fill", title: "Coucher", value: weather.current.sunset.formatted(date: .omitted, time: .shortened), subtitle: "")
                            }
                            .padding(.horizontal)

                            // Courbe du jour
                            WeatherChartView(hourlyData: weather.hourly, unit: settings.unit)

                            // Prévisions 5 jours
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Prévisions 5 jours")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(weather.daily) { day in
                                    HStack {
                                        Text(day.date.formatted(.dateTime.weekday(.wide)))
                                            .frame(width: 80, alignment: .leading)
                                        WeatherIcon(iconCode: day.iconCode, size: 14)
                                            .frame(width: 36)
                                        Text(day.conditionDescription)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Spacer()
                                        if let morning = day.morningTemperature {
                                            Text("\(Int(morning))°")
                                                .font(.caption2)
                                                .foregroundColor(.blue.opacity(0.8))
                                                .frame(width: 30, alignment: .trailing)
                                        }
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

                            if let syncDate = weatherManager.lastSyncDate {
                                Text("Dernière sync · \(syncDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(weatherManager.lastSyncFailed ? .red : .secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                } else if let error = weatherManager.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("Erreur").font(.headline)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Réessayer") { weatherManager.refresh() }
                    }
                    .padding(40)
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("En attente de données…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Actualiser") { weatherManager.refresh() }
                    }
                    .padding(40)
                    .frame(maxHeight: .infinity)
                }
            }

            // MARK: Footer — réglages + quitter
            Divider()
            HStack {
                Button {
                    NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Réglages")

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Quitter WeatherBar")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(.secondary)
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
