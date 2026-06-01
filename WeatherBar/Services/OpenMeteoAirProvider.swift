import Foundation

class OpenMeteoAirProvider: AirQualityProvider {
    let name = "Open-Meteo Air"
    let supportedMetrics: Set<AirMetric> = AirProviderType.openMeteo.supportedMetrics

    private let enabledMetrics: Set<AirMetric>
    private let baseURL = "https://air-quality-api.open-meteo.com/v1/air-quality"

    // Open-Meteo variable name per metric
    private static let variableNames: [AirMetric: String] = [
        .europeanAQI:   "european_aqi",
        .pm25:          "pm2_5",
        .pm10:          "pm10",
        .no2:           "nitrogen_dioxide",
        .o3:            "ozone",
        .so2:           "sulphur_dioxide",
        .pollenGrasses: "grass_pollen",
        .pollenBirch:   "birch_pollen",
        .pollenAlder:   "alder_pollen",
        .pollenOlive:   "olive_pollen",
        .pollenRagweed: "ragweed_pollen",
        .pollenMugwort: "mugwort_pollen",
    ]

    init(enabledMetrics: Set<AirMetric>) {
        self.enabledMetrics = enabledMetrics
    }

    func fetchAirQuality(for location: Location) async throws -> [AirQualityReading] {
        let requestedVars = supportedMetrics
            .compactMap { Self.variableNames[$0] }
            .joined(separator: ",")

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude",     value: "\(location.coordinate.latitude)"),
            URLQueryItem(name: "longitude",    value: "\(location.coordinate.longitude)"),
            URLQueryItem(name: "hourly",       value: requestedVars),
            URLQueryItem(name: "timezone",     value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]

        guard let url = components.url else { throw AirQualityProviderError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw AirQualityProviderError.networkError(NSError(domain: "Network", code: 0))
        }
        guard http.statusCode == 200 else {
            throw AirQualityProviderError.apiError("HTTP \(http.statusCode)")
        }

        do {
            let forecast = try JSONDecoder().decode(OMAirForecast.self, from: data)
            return mapResponse(forecast.hourly)
        } catch {
            print("[OpenMeteoAir] Decoding error: \(error)")
            throw AirQualityProviderError.decodingError(error)
        }
    }

    // MARK: - Mapping

    private func mapResponse(_ hourly: OMAirHourly) -> [AirQualityReading] {
        let idx = currentHourIndex(times: hourly.time)

        func val(_ arr: [Double?]?) -> Double? {
            guard let a = arr, idx < a.count else { return nil }
            return a[idx]
        }

        var readings: [AirQualityReading] = []

        let metricData: [(AirMetric, Double?)] = [
            (.europeanAQI,   val(hourly.european_aqi)),
            (.pm25,          val(hourly.pm2_5)),
            (.pm10,          val(hourly.pm10)),
            (.no2,           val(hourly.nitrogen_dioxide)),
            (.o3,            val(hourly.ozone)),
            (.so2,           val(hourly.sulphur_dioxide)),
            (.pollenGrasses, val(hourly.grass_pollen)),
            (.pollenBirch,   val(hourly.birch_pollen)),
            (.pollenAlder,   val(hourly.alder_pollen)),
            (.pollenOlive,   val(hourly.olive_pollen)),
            (.pollenRagweed, val(hourly.ragweed_pollen)),
            (.pollenMugwort, val(hourly.mugwort_pollen)),
        ]

        for (metric, value) in metricData {
            guard enabledMetrics.contains(metric) else { continue }
            let index: AirQualityIndex?
            if let v = value {
                switch metric {
                case .europeanAQI:
                    index = .from(europeanAQI: v)
                case .pollenGrasses, .pollenBirch, .pollenAlder,
                     .pollenOlive, .pollenRagweed, .pollenMugwort:
                    index = .fromPollen(v)
                default:
                    index = .fromConcentration(v, for: metric)
                }
            } else {
                index = nil
            }
            readings.append(AirQualityReading(metric: metric, value: value, index: index, providerName: name))
        }

        return readings
    }

    private func currentHourIndex(times: [String]) -> Int {
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let dates = times.compactMap { fmt.date(from: $0) }
        return dates.firstIndex(where: { $0 >= now }) ?? 0
    }
}

// MARK: - DTOs

struct OMAirForecast: Decodable {
    let hourly: OMAirHourly
}

struct OMAirHourly: Decodable {
    let time: [String]
    var pm10: [Double?]?
    var pm2_5: [Double?]?
    var nitrogen_dioxide: [Double?]?
    var sulphur_dioxide: [Double?]?
    var ozone: [Double?]?
    var european_aqi: [Double?]?
    var grass_pollen: [Double?]?
    var birch_pollen: [Double?]?
    var alder_pollen: [Double?]?
    var olive_pollen: [Double?]?
    var ragweed_pollen: [Double?]?
    var mugwort_pollen: [Double?]?
}
