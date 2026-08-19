import AppKit
import SwiftUI
import Combine

class StatusBarController {
    private var statusItem: NSStatusItem
    private var panel: PopoverPanel
    private var settings: AppSettings
    private var weatherManager: WeatherManager
    private var airQualityManager: AirQualityManager
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private let panelPresentation = PanelPresentationState()

    init(settings: AppSettings, weatherManager: WeatherManager, airQualityManager: AirQualityManager) {
        self.settings = settings
        self.weatherManager = weatherManager
        self.airQualityManager = airQualityManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let contentView = MainWeatherView(
            settings: settings,
            weatherManager: weatherManager,
            airQualityManager: airQualityManager,
            panelPresentation: panelPresentation
        )
        let hostingController = NSHostingController(rootView: contentView)

        self.panel = PopoverPanel(
            // Keep the AppKit hit-testing area in sync with MainWeatherView.
            // Content drawn outside this rect remains visible but cannot
            // receive mouse events.
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 680),
            contentViewController: hostingController
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: "Météo")
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        setupEventMonitor()
        setupBindings()
    }

    private func setupBindings() {
        Publishers.CombineLatest(weatherManager.$weather, weatherManager.$lastSyncFailed)
            .receive(on: RunLoop.main)
            .sink { [weak self] weather, syncFailed in
                guard let self = self else { return }
                if let weather = weather {
                    self.updateStatusItem(
                        temperature: weather.current.temperature,
                        iconName: WeatherIconMapper.symbol(for: weather.current.iconCode)
                    )
                } else if syncFailed {
                    self.updateStatusItem(temperature: nil, iconName: "exclamationmark.triangle.fill")
                }
            }
            .store(in: &cancellables)
    }

    @objc func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        panelPresentation.isVisible = true

        if let button = statusItem.button {
            let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
            let panelRect = panel.frame

            let x = buttonRect.origin.x + (buttonRect.width / 2) - (panelRect.width / 2)
            let y = buttonRect.origin.y - panelRect.height - 5

            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        panelPresentation.isVisible = false
        panel.orderOut(nil)
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }

            // A non-activating NSPanel can occasionally cause one of its own
            // clicks to reach the global monitor. Only dismiss when the mouse
            // is genuinely outside the panel's screen-space frame.
            if !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.hidePanel()
            }
        }
    }

    func updateStatusItem(temperature: Double?, iconName: String) {
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Météo")

        if let temp = temperature {
            button.title = "\(Int(temp))\(settings.unit.symbol)"
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }
}
