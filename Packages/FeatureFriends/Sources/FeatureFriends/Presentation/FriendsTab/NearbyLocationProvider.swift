import CoreLocation
import Foundation

@MainActor
final class NearbyLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationDenied = false
    var onAuthorizationChange: (() -> Void)?

    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var hasAuthorization: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func currentCoordinate() async -> CLLocationCoordinate2D? {
        guard CLLocationManager.locationServicesEnabled() else {
            coordinate = nil
            return nil
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return nil
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            authorizationDenied = true
            return nil
        }
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
            if continuations.count == 1 {
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
        case .denied, .restricted:
            authorizationDenied = true
        default:
            break
        }
        onAuthorizationChange?()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard CLLocationManager.locationServicesEnabled() else {
            finishRequest(nil)
            return
        }
        coordinate = locations.last?.coordinate
        finishRequest(coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finishRequest(nil)
    }

    private func finishRequest(_ value: CLLocationCoordinate2D?) {
        let waiting = continuations
        continuations = []
        waiting.forEach { $0.resume(returning: value) }
    }
}
