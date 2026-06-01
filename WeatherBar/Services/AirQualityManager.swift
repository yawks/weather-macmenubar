import Foundation
import Combine

class AirQualityManager: ObservableObject {
    @Published var readings: [AirQualityReading] = []
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    @Published var lastSyncFailed = false

    private let settings: AppSettings
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings

        Publishers.CombineLatest(settings.$selectedLocation, settings.$airProviderConfigs)
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
            .store(in: &cancellables)

        // Air quality updates every 30 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    func refresh() {
        guard let location = settings.selectedLocation else { return }

        let providers = activeProviders
        guard !providers.isEmpty else {
            readings = []
            return
        }

        print("[AirQualityManager] Chargement qualité de l'air pour \(location.name)…")
        isLoading = true

        Task {
            var allReadings: [AirQualityReading] = []
            for provider in providers {
                do {
                    let r = try await provider.fetchAirQuality(for: location)
                    allReadings.append(contentsOf: r)
                    print("[AirQualityManager] ✓ \(provider.name) — \(r.count) lecture(s)")
                } catch {
                    print("[AirQualityManager] ✗ \(provider.name) : \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                self.readings = allReadings
                self.isLoading = false
                self.lastSyncDate = Date()
                self.lastSyncFailed = allReadings.isEmpty
            }
        }
    }

    // MARK: - Private

    private var activeProviders: [any AirQualityProvider] {
        AirProviderType.allCases.compactMap { type in
            let config = settings.airConfig(for: type)
            guard config.enabled else { return nil }
            switch type {
            case .openMeteo:
                return OpenMeteoAirProvider(enabledMetrics: config.enabledMetrics)
            case .airparif:
                guard !config.apiKey.isEmpty, !config.inseeCode.isEmpty else { return nil }
                return AirparifProvider(
                    apiKey: config.apiKey,
                    inseeCode: config.inseeCode,
                    enabledMetrics: config.enabledMetrics
                )
            }
        }
    }
}
