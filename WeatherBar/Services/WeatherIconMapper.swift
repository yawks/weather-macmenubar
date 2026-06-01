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
        // Open-Meteo WMO codes: "wmo_CODE_day" / "wmo_CODE_night"
        if iconCode.hasPrefix("wmo_") {
            let parts = iconCode.split(separator: "_")
            if parts.count >= 2, let code = Int(parts[1]) {
                return symbolForWMO(code, isNight: parts.last == "night")
            }
            return "cloud.fill"
        }

        switch iconCode {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.stars.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d": return "cloud.fill"
        case "03n": return "cloud.fill"
        case "04d": return "cloud.fill"
        case "04n": return "cloud.fill"
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
        default:
            print("[WeatherIconMapper] OWM icon non mappé : '\(iconCode)'")
            return "cloud.fill"
        }
    }

    private static func symbolForWMO(_ code: Int, isNight: Bool) -> String {
        switch code {
        case 0:       return isNight ? "moon.stars.fill"      : "sun.max.fill"
        case 1:       return isNight ? "moon.stars.fill"      : "sun.max.fill"
        case 2:       return isNight ? "cloud.moon.fill"      : "cloud.sun.fill"
        case 3:       return "cloud.fill"
        case 45, 48:  return "cloud.fog.fill"
        case 51, 53:  return "cloud.drizzle.fill"
        case 55...57: return "cloud.drizzle.fill"
        case 61, 63:  return isNight ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill"
        case 65:      return "cloud.heavyrain.fill"
        case 66, 67:  return "cloud.rain.fill"
        case 71, 73:  return "snowflake"
        case 75, 77:  return "snowflake"
        case 80, 81:  return isNight ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill"
        case 82:      return "cloud.heavyrain.fill"
        case 85, 86:  return "cloud.snow.fill"
        case 95:      return "cloud.bolt.rain.fill"
        case 96, 99:  return "cloud.bolt.rain.fill"
        default:
            print("[WeatherIconMapper] WMO code non mappé : \(code) (isNight=\(isNight))")
            return "cloud.fill"
        }
    }

}
