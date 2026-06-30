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

    // Concentration-based index using French INQA breakpoints (arrêté du 10 juin 2021)
    // First level is "Bon" — there is no "Très bon" in the INQA scale.
    static func fromConcentration(_ v: Double, for metric: AirMetric) -> AirQualityIndex? {
        switch metric {
        case .no2:
            switch v {
            case ..<40:  return .good
            case ..<90:  return .moderate
            case ..<120: return .poor
            case ..<230: return .veryPoor
            case ..<340: return .extremelyPoor
            default:     return .extremelyPoor
            }
        case .o3:
            switch v {
            case ..<50:  return .good
            case ..<100: return .moderate
            case ..<130: return .poor
            case ..<240: return .veryPoor
            case ..<380: return .extremelyPoor
            default:     return .extremelyPoor
            }
        case .pm10:
            switch v {
            case ..<20:  return .good
            case ..<40:  return .moderate
            case ..<50:  return .poor
            case ..<100: return .veryPoor
            case ..<150: return .extremelyPoor
            default:     return .extremelyPoor
            }
        case .pm25:
            switch v {
            case ..<10:  return .good
            case ..<20:  return .moderate
            case ..<25:  return .poor
            case ..<50:  return .veryPoor
            case ..<75:  return .extremelyPoor
            default:     return .extremelyPoor
            }
        case .so2:
            switch v {
            case ..<100: return .good
            case ..<200: return .moderate
            case ..<350: return .poor
            case ..<500: return .veryPoor
            case ..<750: return .extremelyPoor
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

// MARK: - Metric info (for popovers)

extension AirMetric {
    var fullName: String {
        switch self {
        case .europeanAQI:   return "Indice de Qualité de l'Air Européen"
        case .pm25:          return "Particules fines (Ø < 2,5 µm)"
        case .pm10:          return "Particules inhalables (Ø < 10 µm)"
        case .no2:           return "Dioxyde d'azote"
        case .o3:            return "Ozone troposphérique"
        case .so2:           return "Dioxyde de soufre"
        case .pollenGrasses: return "Graminées — Poaceae"
        case .pollenBirch:   return "Bouleau — Betula"
        case .pollenAlder:   return "Aulne — Alnus"
        case .pollenOlive:   return "Olivier — Olea europaea"
        case .pollenRagweed: return "Ambroisies — Ambrosia"
        case .pollenMugwort: return "Armoises — Artemisia"
        }
    }

    var metricDescription: String {
        switch self {
        case .europeanAQI:
            return "Indice composite calculé à partir des principaux polluants atmosphériques. Reflète la qualité globale de l'air à un instant donné. Source : European Environment Agency (EEA)."
        case .no2:
            return "Gaz issu principalement du trafic routier et des combustions industrielles. Irritant pour les voies respiratoires supérieures, il aggrave les maladies cardiovasculaires et l'asthme."
        case .o3:
            return "Gaz formé par réaction photochimique (soleil + NOₓ + composés organiques volatils). Concentrations maximales en fin d'après-midi en été. Irritant pulmonaire, réduit la fonction respiratoire."
        case .pm10:
            return "Particules de diamètre inférieur à 10 µm issues de combustions (trafic, chauffage), poussières et procédés industriels. Se déposent dans les voies aériennes supérieures."
        case .pm25:
            return "Particules de diamètre inférieur à 2,5 µm. Pénètrent profondément dans les alvéoles pulmonaires et passent dans le sang. Effets cardiovasculaires et respiratoires à long terme."
        case .so2:
            return "Gaz issu de la combustion de carburants soufrés (fioul lourd, charbon) et de certains procédés industriels. Irritant des voies respiratoires, contribue aux pluies acides."
        case .pollenGrasses:
            return "Pollens de graminées (gazon, blé, seigle, fléole…). Principale cause de rhume des foins en Europe. Très allergisants. Saison : avril à juillet, pic en mai–juin."
        case .pollenBirch:
            return "Pollens de bouleau, arbre des zones tempérées. Très allergisant, avec réactions croisées fréquentes (pomme, noisette, carotte). Saison : mars à mai."
        case .pollenAlder:
            return "Pollens d'aulne, l'un des premiers arbres à fleurir. Réactions croisées possibles avec le bouleau. Saison : janvier à mars, selon la région."
        case .pollenOlive:
            return "Pollens d'olivier, très allergisant dans le bassin méditerranéen. Peut provoquer des réactions croisées avec les frênes. Saison : mai à juin."
        case .pollenRagweed:
            return "Pollens d'ambroisies, plante envahissante originaire d'Amérique du Nord. Extrêmement allergisante, même à faible concentration. Saison : août à octobre."
        case .pollenMugwort:
            return "Pollens d'armoises (Artemisia). Saison : juillet à septembre. Réactions croisées fréquentes avec les ambroisies et certains aliments (céleri, épices)."
        }
    }

    // (index level, range label) for display in the info popover
    var displayThresholds: [(AirQualityIndex, String)] {
        switch self {
        case .europeanAQI:
            return [
                (.veryGood,      "0 – 20"),
                (.good,          "20 – 40"),
                (.moderate,      "40 – 60"),
                (.poor,          "60 – 80"),
                (.veryPoor,      "80 – 100"),
                (.extremelyPoor, "> 100"),
            ]
        case .no2:
            return [
                (.good,          "< 40 µg/m³"),
                (.moderate,      "40 – 90 µg/m³"),
                (.poor,          "90 – 120 µg/m³"),
                (.veryPoor,      "120 – 230 µg/m³"),
                (.extremelyPoor, "> 230 µg/m³"),
            ]
        case .o3:
            return [
                (.good,          "< 50 µg/m³"),
                (.moderate,      "50 – 100 µg/m³"),
                (.poor,          "100 – 130 µg/m³"),
                (.veryPoor,      "130 – 240 µg/m³"),
                (.extremelyPoor, "> 240 µg/m³"),
            ]
        case .pm10:
            return [
                (.good,          "< 20 µg/m³"),
                (.moderate,      "20 – 40 µg/m³"),
                (.poor,          "40 – 50 µg/m³"),
                (.veryPoor,      "50 – 100 µg/m³"),
                (.extremelyPoor, "> 100 µg/m³"),
            ]
        case .pm25:
            return [
                (.good,          "< 10 µg/m³"),
                (.moderate,      "10 – 20 µg/m³"),
                (.poor,          "20 – 25 µg/m³"),
                (.veryPoor,      "25 – 50 µg/m³"),
                (.extremelyPoor, "> 50 µg/m³"),
            ]
        case .so2:
            return [
                (.good,          "< 100 µg/m³"),
                (.moderate,      "100 – 200 µg/m³"),
                (.poor,          "200 – 350 µg/m³"),
                (.veryPoor,      "350 – 500 µg/m³"),
                (.extremelyPoor, "> 500 µg/m³"),
            ]
        case .pollenGrasses, .pollenBirch, .pollenAlder,
             .pollenOlive, .pollenRagweed, .pollenMugwort:
            return [
                (.veryGood,      "< 5 gr/m³"),
                (.good,          "5 – 15 gr/m³"),
                (.moderate,      "15 – 50 gr/m³"),
                (.poor,          "50 – 100 gr/m³"),
                (.veryPoor,      "> 100 gr/m³"),
            ]
        }
    }

    var thresholdSource: String {
        switch self {
        case .europeanAQI:
            return "Source : European Environment Agency"
        case .pollenGrasses, .pollenBirch, .pollenAlder,
             .pollenOlive, .pollenRagweed, .pollenMugwort:
            return "Source : Open-Meteo / SILAM model"
        default:
            return "Référentiel : INQA (arrêté du 10 juin 2021)"
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
