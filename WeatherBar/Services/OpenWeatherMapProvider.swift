import Foundation

class OpenWeatherMapProvider: WeatherProvider {
    let name = "OpenWeatherMap"

    func fetchWeather(for location: Location, units: TemperatureUnit, lang: String, apiKey: String) async throws -> WeatherData {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let base = "https://api.openweathermap.org/data/2.5"
        let common = "lat=\(lat)&lon=\(lon)&units=\(units.rawValue)&lang=\(lang)&appid=\(apiKey)"

        async let currentResult: OWMCurrent = fetch("\(base)/weather?\(common)")
        async let forecastResult: OWMForecast = fetch("\(base)/forecast?\(common)")

        let (current, forecast) = try await (currentResult, forecastResult)
        return mapResponse(current: current, forecast: forecast)
    }

    // MARK: - Generic fetch

    private func fetch<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw WeatherProviderError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw WeatherProviderError.networkError(NSError(domain: "Network", code: 0))
        }

        if http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["message"] as? String }
                ?? "HTTP \(http.statusCode)"
            throw WeatherProviderError.apiError(message)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[OWM] Decoding error: \(error)")
            throw WeatherProviderError.decodingError(error)
        }
    }

    // MARK: - Mapping

    private func mapResponse(current: OWMCurrent, forecast: OWMForecast) -> WeatherData {
        let dailyGroups = Dictionary(grouping: forecast.list) { entry -> String in
            let date = Date(timeIntervalSince1970: TimeInterval(entry.dt))
            return Calendar.current.startOfDay(for: date).description
        }

        let today = Calendar.current.startOfDay(for: Date()).description
        let todayEntries = dailyGroups[today] ?? []
        let tempMin = todayEntries.map(\.main.temp_min).min() ?? current.main.temp_min
        let tempMax = todayEntries.map(\.main.temp_max).max() ?? current.main.temp_max

        let currentWeather = CurrentWeather(
            temperature: current.main.temp,
            feelsLike: current.main.feels_like,
            tempMin: tempMin,
            tempMax: tempMax,
            humidity: Double(current.main.humidity),
            windSpeed: current.wind.speed,
            windDirection: Double(current.wind.deg ?? 0),
            sunrise: Date(timeIntervalSince1970: TimeInterval(current.sys.sunrise)),
            sunset: Date(timeIntervalSince1970: TimeInterval(current.sys.sunset)),
            condition: mapCondition(current.weather.first?.id ?? 800),
            conditionDescription: current.weather.first?.description.capitalized ?? "",
            iconCode: current.weather.first?.icon ?? "01d"
        )

        let currentEntry = HourlyWeather(
            date: Date(timeIntervalSince1970: TimeInterval(current.dt)),
            temperature: current.main.temp,
            precipitationProbability: 0,
            condition: mapCondition(current.weather.first?.id ?? 800),
            iconCode: current.weather.first?.icon ?? "01d"
        )

        let forecastEntries = forecast.list.map { h in
            HourlyWeather(
                date: Date(timeIntervalSince1970: TimeInterval(h.dt)),
                temperature: h.main.temp,
                precipitationProbability: h.pop ?? 0,
                condition: mapCondition(h.weather.first?.id ?? 800),
                iconCode: h.weather.first?.icon ?? "01d"
            )
        }

        let hourly = ([currentEntry] + forecastEntries)
            .sorted { $0.date < $1.date }

        let sortedDays = dailyGroups
            .sorted { $0.key < $1.key }
            .prefix(7)

        let daily = sortedDays.compactMap { (_, entries) -> DailyWeather? in
            guard let first = entries.first else { return nil }
            let noon = entries.min { abs($0.dt % 86400 - 43200) < abs($1.dt % 86400 - 43200) } ?? first
            return DailyWeather(
                date: Date(timeIntervalSince1970: TimeInterval(first.dt)),
                tempMin: entries.map(\.main.temp_min).min() ?? first.main.temp_min,
                tempMax: entries.map(\.main.temp_max).max() ?? first.main.temp_max,
                condition: mapCondition(noon.weather.first?.id ?? 800),
                conditionDescription: noon.weather.first?.description.capitalized ?? "",
                iconCode: noon.weather.first?.icon ?? "01d"
            )
        }

        return WeatherData(current: currentWeather, hourly: Array(hourly), daily: daily)
    }

    private func mapCondition(_ id: Int) -> WeatherCondition {
        switch id {
        case 200...299: return .thunderstorm
        case 300...399: return .drizzle
        case 500...599: return .rain
        case 600...699: return .snow
        case 700...799: return .atmosphere
        case 800:        return .clear
        default:         return .cloudy
        }
    }
}

// MARK: - DTOs API 2.5

struct OWMCurrent: Decodable {
    let dt: Int
    let weather: [OWMWeatherInfo]
    let main: OWMMain
    let wind: OWMWind
    let sys: OWMSys
}

struct OWMForecast: Decodable {
    let list: [OWMForecastEntry]
}

struct OWMForecastEntry: Decodable {
    let dt: Int
    let main: OWMMain
    let weather: [OWMWeatherInfo]
    let pop: Double?
}

struct OWMMain: Decodable {
    let temp: Double
    let feels_like: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Int
}

struct OWMWind: Decodable {
    let speed: Double
    let deg: Int?
}

struct OWMSys: Decodable {
    let sunrise: Int
    let sunset: Int
}

struct OWMWeatherInfo: Decodable {
    let id: Int
    let description: String
    let icon: String
}
