import Foundation

// OWM icon codes reference:
// 01d/n = clear sky
// 02d/n = few clouds (11-25%)
// 03d/n = scattered clouds (25-50%)
// 04d/n = broken/overcast clouds (51-100%)
// 09d/n = shower rain
// 10d/n = rain
// 11d/n = thunderstorm
// 13d/n = snow/sleet
// 50d/n = mist/fog/haze/smoke

struct WeatherIconMapper {
    static func symbol(for iconCode: String) -> String {
        switch iconCode {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.stars.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d": return "cloud.fill"
        case "03n": return "cloud.fill"
        case "04d": return "smoke.fill"
        case "04n": return "smoke.fill"
        case "09d": return "cloud.drizzle.fill"
        case "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d": return "cloud.bolt.rain.fill"
        case "11n": return "cloud.bolt.rain.fill"
        case "13d": return "snowflake"
        case "13n": return "snowflake"
        case "50d": return "cloud.fog.fill"
        case "50n": return "cloud.fog.fill"
        default:    return "cloud.fill"
        }
    }
}
