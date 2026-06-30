import Foundation

struct MoonPhaseInfo {
    let phase: Double          // 0.0–1.0 (0 = new moon, 0.5 = full moon)
    let phaseName: String
    let illumination: Double   // 0.0–1.0
    let moonrise: Date?
    let moonset: Date?
}

enum MoonPhase: String {
    case newMoon            = "Nouvelle lune"
    case waxingCrescent     = "Croissant croissant"
    case firstQuarter       = "Premier quartier"
    case waxingGibbous      = "Lune gibbeuse croissante"
    case fullMoon           = "Pleine lune"
    case waningGibbous      = "Lune gibbeuse décroissante"
    case lastQuarter        = "Dernier quartier"
    case waningCrescent     = "Croissant décroissant"

    static func from(phase: Double) -> MoonPhase {
        switch phase {
        case 0..<0.0625:   return .newMoon
        case 0.0625..<0.1875: return .waxingCrescent
        case 0.1875..<0.3125: return .firstQuarter
        case 0.3125..<0.4375: return .waxingGibbous
        case 0.4375..<0.5625: return .fullMoon
        case 0.5625..<0.6875: return .waningGibbous
        case 0.6875..<0.8125: return .lastQuarter
        case 0.8125..<0.9375: return .waningCrescent
        default:              return .newMoon
        }
    }

    var sfSymbol: String {
        switch self {
        case .newMoon:         return "moonphase.new.moon"
        case .waxingCrescent:  return "moonphase.waxing.crescent"
        case .firstQuarter:    return "moonphase.first.quarter"
        case .waxingGibbous:   return "moonphase.waxing.gibbous"
        case .fullMoon:        return "moonphase.full.moon"
        case .waningGibbous:   return "moonphase.waning.gibbous"
        case .lastQuarter:     return "moonphase.last.quarter"
        case .waningCrescent:  return "moonphase.waning.crescent"
        }
    }
}

struct MoonCalculator {

    // MARK: - Phase calculation (Jean Meeus algorithm)

    static func phaseInfo(for date: Date, latitude: Double, longitude: Double) -> MoonPhaseInfo {
        let jd = julianDay(from: date)
        let phase = moonPhase(jd: jd)
        let illumination = (1 - cos(2 * .pi * phase)) / 2
        let phaseName = MoonPhase.from(phase: phase).rawValue

        let (rise, set) = moonRiseSet(date: date, latitude: latitude, longitude: longitude)

        return MoonPhaseInfo(
            phase: phase,
            phaseName: phaseName,
            illumination: illumination,
            moonrise: rise,
            moonset: set
        )
    }

    // MARK: - Julian day

    private static func julianDay(from date: Date) -> Double {
        let cal = Calendar(identifier: .gregorian)
        var comps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        var Y = Double(comps.year!)
        var M = Double(comps.month!)
        let D = Double(comps.day!) + Double(comps.hour! * 3600 + comps.minute! * 60 + comps.second!) / 86400.0

        if M <= 2 { Y -= 1; M += 12 }
        let A = floor(Y / 100)
        let B = 2 - A + floor(A / 4)
        return floor(365.25 * (Y + 4716)) + floor(30.6001 * (M + 1)) + D + B - 1524.5
    }

    // Returns phase 0–1 where 0/1 = new moon, 0.5 = full moon
    private static func moonPhase(jd: Double) -> Double {
        let k = (jd - 2451550.1) / 29.530588853
        return k - floor(k)
    }

    // MARK: - Moonrise / Moonset

    private static func moonRiseSet(date: Date, latitude: Double, longitude: Double) -> (rise: Date?, set: Date?) {
        let cal = Calendar(identifier: .gregorian)
        let tz  = TimeZone.current
        var comps = cal.dateComponents(in: tz, from: date)
        comps.hour = 0; comps.minute = 0; comps.second = 0
        guard let midnight = cal.date(from: comps) else { return (nil, nil) }

        let jd0 = julianDay(from: midnight)
        let lat  = latitude  * .pi / 180
        let lon  = longitude

        var rise: Date? = nil
        var set:  Date? = nil

        // Search 36 hours (not just 24) so a moonrise just after midnight is found
        // and can be shown as "dem. HH:mm". Step = 10 minutes.
        let windowHours = 36.0
        let steps = Int(windowHours * 6)   // 6 steps/hour = 10 min each
        var prevAlt  = moonAltitude(jd: jd0, lat: lat, lon: lon)
        var prevSign = prevAlt > 0

        for i in 1...steps {
            let t   = Double(i) / Double(steps) * (windowHours / 24.0)
            let jd  = jd0 + t
            let alt = moonAltitude(jd: jd, lat: lat, lon: lon)
            let sign = alt > 0

            if sign != prevSign {
                let frac      = abs(prevAlt) / (abs(prevAlt) + abs(alt))
                let crossFrac = (Double(i - 1) + frac) / Double(steps) * (windowHours / 24.0)
                let crossDate = midnight.addingTimeInterval(crossFrac * 86400)

                if prevSign && !sign {
                    if set == nil  { set  = crossDate }
                } else {
                    if rise == nil { rise = crossDate }
                }
            }
            prevAlt  = alt
            prevSign = sign
        }
        return (rise, set)
    }

    // Moon altitude in degrees above horizon
    private static func moonAltitude(jd: Double, lat: Double, lon: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        let D = jd - 2451545.0

        // Reduce all degree angles mod 360 before converting to rad — avoids float
        // precision loss when D is large (tens of thousands of days past J2000)
        func norm(_ deg: Double) -> Double {
            let r = deg.truncatingRemainder(dividingBy: 360)
            return r < 0 ? r + 360 : r
        }

        let L0 = norm(218.316 + 13.176396 * D)
        let M  = toRad(norm(134.963 + 13.064993 * D))
        let F  = toRad(norm(93.272  + 13.229350 * D))

        let lon_moon = toRad(L0 + 6.289 * sin(M) - 1.274 * sin(2 * F - M) + 0.658 * sin(2 * F))
        let lat_moon = toRad(5.128 * sin(F))

        let eps = toRad(23.439 - 0.0000004 * T)

        let ra  = atan2(sin(lon_moon) * cos(eps) - tan(lat_moon) * sin(eps), cos(lon_moon))
        let dec = asin(sin(lat_moon) * cos(eps) + cos(lat_moon) * sin(eps) * sin(lon_moon))

        // GMST réduit mod 360 → Local Hour Angle
        let gmst = toRad(norm(280.46061837 + 360.98564736629 * D))
        let lha  = gmst + toRad(lon) - ra

        let alt = asin(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(lha))
        return alt * 180 / .pi
    }

    private static func toRad(_ deg: Double) -> Double { deg * .pi / 180 }
}
