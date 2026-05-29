import Foundation

class OpenWeatherMapProvider: WeatherProvider {
    let name = "OpenWeatherMap"

    func fetchWeather(for location: Location, units: TemperatureUnit, lang: String, apiKey: String) async throws -> WeatherData {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Using One Call API 3.0
        let urlString = "https://api.openweathermap.org/data/3.0/onecall?lat=\(lat)&lon=\(lon)&units=\(units.rawValue)&exclude=minutely,alerts&appid=\(apiKey)&lang=\(lang)"

        guard let url = URL(string: urlString) else {
            throw WeatherProviderError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherProviderError.networkError(NSError(domain: "Network", code: 0))
        }

        if httpResponse.statusCode != 200 {
            // Try to decode error message from OWM
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorObj["message"] as? String {
                throw WeatherProviderError.apiError(message)
            }
            throw WeatherProviderError.apiError("HTTP Error \(httpResponse.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let wrapper = try decoder.decode(OWMResponse.self, from: data)
            return mapResponse(wrapper)
        } catch {
            print("Decoding error: \(error)")
            throw WeatherProviderError.decodingError(error)
        }
    }

    private func mapResponse(_ wrapper: OWMResponse) -> WeatherData {
        let current = CurrentWeather(
            temperature: wrapper.current.temp,
            feelsLike: wrapper.current.feels_like,
            tempMin: wrapper.daily.first?.temp.min ?? wrapper.current.temp,
            tempMax: wrapper.daily.first?.temp.max ?? wrapper.current.temp,
            humidity: Double(wrapper.current.humidity),
            windSpeed: wrapper.current.wind_speed,
            windDirection: Double(wrapper.current.wind_deg),
            sunrise: Date(timeIntervalSince1970: TimeInterval(wrapper.current.sunrise)),
            sunset: Date(timeIntervalSince1970: TimeInterval(wrapper.current.sunset)),
            condition: mapCondition(wrapper.current.weather.first?.id ?? 800),
            conditionDescription: wrapper.current.weather.first?.description.capitalized ?? "",
            iconCode: wrapper.current.weather.first?.icon ?? "01d"
        )

        let hourly = wrapper.hourly.prefix(24).map { h in
            HourlyWeather(
                date: Date(timeIntervalSince1970: TimeInterval(h.dt)),
                temperature: h.temp,
                precipitationProbability: h.pop,
                condition: mapCondition(h.weather.first?.id ?? 800),
                iconCode: h.weather.first?.icon ?? "01d"
            )
        }

        let daily = wrapper.daily.map { d in
            DailyWeather(
                date: Date(timeIntervalSince1970: TimeInterval(d.dt)),
                tempMin: d.temp.min,
                tempMax: d.temp.max,
                condition: mapCondition(d.weather.first?.id ?? 800),
                conditionDescription: d.weather.first?.description.capitalized ?? "",
                iconCode: d.weather.first?.icon ?? "01d"
            )
        }

        return WeatherData(current: current, hourly: Array(hourly), daily: daily)
    }

    private func mapCondition(_ id: Int) -> WeatherCondition {
        switch id {
        case 200...299: return .thunderstorm
        case 300...399: return .drizzle
        case 500...599: return .rain
        case 600...699: return .snow
        case 700...799: return .atmosphere
        case 800: return .clear
        default: return .cloudy
        }
    }
}

// Internal OWM DTOs
struct OWMResponse: Codable {
    let current: OWMCurrent
    let hourly: [OWMHourly]
    let daily: [OWMDaily]
}

struct OWMCurrent: Codable {
    let dt: Int
    let sunrise: Int
    let sunset: Int
    let temp: Double
    let feels_like: Double
    let humidity: Int
    let wind_speed: Double
    let wind_deg: Int
    let weather: [OWMWeatherInfo]
}

struct OWMHourly: Codable {
    let dt: Int
    let temp: Double
    let pop: Double
    let weather: [OWMWeatherInfo]
}

struct OWMDaily: Codable {
    let dt: Int
    let temp: OWMDayTemp
    let weather: [OWMWeatherInfo]
}

struct OWMDayTemp: Codable {
    let min: Double
    let max: Double
}

struct OWMWeatherInfo: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}
