import Foundation

class MeteoFranceProvider: WeatherProvider {
    let name = "Météo France"
    private let baseURL = "https://public-api.meteofrance.fr/public/DPPrevision/v1"

    func fetchWeather(for location: Location, units: TemperatureUnit, lang: String, apiKey: String) async throws -> WeatherData {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // The official Public API (DPPrevision v1) uses coordinates
        let urlString = "\(baseURL)/forecast?lat=\(lat)&lon=\(lon)&lang=\(lang)"

        let forecast: MFPublicForecast = try await fetch(urlString, apiKey: apiKey)

        return mapResponse(forecast: forecast)
    }

    private func fetch<T: Decodable>(_ urlString: String, apiKey: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw WeatherProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WeatherProviderError.networkError(NSError(domain: "Network", code: 0))
        }

        if http.statusCode != 200 {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw WeatherProviderError.apiError("Clé API invalide ou expirée (Header 'apikey').")
            }
            if http.statusCode == 429 {
                throw WeatherProviderError.apiError("Quota dépassé sur le portail API Météo France.")
            }
            throw WeatherProviderError.apiError("HTTP \(http.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            // The API uses ISO8601 dates often
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[MeteoFrance] Decoding error: \(error)")
            // Try to print the data to see the structure if it fails
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[MeteoFrance] Data received: \(jsonString)")
            }
            throw WeatherProviderError.decodingError(error)
        }
    }

    private func mapResponse(forecast: MFPublicForecast) -> WeatherData {
        let properties = forecast.properties

        // Find current or nearest hourly forecast
        let now = Date()
        let currentEntry = properties.forecast.first { $0.time >= now } ?? properties.forecast.first!

        // Use the first daily forecast for summary
        let todayForecast = properties.daily_forecast.first!

        // Simulation of morning temperature: average of 6am to 12pm
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let morningStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: today)!
        let morningEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!

        let morningTemps = properties.forecast.filter { $0.time >= morningStart && $0.time <= morningEnd }.map { $0.T }
        let morningAvg = morningTemps.isEmpty ? nil : morningTemps.reduce(0, +) / Double(morningTemps.count)

        let current = CurrentWeather(
            temperature: currentEntry.T,
            feelsLike: currentEntry.T_windchill ?? currentEntry.T,
            tempMin: todayForecast.T_min,
            tempMax: todayForecast.T_max,
            humidity: Double(currentEntry.humidity ?? 0),
            windSpeed: currentEntry.wind_speed ?? 0,
            windDirection: Double(currentEntry.wind_direction ?? 0),
            sunrise: todayForecast.sunrise_time ?? Date(),
            sunset: todayForecast.sunset_time ?? Date(),
            condition: mapCondition(currentEntry.weather_icon),
            conditionDescription: currentEntry.weather_description ?? "",
            iconCode: currentEntry.weather_icon,
            tempDeviation: nil
        )

        let hourly = properties.forecast.prefix(24).map { h in
            HourlyWeather(
                date: h.time,
                temperature: h.T,
                precipitationProbability: Double(h.precipitation_hazard_1h ?? 0) / 100.0,
                condition: mapCondition(h.weather_icon),
                iconCode: h.weather_icon,
                windSpeed: h.wind_speed,
                windDirection: Double(h.wind_direction ?? 0),
                tempDeviation: nil
            )
        }

        let daily = properties.daily_forecast.map { d in
            let dStart = calendar.startOfDay(for: d.time)
            let dMorningStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: dStart)!
            let dMorningEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dStart)!
            let dMorningTemps = properties.forecast.filter { $0.time >= dMorningStart && $0.time <= dMorningEnd }.map { $0.T }
            let dMorningAvg = dMorningTemps.isEmpty ? nil : dMorningTemps.reduce(0, +) / Double(dMorningTemps.count)

            return DailyWeather(
                date: d.time,
                tempMin: d.T_min,
                tempMax: d.T_max,
                condition: mapCondition(d.daily_weather_icon),
                conditionDescription: d.daily_weather_description ?? "",
                iconCode: d.daily_weather_icon,
                morningTemperature: dMorningAvg,
                tempDeviation: nil
            )
        }

        return WeatherData(current: current, hourly: Array(hourly), daily: daily)
    }

    private func mapCondition(_ icon: String) -> WeatherCondition {
        // Official API icons start with 'i' (e.g., "i1j", "i2n")
        if icon.contains("i1") { return .clear }
        if icon.contains("i2") { return .clear } // light clouds
        if icon.contains("i3") || icon.contains("i4") || icon.contains("i5") { return .cloudy }
        if icon.contains("i6") || icon.contains("i7") || icon.contains("i8") { return .cloudy }
        if icon.contains("i9") || icon.contains("i10") || icon.contains("i11") { return .rain }
        if icon.contains("i12") || icon.contains("i13") || icon.contains("i14") || icon.contains("i15") { return .rain }
        if icon.contains("i16") || icon.contains("i17") || icon.contains("i18") { return .thunderstorm }
        if icon.contains("i19") || icon.contains("i20") { return .snow }
        if icon.contains("i21") || icon.contains("i22") || icon.contains("i23") { return .snow }
        if icon.contains("i24") || icon.contains("i25") { return .atmosphere }
        if icon.contains("i26") || icon.contains("i27") || icon.contains("i28") || icon.contains("i29") || icon.contains("i30") { return .rain }

        // Fallback for codes found in the rwg API or older ones
        if icon.contains("i91") || icon.contains("i92") || icon.contains("i93") { return .thunderstorm }
        if icon.contains("i72") || icon.contains("i73") || icon.contains("i74") { return .rain }
        if icon.contains("i50") || icon.contains("i51") || icon.contains("i52") { return .rain }

        return .clear
    }
}

// MARK: - DTOs Official Portal (DPPrevision v1)

struct MFPublicForecast: Decodable {
    let properties: MFPublicProperties
}

struct MFPublicProperties: Decodable {
    let forecast: [MFPublicHourlyEntry]
    let daily_forecast: [MFPublicDailyEntry]
}

struct MFPublicHourlyEntry: Decodable {
    let time: Date
    let T: Double
    let T_windchill: Double?
    let humidity: Int?
    let wind_speed: Double?
    let wind_direction: Int?
    let weather_icon: String
    let weather_description: String?
    let precipitation_hazard_1h: Int?

    enum CodingKeys: String, CodingKey {
        case time
        case T
        case T_windchill
        case humidity
        case wind_speed
        case wind_direction
        case weather_icon
        case weather_description
        case precipitation_hazard_1h
    }
}

struct MFPublicDailyEntry: Decodable {
    let time: Date
    let T_min: Double
    let T_max: Double
    let daily_weather_icon: String
    let daily_weather_description: String?
    let sunrise_time: Date?
    let sunset_time: Date?

    enum CodingKeys: String, CodingKey {
        case time
        case T_min
        case T_max
        case daily_weather_icon
        case daily_weather_description
        case sunrise_time
        case sunset_time
    }
}
