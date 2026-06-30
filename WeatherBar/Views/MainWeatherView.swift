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
    @ObservedObject var airQualityManager: AirQualityManager

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

            // MARK: Bannière erreur synchro
            if weatherManager.lastSyncFailed && weatherManager.weather != nil {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Erreur lors de la dernière synchro")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                        Button("Réessayer") { weatherManager.refresh() }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.12))
                    Divider()
                }
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
                                MetricBlock(
                                    icon: "sun.max.fill",
                                    title: "Indice UV",
                                    value: weather.current.uvIndex.map { String(Int($0.rounded())) } ?? "--",
                                    subtitle: uvCategory(weather.current.uvIndex)
                                )
                            }
                            .padding(.horizontal)

                            // Arc solaire
                            SunArcView(sunrise: weather.current.sunrise, sunset: weather.current.sunset)

                            // Courbe du jour
                            WeatherChartView(hourlyData: weather.hourly, unit: settings.unit)

                            // Qualité de l'air + pollens
                            if !airQualityManager.readings.isEmpty {
                                Divider().padding(.horizontal)
                                AirQualityView(readings: airQualityManager.readings)
                                Divider().padding(.horizontal)
                            }

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
                                        Text("\(Int(day.tempMax))°")
                                            .frame(width: 30, alignment: .trailing)
                                        Text("\(Int(day.tempMin))°")
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, alignment: .trailing)
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            // Phase de lune
                            if let coord = settings.selectedLocation?.coordinate {
                                Divider().padding(.horizontal)
                                MoonPhaseView(info: MoonCalculator.phaseInfo(
                                    for: Date(),
                                    latitude: coord.latitude,
                                    longitude: coord.longitude
                                ))
                            }

                            if let syncDate = weatherManager.lastSyncDate {
                                Text("Dernière sync · \(syncDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                } else if weatherManager.errorMessage != nil && weatherManager.weather == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("Impossible de charger la météo")
                            .font(.headline)
                        Text("Vérifiez votre connexion réseau.")
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
        .frame(width: 350, height: 680)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private func uvCategory(_ uv: Double?) -> String {
    guard let uv else { return "" }
    switch uv {
    case ..<3:  return "Faible"
    case ..<6:  return "Modéré"
    case ..<8:  return "Élevé"
    case ..<11: return "Très élevé"
    default:    return "Extrême"
    }
}

// MARK: - SunArcView

struct SunArcView: View {
    let sunrise: Date
    let sunset: Date
    var now: Date = Date()

    private var progress: Double {
        let total = sunset.timeIntervalSince(sunrise)
        guard total > 0 else { return 0 }
        return max(0, min(1, now.timeIntervalSince(sunrise) / total))
    }

    private var sunColor: Color {
        switch progress {
        case ..<0.08:  return Color(red: 1.0, green: 0.55, blue: 0.35)
        case ..<0.20:  return Color(red: 1.0, green: 0.75, blue: 0.20)
        case ..<0.80:  return Color(red: 1.0, green: 0.88, blue: 0.10)
        case ..<0.92:  return Color(red: 1.0, green: 0.60, blue: 0.10)
        default:       return Color(red: 0.95, green: 0.30, blue: 0.10)
        }
    }

    private func arcPoint(t: Double, w: Double, arcTop: Double, arcBottom: Double) -> CGPoint {
        CGPoint(
            x: w * t,
            y: arcTop + (arcBottom - arcTop) * pow(2 * t - 1, 2)
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w        = Double(geo.size.width)
                let h        = Double(geo.size.height)
                let arcTop   = 10.0
                let arcBottom = h - 4.0
                let steps    = 80

                ZStack {
                    // Full arc (gray)
                    Path { path in
                        path.move(to: arcPoint(t: 0, w: w, arcTop: arcTop, arcBottom: arcBottom))
                        for i in 1...steps {
                            path.addLine(to: arcPoint(t: Double(i) / Double(steps), w: w, arcTop: arcTop, arcBottom: arcBottom))
                        }
                    }
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 2)

                    // Past arc (warm gradient)
                    if progress > 0.01 {
                        Path { path in
                            let endStep = max(1, Int(Double(steps) * progress))
                            path.move(to: arcPoint(t: 0, w: w, arcTop: arcTop, arcBottom: arcBottom))
                            for i in 1...endStep {
                                path.addLine(to: arcPoint(t: Double(i) / Double(steps), w: w, arcTop: arcTop, arcBottom: arcBottom))
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.55, blue: 0.35), sunColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2.5
                        )
                    }

                    // Sun circle
                    let sunPt = arcPoint(t: progress, w: w, arcTop: arcTop, arcBottom: arcBottom)
                    Circle()
                        .fill(sunColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: sunColor.opacity(0.6), radius: 5)
                        .position(x: sunPt.x, y: sunPt.y)
                }
            }
            .frame(height: 60)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lever de soleil")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(sunrise.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Coucher de soleil")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(sunset.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - MetricBlock

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
