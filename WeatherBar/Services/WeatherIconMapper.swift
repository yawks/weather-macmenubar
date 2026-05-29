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
        // Météo France
        if iconCode.hasPrefix("p") {
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

        if icon.contains("p1") { return isNight ? "moon.stars.fill" : "sun.max.fill" }
        if icon.contains("p2") { return isNight ? "cloud.moon.fill" : "cloud.sun.fill" }
        if icon.contains("p3") { return "cloud.fill" }
        if icon.contains("p4") || icon.contains("p5") { return "cloud.fill" }
        if icon.contains("p6") || icon.contains("p7") || icon.contains("p8") { return "cloud.fill" }
        if icon.contains("p9") || icon.contains("p10") || icon.contains("p11") { return "cloud.rain.fill" }
        if icon.contains("p12") || icon.contains("p13") || icon.contains("p14") || icon.contains("p15") { return "cloud.heavyrain.fill" }
        if icon.contains("p16") || icon.contains("p17") || icon.contains("p18") { return "cloud.bolt.rain.fill" }
        if icon.contains("p19") || icon.contains("p20") { return "snowflake" }
        if icon.contains("p21") || icon.contains("p22") || icon.contains("p23") { return "snow" }
        if icon.contains("p24") || icon.contains("p25") { return "cloud.fog.fill" }
        if icon.contains("p26") || icon.contains("p27") || icon.contains("p28") || icon.contains("p29") || icon.contains("p30") { return "cloud.drizzle.fill" }

        return isNight ? "moon.stars.fill" : "sun.max.fill"
    }
}
