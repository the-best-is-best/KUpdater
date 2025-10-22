import Foundation

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
}

// MARK: - KUpdater
@MainActor
@objc public class KUpdater: NSObject {
    
    @objc public var isTestFlight: Bool = false
    @objc public var authorizationTestFlight: String? = nil
    @objc public var countryCode: String? = nil
    @objc public var appStoreId: String? = nil
    
    @objc public static let shared = KUpdater()
    
    // MARK: - Show update
    // The forceUpdate flag is now passed directly as a parameter.
    @objc public func showUpdate(forceUpdate: Bool = false, title: String? = nil, message: String? = nil) {
        // The checkVersion method is already on the MainActor, so we can call it directly.
        checkVersion(force: forceUpdate, title: title, message: message)
    }
    
    @objc
    public func isUpdateAvailable(completion: @escaping @Sendable (Bool, Error?) -> Void) {
        if let currentVersion = self.getBundle(key: "CFBundleShortVersionString") {
            _ = getAppInfo { (data, info, error) in
                if let error = error {
                    completion(false, error)
                    return
                }

                // Check App Store version if it's not in TestFlight
                if let appStoreAppVersion = info?.version, appStoreAppVersion > currentVersion {
                    completion(true, nil)
                }
                // Check TestFlight version if in TestFlight
                else if let testFlightAppVersion = data?.attributes.version, testFlightAppVersion > currentVersion {
                    completion(true, nil)
                }
                else {
                    completion(false, nil)
                }
            }
        } else {
            completion(false, VersionError.invalidBundleInfo)
        }
    }
    // MARK: - Check version
    private func checkVersion(force: Bool, title: String? = nil, message: String? = nil) {
        guard let currentVersion = getBundle(key: "CFBundleShortVersionString") else {
            print("Error decoding current version")
            return
        }
        
        // Capture the value of isTestFlight before the Sendable closure.
        let isTestFlight = self.isTestFlight
        
        // Pass the force flag to the closure to be used later
        _ = getAppInfo { [weak self] testFlightInfo, appStoreInfo, error in
            guard let self = self else { return }
            
            // Use the local isTestFlight variable instead of self.isTestFlight
            let store = isTestFlight ? "TestFlight" : "AppStore"
            
            if let error = error {
                print("Error getting app \(store) version:", error)
                return
            }
            
            // The calls to handleVersionCheck must be on the MainActor.
            Task { @MainActor in
                if let appStoreVersion = appStoreInfo?.version, !isTestFlight {
                    self.handleVersionCheck(storeVersion: appStoreVersion, currentVersion: currentVersion, force: force, url: appStoreInfo?.trackViewUrl, title: title, message: message)
                } else if let testFlightVersion = testFlightInfo?.attributes.version, isTestFlight {
                    self.handleVersionCheck(storeVersion: testFlightVersion, currentVersion: currentVersion, force: force, url: appStoreInfo?.trackViewUrl, title: title, message: message)
                } else {
                    print("App does not exist on \(store)")
                }
            }
        }
    }
    
    // This method is now also on the MainActor.
    private func handleVersionCheck(storeVersion: String, currentVersion: String, force: Bool, url: String?, title: String?, message: String?) {
        handleVersionCheckFile(storeVersion: storeVersion, currentVersion: currentVersion, force: force, url: url, title: title, message: message)
    }
    
    // MARK: - Helper
    func getBundle(key: String) -> String? {
        // This is safe to keep as a synchronous function.
        guard let filePath = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let value = plist.object(forKey: key) as? String else {
            return nil
        }
        return value
    }
    
    @MainActor private func getUrl(from identifier: String) -> String {
        let region = countryCode ?? Locale.current.regionCode ?? "us"
        let testflightURL = "https://api.appstoreconnect.apple.com/v1/apps/\(appStoreId ?? "")/builds"
        let appStoreURL = "http://itunes.apple.com/\(region)/lookup?bundleId=\(identifier)"
        return isTestFlight ? testflightURL : appStoreURL
    }
    
    
    @MainActor
    private func getAppInfo(completion: @escaping @Sendable (TestFlightInfo?, AppInfo?, (any Error)?) -> Void) -> URLSessionDataTask? {
        
        guard let identifier = self.getBundle(key: "CFBundleIdentifier"),
              let url = URL(string: getUrl(from: identifier)) else {
            // Correctly using Task to ensure the completion is called on the MainActor.
            Task {
                completion(nil, nil, VersionError.invalidBundleInfo)
            }
            return nil
        }
        
        var request = URLRequest(url: url)
        if self.isTestFlight {
            request.setValue(authorizationTestFlight, forHTTPHeaderField: "Authorization")
        }
        
        // Capture the value of isTestFlight before the Sendable closure is created.
        let isTestFlight = self.isTestFlight
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                do {
                    if let error = error { throw error }
                    guard let data = data else { throw VersionError.invalidResponse }
                    
                    let result = try JSONDecoder().decode(LookupResult.self, from: data)
                    
                    if isTestFlight {
                        completion(result.data?.first, nil, nil)
                    } else {
                        completion(nil, result.results?.first, nil)
                    }
                    
                } catch {
                    completion(nil, nil, error)
                }
            }
        }
        
        task.resume()
        return task
    }
}
