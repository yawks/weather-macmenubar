import SwiftUI

@main
struct WeatherBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var settings = AppSettings()
    lazy var weatherManager = WeatherManager(settings: settings)
    lazy var airQualityManager = AirQualityManager(settings: settings)
    var statusBarController: StatusBarController?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            settings: settings,
            weatherManager: weatherManager,
            airQualityManager: airQualityManager
        )

        // Show settings if not configured
        if !settings.isConfigured {
            openSettings()
        }
    }

    @objc func openSettings() {
        statusBarController?.hidePanel()

        if settingsWindow == nil {
            let contentView = SettingsView(settings: settings)
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Réglages WeatherBar"
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
