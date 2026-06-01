import SwiftUI

enum WeatherProviderType: String, Codable, CaseIterable {
    case openWeatherMap = "OpenWeatherMap"
    case openMeteo = "Open-Meteo"
}

class AppSettings: ObservableObject {
    @Published var provider: WeatherProviderType {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "provider") }
    }
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }
    @Published var unit: TemperatureUnit {
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: "unit") }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    @Published var selectedLocation: Location? {
        didSet {
            if let location = selectedLocation,
               let encoded = try? JSONEncoder().encode(location) {
                UserDefaults.standard.set(encoded, forKey: "selectedLocation")
            }
        }
    }
    @Published var airProviderConfigs: [String: AirProviderConfig] {
        didSet {
            if let encoded = try? JSONEncoder().encode(airProviderConfigs) {
                UserDefaults.standard.set(encoded, forKey: "airProviderConfigs")
            }
        }
    }

    init() {
        self.provider = WeatherProviderType(rawValue: UserDefaults.standard.string(forKey: "provider") ?? "") ?? .openWeatherMap
        self.apiKey   = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.unit     = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: "unit") ?? "") ?? .celsius
        self.language = UserDefaults.standard.string(forKey: "language") ?? "fr"

        if let data = UserDefaults.standard.data(forKey: "selectedLocation"),
           let location = try? JSONDecoder().decode(Location.self, from: data) {
            self.selectedLocation = location
        }

        if let data = UserDefaults.standard.data(forKey: "airProviderConfigs"),
           let configs = try? JSONDecoder().decode([String: AirProviderConfig].self, from: data) {
            self.airProviderConfigs = configs
        } else {
            self.airProviderConfigs = Dictionary(
                uniqueKeysWithValues: AirProviderType.allCases.map {
                    ($0.rawValue, AirProviderConfig.defaultConfig(for: $0))
                }
            )
        }
    }

    var isConfigured: Bool {
        switch provider {
        case .openWeatherMap: return !apiKey.isEmpty && selectedLocation != nil
        case .openMeteo:      return selectedLocation != nil
        }
    }

    var currentApiKey: String {
        provider == .openWeatherMap ? apiKey : ""
    }

    func airConfig(for type: AirProviderType) -> AirProviderConfig {
        airProviderConfigs[type.rawValue] ?? AirProviderConfig.defaultConfig(for: type)
    }

    func setAirConfig(_ config: AirProviderConfig, for type: AirProviderType) {
        airProviderConfigs[type.rawValue] = config
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            // MARK: Weather provider
            Section(header: Text("Fournisseur météo")) {
                Picker("Source", selection: $settings.provider) {
                    ForEach(WeatherProviderType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            if settings.provider == .openWeatherMap {
                Section(header: Text("Configuration API météo")) {
                    TextField("Clé API OpenWeatherMap", text: $settings.apiKey)
                    Text("Une clé API One Call 3.0 est requise.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: Location
            Section(header: Text("Localisation")) {
                TextField("Rechercher une ville...", text: $locationService.searchQuery)

                if !locationService.completions.isEmpty {
                    List(locationService.completions, id: \.self) { completion in
                        Button(action: {
                            Task {
                                if let location = try? await locationService.geocode(completion: completion) {
                                    settings.selectedLocation = location
                                    locationService.searchQuery = location.name
                                    locationService.completions = []
                                }
                            }
                        }) {
                            VStack(alignment: .leading) {
                                Text(completion.title)
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 150)
                } else if let location = settings.selectedLocation {
                    Text("Ville actuelle : \(location.name)")
                        .foregroundColor(.green)
                }
            }

            // MARK: Preferences
            Section(header: Text("Préférences")) {
                Picker("Unités", selection: $settings.unit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        Text(unit == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)").tag(unit)
                    }
                }
                Picker("Langue", selection: $settings.language) {
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                }
            }

            // MARK: Air Quality
            Section(header: Text("Qualité de l'air")) {
                ForEach(AirProviderType.allCases, id: \.self) { type in
                    AirProviderSection(
                        type: type,
                        config: airConfigBinding(for: type)
                    )
                }
            }

            Button("Terminer") { dismiss() }
                .disabled(!settings.isConfigured)
                .frame(maxWidth: .infinity)
                .padding(.top)
        }
        .padding()
        .frame(width: 420)
    }

    private func airConfigBinding(for type: AirProviderType) -> Binding<AirProviderConfig> {
        Binding(
            get: { self.settings.airConfig(for: type) },
            set: { self.settings.setAirConfig($0, for: type) }
        )
    }
}

// MARK: - Air provider section

private struct AirProviderSection: View {
    let type: AirProviderType
    @Binding var config: AirProviderConfig

    @State private var showMetrics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: name + toggle
            HStack {
                Text(type.rawValue)
                    .fontWeight(.medium)
                if type == .openMeteo {
                    Text("gratuit")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                Spacer()
                Toggle("", isOn: $config.enabled)
                    .labelsHidden()
            }

            if config.enabled {
                // Credentials
                if type.requiresApiKey {
                    HStack {
                        SecureField("Clé API", text: $config.apiKey)
                            .textFieldStyle(.roundedBorder)
                        Link("Obtenir", destination: URL(string: type.apiKeyHelpURL)!)
                            .font(.caption)
                    }
                }
                if type.requiresInseeCode {
                    HStack {
                        TextField("Code INSEE (ex: 75056)", text: $config.inseeCode)
                            .textFieldStyle(.roundedBorder)
                        Link("Trouver", destination: URL(string: type.inseeCodeHelpURL)!)
                            .font(.caption)
                    }
                    Text("Code de la commune (5 chiffres) — Île-de-France uniquement.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Metrics picker
                DisclosureGroup(
                    isExpanded: $showMetrics,
                    content: {
                        MetricsGrid(type: type, config: $config)
                            .padding(.top, 4)
                    },
                    label: {
                        Text("Métriques affichées (\(config.enabledMetrics.count)/\(type.supportedMetrics.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metrics grid

private struct MetricsGrid: View {
    let type: AirProviderType
    @Binding var config: AirProviderConfig

    private var pollutionMetrics: [AirMetric] {
        type.supportedMetrics.filter { $0.category == .pollution }.sorted { $0.rawValue < $1.rawValue }
    }
    private var pollenMetrics: [AirMetric] {
        type.supportedMetrics.filter { $0.category == .pollen }.sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !pollutionMetrics.isEmpty {
                Text("Polluants").font(.caption2).foregroundColor(.secondary)
                FlowLayout(metrics: pollutionMetrics, config: $config)
            }
            if !pollenMetrics.isEmpty {
                Text("Pollens").font(.caption2).foregroundColor(.secondary).padding(.top, 2)
                FlowLayout(metrics: pollenMetrics, config: $config)
            }
        }
    }
}

// MARK: - Flow layout for metric toggles

private struct FlowLayout: View {
    let metrics: [AirMetric]
    @Binding var config: AirProviderConfig

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 6) {
            ForEach(metrics, id: \.self) { metric in
                Toggle(metric.displayName, isOn: metricBinding(metric))
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
        }
    }

    private func metricBinding(_ metric: AirMetric) -> Binding<Bool> {
        Binding(
            get: { config.enabledMetrics.contains(metric) },
            set: { enabled in
                if enabled {
                    config.enabledMetrics.insert(metric)
                } else {
                    config.enabledMetrics.remove(metric)
                }
            }
        )
    }
}
