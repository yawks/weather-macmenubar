import SwiftUI

enum WeatherProviderType: String, Codable, CaseIterable {
    case openWeatherMap = "OpenWeatherMap"
    case meteoFrance = "Météo France"
}

class AppSettings: ObservableObject {
    @Published var provider: WeatherProviderType {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "provider") }
    }
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }
    @Published var meteoFranceKey: String {
        didSet { UserDefaults.standard.set(meteoFranceKey, forKey: "meteoFranceKey") }
    }
    @Published var unit: TemperatureUnit {
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: "unit") }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }

    @Published var selectedLocation: Location? {
        didSet {
            if let location = selectedLocation {
                if let encoded = try? JSONEncoder().encode(location) {
                    UserDefaults.standard.set(encoded, forKey: "selectedLocation")
                }
            }
        }
    }

    init() {
        self.provider = WeatherProviderType(rawValue: UserDefaults.standard.string(forKey: "provider") ?? "") ?? .openWeatherMap
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.meteoFranceKey = UserDefaults.standard.string(forKey: "meteoFranceKey") ?? ""
        self.unit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: "unit") ?? "") ?? .celsius
        self.language = UserDefaults.standard.string(forKey: "language") ?? "fr"

        if let data = UserDefaults.standard.data(forKey: "selectedLocation"),
           let location = try? JSONDecoder().decode(Location.self, from: data) {
            self.selectedLocation = location
        }
    }

    var isConfigured: Bool {
        let key = provider == .openWeatherMap ? apiKey : meteoFranceKey
        return !key.isEmpty && selectedLocation != nil
    }

    var currentApiKey: String {
        provider == .openWeatherMap ? apiKey : meteoFranceKey
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section(header: Text("Fournisseur de données")) {
                Picker("Source", selection: $settings.provider) {
                    ForEach(WeatherProviderType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            Section(header: Text("Configuration API")) {
                if settings.provider == .openWeatherMap {
                    TextField("Clé API OpenWeatherMap", text: $settings.apiKey)
                    Text("Une clé API One Call 3.0 est requise.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    SecureField("Clé API Météo France (apikey)", text: $settings.meteoFranceKey)
                    Text("Créez un compte sur portail-api.meteofrance.fr, souscrivez à 'V1 - Prévisions' et récupérez votre apikey.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

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

            Button("Terminer") {
                dismiss()
            }
            .disabled(!settings.isConfigured)
            .frame(maxWidth: .infinity)
            .padding(.top)
        }
        .padding()
        .frame(width: 400)
    }
}
