import Foundation

class OpenMeteoProvider: WeatherProvider {
    let name = "Open-Meteo"
    private let baseURL = "https://api.open-meteo.com/v1/forecast"

    func fetchWeather(for location: Location, units: TemperatureUnit, lang: String) async throws -> WeatherData {
        let tempUnit = units == .celsius ? "celsius" : "fahrenheit"

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude",         value: "\(location.coordinate.latitude)"),
            URLQueryItem(name: "longitude",        value: "\(location.coordinate.longitude)"),
            URLQueryItem(name: "hourly",           value: "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m,wind_direction_10m,uv_index"),
            URLQueryItem(name: "daily",            value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"),
            URLQueryItem(name: "timezone",         value: "auto"),
            URLQueryItem(name: "forecast_days",    value: "7"),
            URLQueryItem(name: "temperature_unit", value: tempUnit),
            URLQueryItem(name: "wind_speed_unit",  value: "kmh"),
        ]

        guard let url = components.url else { throw WeatherProviderError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("WeatherBar/1.0 (macOS; contact: github.com/weather-macmenubar)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WeatherProviderError.networkError(NSError(domain: "Network", code: 0))
        }

        guard http.statusCode == 200 else {
            throw WeatherProviderError.apiError("HTTP \(http.statusCode)")
        }

        do {
            let forecast = try JSONDecoder().decode(OMForecast.self, from: data)
            return mapResponse(forecast: forecast, lang: lang)
        } catch {
            print("[OpenMeteo] Decoding error: \(error)")
            if let s = String(data: data, encoding: .utf8) { print("[OpenMeteo] Response: \(s.prefix(500))") }
            throw WeatherProviderError.decodingError(error)
        }
    }

    // MARK: - Mapping

    private func mapResponse(forecast: OMForecast, lang: String) -> WeatherData {
        let h = forecast.hourly
        let d = forecast.daily

        let hourlyDates  = h.time.compactMap { parseDateTime($0) }
        let dailyDates   = d.time.compactMap { parseDate($0) }
        let sunriseDates = d.sunrise.compactMap { parseDateTime($0) }
        let sunsetDates  = d.sunset.compactMap  { parseDateTime($0) }

        let now = Date()
        let currentIdx = hourlyDates.firstIndex(where: { $0 >= now }) ?? 0

        let sunrise = sunriseDates.first ?? now
        let sunset  = sunsetDates.first  ?? now

        let currentCode = h.weather_code[currentIdx]
        let currentIsDay = now >= sunrise && now <= sunset

        let current = CurrentWeather(
            temperature:          h.temperature_2m[currentIdx],
            feelsLike:            h.apparent_temperature[currentIdx],
            tempMin:              d.temperature_2m_min[0],
            tempMax:              d.temperature_2m_max[0],
            humidity:             Double(h.relative_humidity_2m[currentIdx]),
            windSpeed:            h.wind_speed_10m[currentIdx],
            windDirection:        Double(h.wind_direction_10m[currentIdx]),
            sunrise:              sunrise,
            sunset:               sunset,
            condition:            condition(for: currentCode),
            conditionDescription: describe(currentCode, lang: lang),
            iconCode:             iconCode(currentCode, isDay: currentIsDay),
            tempDeviation:        nil,
            uvIndex:              h.uv_index?[currentIdx]
        )

        let hourly: [HourlyWeather] = hourlyDates.indices.prefix(24).map { i in
            let date    = hourlyDates[i]
            let isDaySr = sunriseDates.first ?? sunrise
            let isDaySt = sunsetDates.first  ?? sunset
            let isDay   = date >= isDaySr && date <= isDaySt
            let code    = h.weather_code[i]
            return HourlyWeather(
                date:                     date,
                temperature:              h.temperature_2m[i],
                precipitationProbability: Double(h.precipitation_probability[i]) / 100.0,
                condition:                condition(for: code),
                iconCode:                 iconCode(code, isDay: isDay),
                windSpeed:                h.wind_speed_10m[i],
                windDirection:            Double(h.wind_direction_10m[i]),
                tempDeviation:            nil
            )
        }

        let calendar = Calendar.current
        let daily: [DailyWeather] = dailyDates.indices.map { i in
            let dayStart    = calendar.startOfDay(for: dailyDates[i])
            let morningS    = calendar.date(bySettingHour: 6,  minute: 0, second: 0, of: dayStart)!
            let morningE    = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
            let morningTemps = zip(hourlyDates, h.temperature_2m)
                .filter { $0.0 >= morningS && $0.0 <= morningE }
                .map(\.1)
            let morningAvg = morningTemps.isEmpty ? nil
                           : morningTemps.reduce(0, +) / Double(morningTemps.count)

            let code = d.weather_code[i]
            return DailyWeather(
                date:                 dailyDates[i],
                tempMin:              d.temperature_2m_min[i],
                tempMax:              d.temperature_2m_max[i],
                condition:            condition(for: code),
                conditionDescription: describe(code, lang: lang),
                iconCode:             iconCode(code, isDay: true),
                morningTemperature:   morningAvg,
                tempDeviation:        nil
            )
        }

        return WeatherData(current: current, hourly: hourly, daily: daily)
    }

    // MARK: - Helpers

    private func iconCode(_ wmo: Int, isDay: Bool) -> String {
        "wmo_\(wmo)_\(isDay ? "day" : "night")"
    }

    private func condition(for wmo: Int) -> WeatherCondition {
        switch wmo {
        case 0, 1:                         return .clear
        case 2, 3:                         return .cloudy
        case 45, 48:                       return .atmosphere
        case 51, 53, 55, 56, 57:           return .drizzle
        case 61, 63, 65, 66, 67, 80...82:  return .rain
        case 71, 73, 75, 77, 85, 86:       return .snow
        case 95, 96, 99:                   return .thunderstorm
        default:                           return .clear
        }
    }

    private func describe(_ wmo: Int, lang: String) -> String {
        let fr = lang.hasPrefix("fr")
        switch wmo {
        case 0:  return fr ? "Ciel dégagé"              : "Clear sky"
        case 1:  return fr ? "Principalement dégagé"    : "Mainly clear"
        case 2:  return fr ? "Partiellement nuageux"    : "Partly cloudy"
        case 3:  return fr ? "Couvert"                  : "Overcast"
        case 45: return fr ? "Brouillard"               : "Fog"
        case 48: return fr ? "Brouillard givrant"       : "Icy fog"
        case 51: return fr ? "Bruine légère"            : "Light drizzle"
        case 53: return fr ? "Bruine modérée"           : "Drizzle"
        case 55: return fr ? "Bruine dense"             : "Heavy drizzle"
        case 56: return fr ? "Bruine verglaçante légère": "Light freezing drizzle"
        case 57: return fr ? "Bruine verglaçante dense" : "Heavy freezing drizzle"
        case 61: return fr ? "Pluie légère"             : "Light rain"
        case 63: return fr ? "Pluie modérée"            : "Rain"
        case 65: return fr ? "Pluie forte"              : "Heavy rain"
        case 66: return fr ? "Pluie verglaçante légère" : "Light freezing rain"
        case 67: return fr ? "Pluie verglaçante forte"  : "Heavy freezing rain"
        case 71: return fr ? "Neige légère"             : "Light snow"
        case 73: return fr ? "Neige modérée"            : "Snow"
        case 75: return fr ? "Neige forte"              : "Heavy snow"
        case 77: return fr ? "Grains de neige"          : "Snow grains"
        case 80: return fr ? "Averses légères"          : "Light showers"
        case 81: return fr ? "Averses modérées"         : "Showers"
        case 82: return fr ? "Averses violentes"        : "Heavy showers"
        case 85: return fr ? "Averses de neige légères" : "Light snow showers"
        case 86: return fr ? "Averses de neige fortes"  : "Heavy snow showers"
        case 95: return fr ? "Orage"                    : "Thunderstorm"
        case 96: return fr ? "Orage avec grêle"         : "Thunderstorm with hail"
        case 99: return fr ? "Orage avec forte grêle"   : "Thunderstorm with heavy hail"
        default: return fr ? "Inconnu"                  : "Unknown"
        }
    }

    // MARK: - Date parsing

    private let hourlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let dailyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseDateTime(_ s: String) -> Date? { hourlyFormatter.date(from: s) }
    private func parseDate(_ s: String) -> Date?     { dailyFormatter.date(from: s) }
}

// MARK: - DTOs

struct OMForecast: Decodable {
    let hourly: OMHourly
    let daily: OMDaily
}

struct OMHourly: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let apparent_temperature: [Double]
    let relative_humidity_2m: [Int]
    let precipitation_probability: [Int]
    let weather_code: [Int]
    let wind_speed_10m: [Double]
    let wind_direction_10m: [Int]
    let uv_index: [Double]?
}

struct OMDaily: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let sunrise: [String]
    let sunset: [String]
    let precipitation_probability_max: [Int]
}
