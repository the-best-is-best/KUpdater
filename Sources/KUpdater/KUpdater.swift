import Foundation
import UIKit

// MARK: - Errors
enum VersionError: Error {
    case invalidBundleInfo, invalidResponse, dataError
}

// MARK: - Models
struct LookupResult: Decodable {
    let data: [TestFlightInfo]?
    let results: [AppInfo]?
}

struct TestFlightInfo: Decodable {
    let type: String
    let attributes: Attributes
}

struct Attributes: Decodable {
    let version: String
    let expired: String
}

struct AppInfo: Decodable {
    let version: String
    let trackViewUrl: String
    let trackId: Int
}

// MARK: - KUpdater
@MainActor
@objc public class KUpdater: NSObject {
    
    @objc public static let shared = KUpdater()
    
    // Persistent values to survive app background/foreground loops
    private var persistentTitle: String?
    private var persistentMessage: String?
    private var isForced: Bool = false
    
    @objc public var isTestFlight: Bool = false
    @objc public var authorizationTestFlight: String? = nil
    @objc public var countryCode: String? = nil
    @objc public var appStoreId: String? = nil
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func handleAppDidBecomeActive() {
        if isForced {
            showUpdate(forceUpdate: true, title: persistentTitle, message: persistentMessage)
        }
    }

    // MARK: - Public Methods
    
    /// Checks version and presents a UI Alert automatically if an update is found.
    @objc public func showUpdate(forceUpdate: Bool = false, title: String? = nil, message: String? = nil) {
        self.isForced = forceUpdate
        
        // Update persistent values only if new ones are provided
        if let title = title { self.persistentTitle = title }
        if let message = message { self.persistentMessage = message }
        
        checkVersion(force: forceUpdate, title: self.persistentTitle, message: self.persistentMessage)
    }

    /// Checks version and returns a boolean via completion handler. No UI is shown.
    @objc public func isUpdateAvailable(completion: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        guard let currentVersion = self.getBundleValue(key: "CFBundleShortVersionString") else {
            completion(false, VersionError.invalidBundleInfo)
            return
        }
        
        let isTF = self.isTestFlight
        
        _ = getAppInfo { [weak self] (tfData, storeInfo, error) in
            guard let self = self else { return }
            if let error = error {
                completion(false, error)
                return
            }

            Task { @MainActor in
                let storeVersion = isTF ? tfData?.attributes.version : storeInfo?.version
                
                if let versionToCompare = storeVersion, self.compareVersions(current: currentVersion, store: versionToCompare) {
                    completion(true, nil)
                } else {
                    completion(false, nil)
                }
            }
        }
    }

    // MARK: - Internal Logic
    
    nonisolated private func compareVersions(current: String, store: String) -> Bool {
        return store.compare(current, options: .numeric) == .orderedDescending
    }

    private func checkVersion(force: Bool, title: String? = nil, message: String? = nil) {
        guard let currentVersion = getBundleValue(key: "CFBundleShortVersionString") else { return }
        let isTF = self.isTestFlight
        
        _ = getAppInfo { [weak self] tfInfo, storeInfo, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    print("KUpdater Error: \(error)")
                    return
                }

                if isTF, let tfVersion = tfInfo?.attributes.version {
                    if self.compareVersions(current: currentVersion, store: tfVersion) {
                        self.showAlert(version: tfVersion, force: force, url: nil, title: title, message: message)
                    }
                } else if let storeInfo = storeInfo {
                    self.appStoreId = String(storeInfo.trackId)
                    
                    if self.compareVersions(current: currentVersion, store: storeInfo.version) {
                        self.showAlert(version: storeInfo.version, force: force, url: storeInfo.trackViewUrl, title: title, message: message)
                    }
                }
            }
        }
    }

    private func showAlert(version: String, force: Bool, url: String?, title: String?, message: String?) {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard let topVC = keyWindow?.rootViewController else { return }
        
        // Prevent stacking alerts
        if topVC.presentedViewController is UIAlertController {
            topVC.dismiss(animated: false, completion: nil)
        }
        
        let finalUrl = url ?? "https://beta.itunes.apple.com/v1/app/\(appStoreId ?? "")"
        let alertTitle = title ?? "Update Available"
        let alertMessage = message ?? (force ? "A new update is required to continue." : "A new version (\(version)) is available.")
        
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            if let urlObj = URL(string: finalUrl) {
                UIApplication.shared.open(urlObj)
            }
            if force {
                Task { @MainActor in
                    self.showUpdate(forceUpdate: true, title: title, message: message)
                }
            }
        })
        
        if !force {
            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        }
        
        topVC.present(alert, animated: true)
    }

    // MARK: - Helpers
    private func getBundleValue(key: String) -> String? {
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
    
    private func getRequestUrl(identifier: String) -> String {
        if isTestFlight {
            return "https://api.appstoreconnect.apple.com/v1/apps/\(appStoreId ?? "")/builds"
        } else {
            let region = countryCode ?? Locale.current.regionCode ?? "us"
            return "https://itunes.apple.com/\(region)/lookup?bundleId=\(identifier)"
        }
    }
    
    private func getAppInfo(completion: @escaping @Sendable (TestFlightInfo?, AppInfo?, (any Error)?) -> Void) -> URLSessionDataTask? {
        guard let identifier = self.getBundleValue(key: "CFBundleIdentifier"),
              let url = URL(string: getRequestUrl(identifier: identifier)) else {
            Task { completion(nil, nil, VersionError.invalidBundleInfo) }
            return nil
        }
        
        var request = URLRequest(url: url)
        if self.isTestFlight {
            request.setValue(authorizationTestFlight, forHTTPHeaderField: "Authorization")
        }
        
        let isTF = self.isTestFlight
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            do {
                if let error = error { throw error }
                guard let data = data else { throw VersionError.invalidResponse }
                let result = try JSONDecoder().decode(LookupResult.self, from: data)
                
                if isTF {
                    completion(result.data?.first, nil, nil)
                } else {
                    completion(nil, result.results?.first, nil)
                }
            } catch {
                completion(nil, nil, error)
            }
        }
        task.resume()
        return task
    }
}
