import Foundation

class MeteoFranceProvider: WeatherProvider {
    let name = "Météo France"
    private let baseURL = "https://webservice.meteofrance.com"

    func fetchWeather(for location: Location, units: TemperatureUnit, lang: String, apiKey: String) async throws -> WeatherData {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Check if location is roughly within Météo France coverage (France + DOM-TOM)
        // This is a very rough estimation.
        // France Métropolitaine: 41°N to 51°N, 5°W to 10°E
        // We'll let the API decide and handle errors.

        let common = "lat=\(lat)&lon=\(lon)&lang=\(lang)&token=\(apiKey)"

        async let forecastResult: MFWebForecast = fetch("\(baseURL)/forecast?\(common)")
        // We might want rain forecast too if available
        // async let rainResult: MFWebRain? = try? await fetch("\(baseURL)/rain?\(common)")

        let forecast = try await forecastResult

        return mapResponse(forecast: forecast)
    }

    private func fetch<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw WeatherProviderError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw WeatherProviderError.networkError(NSError(domain: "Network", code: 0))
        }

        if http.statusCode != 200 {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw WeatherProviderError.apiError("Clé API invalide ou expirée.")
            }
            if http.statusCode == 400 {
                 throw WeatherProviderError.apiError("Cette localisation n'est peut-être pas couverte par Météo France.")
            }
            throw WeatherProviderError.apiError("HTTP \(http.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[MeteoFrance] Decoding error: \(error)")
            throw WeatherProviderError.decodingError(error)
        }
    }

    private func mapResponse(forecast: MFWebForecast) -> WeatherData {
        let currentEntry = forecast.forecast.first { $0.dt >= Int(Date().timeIntervalSince1970) } ?? forecast.forecast.first!
        let todayForecast = forecast.daily_forecast.first!

        let current = CurrentWeather(
            temperature: currentEntry.T,
            feelsLike: currentEntry.T_ressentie ?? currentEntry.T,
            tempMin: todayForecast.T_min,
            tempMax: todayForecast.T_max,
            humidity: Double(currentEntry.humidity ?? 0),
            windSpeed: currentEntry.wind_speed ?? 0,
            windDirection: Double(currentEntry.wind_direction ?? 0),
            sunrise: Date(timeIntervalSince1970: TimeInterval(todayForecast.sunrise ?? 0)),
            sunset: Date(timeIntervalSince1970: TimeInterval(todayForecast.sunset ?? 0)),
            condition: mapCondition(currentEntry.weather_icon),
            conditionDescription: currentEntry.weather_description ?? "",
            iconCode: currentEntry.weather_icon,
            tempDeviation: todayForecast.T_deviation
        )

        let hourly = forecast.forecast.prefix(24).map { h in
            HourlyWeather(
                date: Date(timeIntervalSince1970: TimeInterval(h.dt)),
                temperature: h.T,
                precipitationProbability: Double(h.prob_rain ?? 0) / 100.0,
                condition: mapCondition(h.weather_icon),
                iconCode: h.weather_icon,
                windSpeed: h.wind_speed,
                windDirection: Double(h.wind_direction ?? 0),
                tempDeviation: todayForecast.T_deviation
            )
        }

        let daily = forecast.daily_forecast.map { d in
            DailyWeather(
                date: Date(timeIntervalSince1970: TimeInterval(d.dt)),
                tempMin: d.T_min,
                tempMax: d.T_max,
                condition: mapCondition(d.weather_icon),
                conditionDescription: d.weather_description ?? "",
                iconCode: d.weather_icon,
                morningTemperature: d.T_morning,
                tempDeviation: d.T_deviation
            )
        }

        return WeatherData(current: current, hourly: Array(hourly), daily: daily)
    }

    private func mapCondition(_ icon: String) -> WeatherCondition {
        // Météo France icons are strings like "p1j", "p2j", etc.
        // From observation of some projects mapping MF icons:
        if icon.contains("p1") { return .clear }
        if icon.contains("p2") || icon.contains("p3") { return .clear } // light clouds
        if icon.contains("p4") || icon.contains("p5") { return .cloudy }
        if icon.contains("p6") || icon.contains("p7") || icon.contains("p8") { return .cloudy }
        if icon.contains("p9") || icon.contains("p10") || icon.contains("p11") { return .rain }
        if icon.contains("p12") || icon.contains("p13") || icon.contains("p14") || icon.contains("p15") { return .rain }
        if icon.contains("p16") || icon.contains("p17") || icon.contains("p18") { return .thunderstorm }
        if icon.contains("p19") || icon.contains("p20") { return .snow }
        if icon.contains("p21") || icon.contains("p22") || icon.contains("p23") { return .snow }
        if icon.contains("p24") || icon.contains("p25") { return .atmosphere } // fog
        if icon.contains("p26") || icon.contains("p27") || icon.contains("p28") || icon.contains("p29") || icon.contains("p30") { return .rain } // showers

        return .clear
    }
}

// MARK: - DTOs Météo France

struct MFWebForecast: Decodable {
    let forecast: [MFWebHourlyEntry]
    let daily_forecast: [MFWebDailyEntry]
}

struct MFWebHourlyEntry: Decodable {
    let dt: Int
    let T: Double
    let T_ressentie: Double?
    let humidity: Int?
    let wind_speed: Double?
    let wind_direction: Int?
    let weather_icon: String
    let weather_description: String?
    let prob_rain: Int?

    enum CodingKeys: String, CodingKey {
        case dt
        case T = "t"
        case T_ressentie = "fl"
        case humidity = "h"
        case wind_speed = "w"
        case wind_direction = "d"
        case weather_icon = "icon"
        case weather_description = "desc"
        case prob_rain = "pop"
    }
}

struct MFWebDailyEntry: Decodable {
    let dt: Int
    let T_min: Double
    let T_max: Double
    let T_morning: Double?
    let T_deviation: Double?
    let weather_icon: String
    let weather_description: String?
    let sunrise: Int?
    let sunset: Int?

    enum CodingKeys: String, CodingKey {
        case dt
        case T_min = "min"
        case T_max = "max"
        case T_morning = "morning"
        case T_deviation = "deviation"
        case weather_icon = "icon"
        case weather_description = "desc"
        case sunrise
        case sunset
    }
}
