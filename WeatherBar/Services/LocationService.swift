import Foundation
import MapKit
import Combine

class LocationService: NSObject, ObservableObject {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []

    private var searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address

        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.searchCompleter.queryFragment = query
            }
            .store(in: &cancellables)
    }

    func geocode(completion: MKLocalSearchCompletion) async throws -> Location? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let item = response.mapItems.first else { return nil }

        return Location(
            name: item.name ?? completion.title,
            coordinate: Coordinate(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
        )
    }
}

extension LocationService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error.localizedDescription)")
    }
}
