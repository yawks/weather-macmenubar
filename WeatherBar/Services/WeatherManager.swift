import Foundation
import Combine

class WeatherManager: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    @Published var lastSyncFailed = false

    private let settings: AppSettings
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private var provider: WeatherProvider {
        switch settings.provider {
        case .openWeatherMap: return OpenWeatherMapProvider(apiKey: settings.currentApiKey)
        case .openMeteo:      return OpenMeteoProvider()
        }
    }

    init(settings: AppSettings) {
        self.settings = settings

        // Refresh when settings change.
        // dropFirst() skips the immediate emission so the explicit refresh() below handles startup.
        // DispatchQueue.main.async defers execution past @Published's willSet, ensuring
        // settings.provider is already updated when refresh() reads it.
        Publishers.CombineLatest(settings.$selectedLocation, settings.$provider)
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
            .store(in: &cancellables)

        // Auto refresh every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    func refresh() {
        guard settings.isConfigured, let location = settings.selectedLocation else {
            print("[WeatherManager] refresh() ignoré — configuration incomplète (location=\(settings.selectedLocation?.name ?? "nil"))")
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
                    lang: settings.language
                )
                print("[WeatherManager] ✓ Météo reçue — \(data.current.conditionDescription), \(data.current.temperature)°")
                await MainActor.run {
                    self.weather = data
                    self.isLoading = false
                    self.lastSyncDate = Date()
                    self.lastSyncFailed = false
                }
            } catch {
                print("[WeatherManager] ✗ Erreur : \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.lastSyncDate = Date()
                    self.lastSyncFailed = true
                }
            }
        }
    }
}
