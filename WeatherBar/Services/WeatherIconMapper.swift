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
        // Météo France (p codes are old/mobile, i codes are official portal)
        if iconCode.hasPrefix("p") || iconCode.hasPrefix("i") {
            return symbolForMeteoFrance(iconCode)
        }

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

    private static func symbolForMeteoFrance(_ icon: String) -> String {
        let isNight = icon.hasSuffix("n")

        // Handling both 'p' and 'i' prefixes
        if icon.contains("1") { return isNight ? "moon.stars.fill" : "sun.max.fill" }
        if icon.contains("2") { return isNight ? "cloud.moon.fill" : "cloud.sun.fill" }
        if icon.contains("3") || icon.contains("4") || icon.contains("5") { return "cloud.fill" }
        if icon.contains("6") || icon.contains("7") || icon.contains("8") { return "cloud.fill" }
        if icon.contains("9") || icon.contains("10") || icon.contains("11") { return "cloud.rain.fill" }
        if icon.contains("12") || icon.contains("13") || icon.contains("14") || icon.contains("15") { return "cloud.heavyrain.fill" }
        if icon.contains("16") || icon.contains("17") || icon.contains("18") { return "cloud.bolt.rain.fill" }
        if icon.contains("19") || icon.contains("20") || icon.contains("21") || icon.contains("22") || icon.contains("23") { return "snowflake" }
        if icon.contains("24") || icon.contains("25") { return "cloud.fog.fill" }
        if icon.contains("26") || icon.contains("27") || icon.contains("28") || icon.contains("29") || icon.contains("30") { return "cloud.drizzle.fill" }

        // Specific codes for official portal API
        if icon.contains("91") || icon.contains("92") || icon.contains("93") { return "cloud.bolt.rain.fill" }
        if icon.contains("72") || icon.contains("73") || icon.contains("74") { return "cloud.rain.fill" }
        if icon.contains("50") || icon.contains("51") || icon.contains("52") { return "cloud.heavyrain.fill" }

        return isNight ? "moon.stars.fill" : "sun.max.fill"
    }
}
