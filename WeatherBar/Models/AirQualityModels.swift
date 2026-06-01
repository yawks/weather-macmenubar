import SwiftUI

// MARK: - Metric Types

enum AirMetricCategory {
    case pollution, pollen
}

enum AirMetric: String, Codable, CaseIterable, Hashable {
    case europeanAQI
    case pm25, pm10, no2, o3, so2
    case pollenGrasses, pollenBirch, pollenAlder, pollenOlive, pollenRagweed, pollenMugwort

    var displayName: String {
        switch self {
        case .europeanAQI:   return "IQA Européen"
        case .pm25:          return "PM₂.₅"
        case .pm10:          return "PM₁₀"
        case .no2:           return "NO₂"
        case .o3:            return "O₃"
        case .so2:           return "SO₂"
        case .pollenGrasses: return "Graminées"
        case .pollenBirch:   return "Bouleau"
        case .pollenAlder:   return "Aulne"
        case .pollenOlive:   return "Olivier"
        case .pollenRagweed: return "Ambroisies"
        case .pollenMugwort: return "Armoises"
        }
    }

    var unit: String {
        switch self {
        case .europeanAQI: return ""
        case .pollenGrasses, .pollenBirch, .pollenAlder,
             .pollenOlive, .pollenRagweed, .pollenMugwort: return "gr/m³"
        default: return "µg/m³"
        }
    }

    var category: AirMetricCategory {
        switch self {
        case .pollenGrasses, .pollenBirch, .pollenAlder,
             .pollenOlive, .pollenRagweed, .pollenMugwort: return .pollen
        default: return .pollution
        }
    }
}

// MARK: - Quality Index

enum AirQualityIndex: String, CaseIterable {
    case veryGood      = "Très bon"
    case good          = "Bon"
    case moderate      = "Moyen"
    case poor          = "Dégradé"
    case veryPoor      = "Mauvais"
    case extremelyPoor = "Très mauvais"

    var color: Color {
        switch self {
        case .veryGood:      return Color(red: 0.0, green: 0.75, blue: 0.35)
        case .good:          return .green
        case .moderate:      return .yellow
        case .poor:          return .orange
        case .veryPoor:      return .red
        case .extremelyPoor: return Color(red: 0.6, green: 0.0, blue: 0.3)
        }
    }

    // European AQI 0–100+
    static func from(europeanAQI v: Double) -> AirQualityIndex {
        switch v {
        case ..<20:  return .veryGood
        case ..<40:  return .good
        case ..<60:  return .moderate
        case ..<80:  return .poor
        case ..<100: return .veryPoor
        default:     return .extremelyPoor
        }
    }

    // French ATMO label strings ("Bon", "Moyen", "Dégradé", …)
    static func from(atmoLabel: String) -> AirQualityIndex? {
        switch atmoLabel.lowercased().trimmingCharacters(in: .whitespaces) {
        case "bon":                          return .good
        case "moyen":                        return .moderate
        case "dégradé", "degrade":           return .poor
        case "mauvais":                      return .veryPoor
        case "très mauvais", "tres mauvais": return .extremelyPoor
        default:                             return nil
        }
    }

    // Pollen grains/m³ — simplified universal scale
    static func fromPollen(_ v: Double) -> AirQualityIndex {
        switch v {
        case ..<5:   return .veryGood
        case ..<15:  return .good
        case ..<50:  return .moderate
        case ..<100: return .poor
        default:     return .veryPoor
        }
    }

    // Concentration-based index using European AQI breakpoints
    static func fromConcentration(_ v: Double, for metric: AirMetric) -> AirQualityIndex? {
        switch metric {
        case .no2:
            switch v {
            case ..<20:  return .veryGood
            case ..<40:  return .good
            case ..<90:  return .moderate
            case ..<120: return .poor
            case ..<230: return .veryPoor
            default:     return .extremelyPoor
            }
        case .o3:
            switch v {
            case ..<33:  return .veryGood
            case ..<65:  return .good
            case ..<120: return .moderate
            case ..<180: return .poor
            case ..<240: return .veryPoor
            default:     return .extremelyPoor
            }
        case .pm10:
            switch v {
            case ..<7:   return .veryGood
            case ..<15:  return .good
            case ..<30:  return .moderate
            case ..<55:  return .poor
            case ..<110: return .veryPoor
            default:     return .extremelyPoor
            }
        case .pm25:
            switch v {
            case ..<5:   return .veryGood
            case ..<10:  return .good
            case ..<20:  return .moderate
            case ..<25:  return .poor
            case ..<50:  return .veryPoor
            default:     return .extremelyPoor
            }
        case .so2:
            switch v {
            case ..<50:  return .veryGood
            case ..<100: return .good
            case ..<200: return .moderate
            case ..<350: return .poor
            case ..<500: return .veryPoor
            default:     return .extremelyPoor
            }
        default:
            return nil
        }
    }

    // Fraction 0–1 used for the pollen bar width
    var barFraction: Double {
        switch self {
        case .veryGood:      return 0.1
        case .good:          return 0.28
        case .moderate:      return 0.52
        case .poor:          return 0.75
        case .veryPoor:      return 0.9
        case .extremelyPoor: return 1.0
        }
    }
}

// MARK: - Reading

struct AirQualityReading: Identifiable {
    var id: String { "\(providerName)-\(metric.rawValue)" }
    let metric: AirMetric
    let value: Double?
    let index: AirQualityIndex?
    let providerName: String
}

// MARK: - Provider Configuration

enum AirProviderType: String, Codable, CaseIterable {
    case openMeteo = "Open-Meteo Air"
    case airparif  = "Airparif"

    var requiresApiKey: Bool    { self == .airparif }
    var requiresInseeCode: Bool { self == .airparif }

    var apiKeyHelpURL: String    { "https://www.airparif.fr/interface-de-programmation-applicative" }
    var inseeCodeHelpURL: String { "https://www.insee.fr/fr/recherche/recherche-geographique?debut=0" }

    var supportedMetrics: Set<AirMetric> {
        switch self {
        case .openMeteo:
            return [.europeanAQI, .pm25, .pm10, .no2, .o3, .so2,
                    .pollenGrasses, .pollenBirch, .pollenAlder,
                    .pollenOlive, .pollenRagweed, .pollenMugwort]
        case .airparif:
            return [.pm25, .pm10, .no2, .o3, .so2]
        }
    }

    var defaultEnabledMetrics: Set<AirMetric> {
        switch self {
        case .openMeteo:
            return [.europeanAQI, .pm25, .pm10, .no2, .o3,
                    .pollenGrasses, .pollenBirch, .pollenAlder,
                    .pollenOlive, .pollenRagweed, .pollenMugwort]
        case .airparif:
            return [.pm25, .pm10, .no2, .o3, .so2]
        }
    }
}

struct AirProviderConfig: Codable {
    var enabled: Bool
    var enabledMetrics: Set<AirMetric>
    var apiKey: String
    var inseeCode: String

    static func defaultConfig(for type: AirProviderType) -> AirProviderConfig {
        AirProviderConfig(
            enabled: type == .openMeteo,
            enabledMetrics: type.defaultEnabledMetrics,
            apiKey: "",
            inseeCode: ""
        )
    }
}
