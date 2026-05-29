import Foundation

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct Location: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let name: String
    let coordinate: Coordinate

    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
}

enum WeatherCondition: String, Codable {
    case clear, cloudy, rain, snow, drizzle, thunderstorm, atmosphere

    var sfSymbolName: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snowflake"
        case .drizzle: return "cloud.drizzle.fill"
        case .thunderstorm: return "cloud.bolt.fill"
        case .atmosphere: return "cloud.fog.fill"
        }
    }
}

struct WeatherData: Codable {
    let current: CurrentWeather
    let hourly: [HourlyWeather]
    let daily: [DailyWeather]
}

struct CurrentWeather: Codable {
    let temperature: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let humidity: Double
    let windSpeed: Double
    let windDirection: Double
    let sunrise: Date
    let sunset: Date
    let condition: WeatherCondition
    let conditionDescription: String
    let iconCode: String // Original API icon code for day/night differentiation
}

struct HourlyWeather: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let temperature: Double
    let precipitationProbability: Double // 0 to 1
    let condition: WeatherCondition
    let iconCode: String
}

struct DailyWeather: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let tempMin: Double
    let tempMax: Double
    let condition: WeatherCondition
    let conditionDescription: String
    let iconCode: String
}

enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius = "metric"
    case fahrenheit = "imperial"

    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}
