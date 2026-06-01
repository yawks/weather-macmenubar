import Foundation

protocol WeatherProvider {
    var name: String { get }
    func fetchWeather(for location: Location, units: TemperatureUnit, lang: String) async throws -> WeatherData
}

enum WeatherProviderError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "L'URL de l'API est invalide."
        case .networkError(let error): return "Erreur réseau : \(error.localizedDescription)"
        case .decodingError(let error): return "Erreur de décodage des données : \(error.localizedDescription)"
        case .apiError(let message): return "Erreur API : \(message)"
        }
    }
}
