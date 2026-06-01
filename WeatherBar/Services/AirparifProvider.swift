import Foundation

class AirparifProvider: AirQualityProvider {
    let name = "Airparif"
    let supportedMetrics: Set<AirMetric> = AirProviderType.airparif.supportedMetrics

    private let apiKey: String
    private let inseeCode: String
    private let enabledMetrics: Set<AirMetric>
    private let baseURL = "https://api.airparif.asso.fr"

    // Airparif pollutant names used in the horair endpoint
    private static let horairNames: [AirMetric: String] = [
        .no2:  "no2",
        .o3:   "o3",
        .pm10: "pm10",
        .pm25: "pm25",
    ]

    init(apiKey: String, inseeCode: String, enabledMetrics: Set<AirMetric>) {
        self.apiKey = apiKey
        self.inseeCode = inseeCode
        self.enabledMetrics = enabledMetrics
    }

    func fetchAirQuality(for location: Location) async throws -> [AirQualityReading] {
        guard !apiKey.isEmpty    else { throw AirQualityProviderError.missingConfiguration("clé API Airparif") }
        guard !inseeCode.isEmpty else { throw AirQualityProviderError.missingConfiguration("code INSEE") }

        // Labels (required) + values (best-effort)
        let labels = try await fetchLabels()
        let values = (try? await fetchHorair(location: location)) ?? [:]

        return buildReadings(labels: labels, values: values)
    }

    // MARK: - Labels endpoint

    private func fetchLabels() async throws -> [AirMetric: AirQualityIndex] {
        guard let url = URL(string: "\(baseURL)/indices/prevision/commune?insee=\(inseeCode)") else {
            throw AirQualityProviderError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AirQualityProviderError.networkError(NSError(domain: "Network", code: 0))
        }
        guard http.statusCode == 200 else {
            throw AirQualityProviderError.apiError("HTTP \(http.statusCode)")
        }

        do {
            let raw = try JSONDecoder().decode([String: [AirparifDailyIndice]].self, from: data)
            guard let forecasts = raw[inseeCode], let today = forecasts.first else { return [:] }

            var result: [AirMetric: AirQualityIndex] = [:]
            let pairs: [(AirMetric, String?)] = [
                (.no2, today.no2), (.o3, today.o3),
                (.pm10, today.pm10), (.pm25, today.pm25), (.so2, today.so2),
            ]
            for (metric, label) in pairs {
                if let label, let idx = AirQualityIndex.from(atmoLabel: label) {
                    result[metric] = idx
                }
            }
            return result
        } catch {
            throw AirQualityProviderError.decodingError(error)
        }
    }

    // MARK: - Horair endpoint (µg/m³ values)

    private func fetchHorair(location: Location) async throws -> [AirMetric: Double] {
        guard let url = URL(string: "\(baseURL)/horair/historique") else {
            throw AirQualityProviderError.invalidURL
        }

        let requested = enabledMetrics
            .intersection(supportedMetrics)
            .compactMap { Self.horairNames[$0] }
        guard !requested.isEmpty else { return [:] }

        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime]

        let body: [String: Any] = [
            "longitude": location.coordinate.longitude,
            "latitude":  location.coordinate.latitude,
            "datemax":   isoFmt.string(from: Date()),
            "heures":    1,
            "polluants": requested,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [:] }

        let horairResp = try JSONDecoder().decode(AirparifHorairResponse.self, from: data)

        var result: [AirMetric: Double] = [:]
        for (metric, omName) in Self.horairNames {
            if let values = horairResp.valeurs[omName], !values.isEmpty, let dv = values[0] {
                result[metric] = dv
            }
        }
        return result
    }

    // MARK: - Build readings

    private func buildReadings(
        labels: [AirMetric: AirQualityIndex],
        values: [AirMetric: Double]
    ) -> [AirQualityReading] {
        enabledMetrics
            .intersection(supportedMetrics)
            .map { metric in
                AirQualityReading(
                    metric: metric,
                    value: values[metric],
                    index: labels[metric],
                    providerName: name
                )
            }
    }
}

// MARK: - DTOs

struct AirparifDailyIndice: Decodable {
    let date: String
    let indice: String?
    let no2: String?
    let o3: String?
    let pm10: String?
    let pm25: String?
    let so2: String?
}

struct AirparifHorairResponse: Decodable {
    let valeurs: [String: [Double?]]
}
