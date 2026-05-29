import Foundation
import Combine

class WeatherManager: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let settings: AppSettings
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private var provider: WeatherProvider {
        switch settings.provider {
        case .openWeatherMap:
            return OpenWeatherMapProvider()
        case .meteoFrance:
            return MeteoFranceProvider()
        }
    }

    init(settings: AppSettings) {
        self.settings = settings

        // Refresh when settings change
        Publishers.CombineLatest(settings.$selectedLocation, settings.$provider)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // Auto refresh every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    func refresh() {
        guard let location = settings.selectedLocation, !settings.currentApiKey.isEmpty else {
            print("[WeatherManager] refresh() ignoré — clé API ou localisation manquante (apiKey=\(settings.currentApiKey.isEmpty ? "vide" : "ok"), location=\(settings.selectedLocation?.name ?? "nil"))")
            return
        }

        print("[WeatherManager] Chargement météo pour \(location.name)…")
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await provider.fetchWeather(
                    for: location,
                    units: settings.unit,
                    lang: settings.language,
                    apiKey: settings.currentApiKey
                )
                print("[WeatherManager] ✓ Météo reçue — \(data.current.conditionDescription), \(data.current.temperature)°")
                await MainActor.run {
                    self.weather = data
                    self.isLoading = false
                }
            } catch {
                print("[WeatherManager] ✗ Erreur : \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
