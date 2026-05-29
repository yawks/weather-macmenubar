import Foundation
import Combine

class WeatherManager: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let settings: AppSettings
    private let provider: WeatherProvider
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings, provider: WeatherProvider = OpenWeatherMapProvider()) {
        self.settings = settings
        self.provider = provider

        // Refresh when settings change
        settings.$selectedLocation
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // Auto refresh every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    func refresh() {
        guard let location = settings.selectedLocation, !settings.apiKey.isEmpty else {
            print("[WeatherManager] refresh() ignoré — clé API ou localisation manquante (apiKey=\(settings.apiKey.isEmpty ? "vide" : "ok"), location=\(settings.selectedLocation?.name ?? "nil"))")
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
                    apiKey: settings.apiKey
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
