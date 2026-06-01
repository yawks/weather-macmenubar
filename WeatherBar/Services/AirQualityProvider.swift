import Foundation

protocol AirQualityProvider {
    var name: String { get }
    var supportedMetrics: Set<AirMetric> { get }
    func fetchAirQuality(for location: Location) async throws -> [AirQualityReading]
}

enum AirQualityProviderError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case missingConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:                  return "URL invalide."
        case .networkError(let e):         return "Erreur réseau : \(e.localizedDescription)"
        case .decodingError(let e):        return "Erreur de décodage : \(e.localizedDescription)"
        case .apiError(let m):             return "Erreur API : \(m)"
        case .missingConfiguration(let f): return "Configuration manquante : \(f)"
        }
    }
}
