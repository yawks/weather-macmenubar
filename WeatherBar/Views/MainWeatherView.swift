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

// MARK: - Animated weather background

private struct WeatherSkyGradient: View {
    let condition: WeatherCondition
    let isDay: Bool

    private var colors: [Color] {
        if !isDay {
            return [
                Color(red: 0.035, green: 0.065, blue: 0.16),
                Color(red: 0.10, green: 0.16, blue: 0.29)
            ]
        }

        switch condition {
        case .clear:
            return [Color(red: 0.25, green: 0.62, blue: 0.92), Color(red: 0.68, green: 0.86, blue: 0.98)]
        case .cloudy, .atmosphere:
            return [Color(red: 0.32, green: 0.45, blue: 0.56), Color(red: 0.62, green: 0.72, blue: 0.78)]
        case .rain, .drizzle, .thunderstorm:
            return [Color(red: 0.19, green: 0.31, blue: 0.40), Color(red: 0.43, green: 0.57, blue: 0.64)]
        case .snow:
            return [Color(red: 0.49, green: 0.62, blue: 0.72), Color(red: 0.80, green: 0.87, blue: 0.91)]
        }
    }

    var body: some View {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A lightweight, procedural scene driven by the current weather. Keeping it
/// in SwiftUI avoids shipping large videos while still adapting to day/night.
struct AnimatedWeatherBackground: View {
    let weather: CurrentWeather
    var moonPhase: Double? = nil
    var conditionOverride: WeatherCondition? = nil
    var isDayOverride: Bool? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDay: Bool {
        if let isDayOverride { return isDayOverride }
        let now = Date()
        return now >= weather.sunrise && now <= weather.sunset
    }

    private var condition: WeatherCondition {
        conditionOverride ?? weather.condition
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    drawSkyDetails(context: &context, size: size, time: time)
                    drawClouds(context: &context, size: size, time: time)
                    drawPrecipitation(context: &context, size: size, time: time)
                }
            }

            if !isDay, condition == .clear, let moonPhase {
                BackgroundMoon(phase: moonPhase)
                    .frame(width: 72, height: 72)
                    .padding(.top, 42)
                    .padding(.trailing, 34)
            }
        }
        .background(WeatherSkyGradient(condition: condition, isDay: isDay))
        .overlay {
            // A subtle veil keeps text readable without hiding the animation.
            Rectangle().fill(.ultraThinMaterial).opacity(0.48)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawSkyDetails(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        if isDay && condition == .clear {
            let sun = CGRect(x: size.width * 0.68, y: 38, width: 90, height: 90)
            context.fill(Path(ellipseIn: sun), with: .color(.yellow.opacity(0.24)))
            context.fill(Path(ellipseIn: sun.insetBy(dx: 20, dy: 20)), with: .color(.yellow.opacity(0.55)))
        } else if !isDay {
            for i in 0..<24 {
                let x = seeded(i, 3) * size.width
                let y = seeded(i, 7) * size.height * 0.72
                let twinkle = 0.25 + 0.35 * (0.5 + 0.5 * sin(time * 0.8 + Double(i)))
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(.white.opacity(twinkle)))
            }
        }

        if condition == .thunderstorm {
            let phase = time.truncatingRemainder(dividingBy: 7.0)
            if phase < 0.10 || (phase > 0.22 && phase < 0.29) {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.25)))
            }
        }

        if condition == .atmosphere {
            for i in 0..<5 {
                let drift = (time * (5 + Double(i))).truncatingRemainder(dividingBy: size.width + 180)
                let rect = CGRect(x: drift - 180, y: size.height * (0.25 + Double(i) * 0.13), width: 230, height: 24)
                context.fill(Path(roundedRect: rect, cornerRadius: 14), with: .color(.white.opacity(0.10)))
            }
        }
    }

    private func drawClouds(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard condition != .clear else { return }
        let cloudCount = condition == .cloudy ? 7 : 5

        for i in 0..<cloudCount {
            let speed = 3.0 + seeded(i, 11) * 5.0
            let rawX = (seeded(i, 13) * (size.width + 190) + time * speed)
                .truncatingRemainder(dividingBy: size.width + 190)
            let x = rawX - 120
            let y = 18 + seeded(i, 17) * size.height * 0.72
            let scale = 0.65 + seeded(i, 19) * 0.75
            let color = Color.white.opacity(isDay ? 0.10 : 0.06)

            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: x, y: y + 18 * scale, width: 105 * scale, height: 34 * scale))
            cloud.addEllipse(in: CGRect(x: x + 17 * scale, y: y + 5 * scale, width: 50 * scale, height: 47 * scale))
            cloud.addEllipse(in: CGRect(x: x + 52 * scale, y: y, width: 58 * scale, height: 55 * scale))
            context.fill(cloud, with: .color(color))
        }
    }

    private func drawPrecipitation(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        switch condition {
        case .rain, .drizzle, .thunderstorm:
            let count = condition == .drizzle ? 45 : (condition == .thunderstorm ? 100 : 75)
            let speed = condition == .drizzle ? 150.0 : 270.0
            for i in 0..<count {
                let x = seeded(i, 23) * (size.width + 50) - 20
                let offset = seeded(i, 29) * size.height
                let y = (offset + time * (speed + seeded(i, 31) * 90)).truncatingRemainder(dividingBy: size.height + 30) - 20
                var drop = Path()
                drop.move(to: CGPoint(x: x, y: y))
                drop.addLine(to: CGPoint(x: x - 5, y: y + (condition == .drizzle ? 9 : 17)))
                context.stroke(drop, with: .color(.white.opacity(0.24 + seeded(i, 37) * 0.28)), lineWidth: 1)
            }
        case .snow:
            for i in 0..<60 {
                let fall = (seeded(i, 41) * size.height + time * (24 + seeded(i, 43) * 34))
                    .truncatingRemainder(dividingBy: size.height + 16) - 8
                let sway = sin(time * 0.7 + Double(i)) * 10
                let x = seeded(i, 47) * size.width + sway
                let diameter = 2.0 + seeded(i, 53) * 3.5
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: fall, width: diameter, height: diameter)),
                    with: .color(.white.opacity(0.35 + seeded(i, 59) * 0.45))
                )
            }
        default:
            break
        }
    }

    /// Deterministic pseudo-random value in 0...1, stable across redraws.
    private func seeded(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index * 127 + salt * 311)) * 43_758.5453
        return value - floor(value)
    }
}

/// Moon used in the weather scene: only the sunlit portion is drawn, leaving
/// the unlit side fully transparent so no artificial dark disk is visible.
private struct BackgroundMoon: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            guard phase > 0.015, phase < 0.985 else { return }

            let radius = min(size.width, size.height) / 2 - 1
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let litShape = illuminatedPath(phase: phase, center: center, radius: radius)

            context.fill(
                litShape,
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.98, blue: 0.82),
                        Color(red: 0.78, green: 0.78, blue: 0.70)
                    ]),
                    center: CGPoint(x: center.x - radius * 0.12, y: center.y - radius * 0.16),
                    startRadius: 0,
                    endRadius: radius * 1.15
                )
            )
        }
        .accessibilityHidden(true)
    }

    private func illuminatedPath(phase: Double, center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let steps = 80
        let waxing = phase < 0.5
        let normalized = waxing ? phase / 0.5 : (phase - 0.5) / 0.5
        let terminatorX = radius * cos(normalized * .pi)

        path.move(to: CGPoint(x: center.x, y: center.y - radius))

        // Outer edge of the illuminated side, from top to bottom.
        for i in 1...steps {
            let angle = waxing
                ? (-.pi / 2 + .pi * Double(i) / Double(steps))
                : (-.pi / 2 - .pi * Double(i) / Double(steps))
            path.addLine(to: CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }

        // Elliptical day/night terminator, from bottom back to top.
        for i in 0...steps {
            let angle = .pi / 2 - .pi * Double(i) / Double(steps)
            path.addLine(to: CGPoint(
                x: center.x + terminatorX * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }

        path.closeSubpath()
        return path
    }
}

struct MainWeatherView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var weatherManager: WeatherManager
    @ObservedObject var airQualityManager: AirQualityManager

    private let backgroundPreview = BackgroundPreview.fromCommandLine

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Group {
                    if let current = weatherManager.weather?.current {
                        AnimatedWeatherBackground(
                            weather: current,
                            moonPhase: currentMoonPhase,
                            conditionOverride: backgroundPreview.condition,
                            isDayOverride: backgroundPreview.isDay
                        )
                    } else {
                        Rectangle().fill(.thickMaterial)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Keep animated drawing away from the AppKit panel edge and
                // provide an opaque hit-testing surface for footer controls.
                Rectangle()
                    .fill(.clear)
                    .frame(height: 49)
            }
            .allowsHitTesting(false)

            // Ensures empty/translucent areas still belong to this window, so
            // mouse-wheel and trackpad events cannot reach the app beneath it.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { }

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
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Réglages")

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Quitter WeatherBar")
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background {
                ZStack {
                    if let current = weatherManager.weather?.current {
                        WeatherSkyGradient(
                            condition: backgroundPreview.condition ?? current.condition,
                            isDay: backgroundPreview.isDay ?? isCurrentWeatherDay(current)
                        )

                        // Match AnimatedWeatherBackground's readability veil.
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.48)
                    } else {
                        Rectangle().fill(.thickMaterial)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { }
            .foregroundColor(.secondary)
            .zIndex(1)
        }
        }
        .frame(width: 350, height: 680)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var currentMoonPhase: Double? {
        guard let coordinate = settings.selectedLocation?.coordinate else { return nil }
        return MoonCalculator.phaseInfo(
            for: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ).phase
    }

    private func isCurrentWeatherDay(_ weather: CurrentWeather) -> Bool {
        let now = Date()
        return now >= weather.sunrise && now <= weather.sunset
    }
}

/// Debug launch arguments used by `scripts/build.sh --background …`.
/// Unknown or absent values deliberately fall back to live weather.
private struct BackgroundPreview {
    let condition: WeatherCondition?
    let isDay: Bool?

    static var fromCommandLine: BackgroundPreview {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        var condition: WeatherCondition?
        var isDay: Bool?

        if let index = arguments.firstIndex(of: "--weather-background"),
           arguments.indices.contains(index + 1) {
            condition = WeatherCondition(rawValue: arguments[index + 1])
        }
        if arguments.contains("--weather-day") { isDay = true }
        if arguments.contains("--weather-night") { isDay = false }

        return BackgroundPreview(condition: condition, isDay: isDay)
        #else
        return BackgroundPreview(condition: nil, isDay: nil)
        #endif
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
