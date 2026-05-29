import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("unit") var unit: TemperatureUnit = .celsius
    @AppStorage("language") var language: String = "fr"
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
        if let data = UserDefaults.standard.data(forKey: "selectedLocation"),
           let location = try? JSONDecoder().decode(Location.self, from: data) {
            self.selectedLocation = location
        }
    }

    var isConfigured: Bool {
        !apiKey.isEmpty && selectedLocation != nil
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section(header: Text("Configuration API")) {
                TextField("Clé API OpenWeatherMap", text: $settings.apiKey)
                Text("Une clé API One Call 3.0 est requise.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
