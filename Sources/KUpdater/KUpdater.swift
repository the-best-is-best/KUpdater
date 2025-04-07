// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import UIKit

// MARK: - Enum Errors
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


// MARK: - Check Update Class
@objc public class KUpdater: NSObject {


    // MARK: - TestFlight variable
    @objc public var isTestFlight: Bool = false
    @objc public var authorizationTestFlight:String? = nil
    @objc public var countryCode:String? = nil


   @objc public var appStoreId:String? = nil

    static var forceUpdate:Bool = false

    // MARK: - Singleton
    @objc public static let shared = KUpdater()

    // MARK: - Check if Update is Available Function
    @objc public func isUpdateAvailable(completion: @escaping (Bool, Error?) -> Void) {
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


    // MARK: - Show Update Function
    @objc public func showUpdate(forceUpdate:Bool = false, title:String? = nil , message: String? = nil) {
        KUpdater.forceUpdate = forceUpdate
        DispatchQueue.global().async {
            self.checkVersion(force : KUpdater.forceUpdate, title: title , message: message)
        }
    }

    private func fetchAppStoreId(completion: @escaping (String?, Error?) -> Void) {
        guard let bundleIdentifier = self.getBundle(key: "CFBundleIdentifier"),
              let url = URL(string: "http://itunes.apple.com/lookup?bundleId=\(bundleIdentifier)") else {
            completion(nil, VersionError.invalidBundleInfo)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(nil, VersionError.invalidResponse)
                return
            }

            do {
                let result = try JSONDecoder().decode(LookupResult.self, from: data)
                if let appInfo = result.results?.first, let appId = appInfo.trackViewUrl.components(separatedBy: "/id").last?.components(separatedBy: "?").first {
                    completion(appId, nil)
                } else {
                    completion(nil, VersionError.dataError)
                }
            } catch {
                completion(nil, error)
            }
        }

        task.resume()
    }


    // MARK: - Function to check version
    private  func checkVersion(force: Bool , title:String? = nil , message:String? = nil) {
        if let currentVersion = self.getBundle(key: "CFBundleShortVersionString") {
            _ = getAppInfo { (data, info, error) in

                let store = self .isTestFlight ? "TestFlight" : "AppStore"

                if let error = error {
                    print("error getting app \(store) version: ", error)
                }

                if let appStoreAppVersion = info?.version { // Check app on AppStore
                    // Check if the installed app is the same that is on AppStore, if it is, print on console, but if it isn't it shows an alert.
                    if appStoreAppVersion <= currentVersion {
                        print("Already on the last app version: ", currentVersion)
                    } else {
                        print("Needs update: \(store) Version: \(appStoreAppVersion) > Current version: ", currentVersion)
                        DispatchQueue.main.async {
                            let topController: UIViewController = (UIApplication.shared.windows.first?.rootViewController)!
                            topController.showAppUpdateAlert(version: appStoreAppVersion, force: force, appURL: (info?.trackViewUrl)!, isTestFlight: self.isTestFlight, title: title , message: message)
                        }
                    }
                } else if let testFlightAppVersion = data?.attributes.version { // Check app on TestFlight
                // Check if the installed app is the same that is on TestFlight, if it is, print on console, but if it isn't it shows an alert.
                    if testFlightAppVersion <= currentVersion {
                        print("Already on the last app version: ",currentVersion)
                    } else {
                        print("Needs update: \(store) Version: \(testFlightAppVersion) > Current version: ", currentVersion)
                        DispatchQueue.main.async {
                            let topController: UIViewController = (UIApplication.shared.windows.first?.rootViewController)!
                            topController.showAppUpdateAlert(version: testFlightAppVersion, force: force, appURL: (info?.trackViewUrl)!, isTestFlight: self.isTestFlight)
                        }
                    }
                }  else { // App doesn't exist on store
                    print("App does not exist on \(store)")
                }
            }
        } else {
            print("Erro to decode app current version")
        }
    }

    private func getUrl(from identifier: String) -> String {
        let region = countryCode ?? Locale.current.regionCode ?? "us" // إذا لم يتم توفير رمز البلد، استخدم البلد الافتراضي
        let testflightURL = "https://api.appstoreconnect.apple.com/v1/apps/\(String(describing: KUpdater.shared.appStoreId))/builds"
    let appStoreURL = "http://itunes.apple.com/\(region)/lookup?bundleId=\(identifier)"

        return isTestFlight ? testflightURL : appStoreURL
    }

    private func getAppInfo(completion: @escaping (TestFlightInfo?, AppInfo?, Error?) -> Void) -> URLSessionDataTask? {

        guard let identifier = self.getBundle(key: "CFBundleIdentifier"),
              let url = URL(string: getUrl(from: identifier)) else {
                DispatchQueue.main.async {
                    completion(nil, nil, VersionError.invalidBundleInfo)
                }
                return nil
        }

        // You need to generate an authorizationTestFlight token to access the TestFlight versions and then you replace the ```***``` with the JWT token.
        // Você precisa gerar um token de autorização para acessar as versões de TestFlight e depois você substitui o ```***``` com o token JWT gerado.
        // https://developer.apple.com/documentation/appstoreconnectapi/generating_tokens_for_api_requests


        var request = URLRequest(url: url)

        // You just need to add an authorization header if you are checking TestFlight version
        // Você só precisa adicionar uma autorização no header se você está checando a versão de testflight
        if self.isTestFlight {
            request.setValue(authorizationTestFlight, forHTTPHeaderField: "Authorization")
        }

        // Make request
        // Fazer a requisição
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in

                do {
                    if let error = error {
                        print(error)
                        throw error
                    }
                    guard let data = data else { throw VersionError.invalidResponse }

                    let result = try JSONDecoder().decode(LookupResult.self, from: data)
                    print(result)

                    if self.isTestFlight {
                        let info = result.data?.first
                        completion(info, nil, nil)
                    } else {
                        let info = result.results?.first
                        completion(nil, info, nil)
                    }

                } catch {
                    completion(nil, nil, error)
                }
            }

        task.resume()
        return task

    }

    func getBundle(key: String) -> String? {

        guard let filePath = Bundle.main.path(forResource: "Info", ofType: "plist") else {
          fatalError("Couldn't find file 'Info.plist'.")
        }
        // Add the file to a dictionary
        let plist = NSDictionary(contentsOfFile: filePath)
        // Check if the variable on plist exists
        guard let value = plist?.object(forKey: key) as? String else {
          fatalError("Couldn't find key '\(key)' in 'Info.plist'.")
        }
        return value
    }
}

// MARK: - Show Alert
extension UIViewController {
    @objc fileprivate func showAppUpdateAlert(version: String, force: Bool, appURL: String, isTestFlight: Bool , title:String? = nil , message:String?  = nil) {
      //  guard let appName = KUpdater.shared.getBundle(key: "CFBundleName") else { return }

        let alertTitle:String
        if(title != nil) {
            alertTitle = title!
        } else {
            alertTitle = "Update Available"
        }
        let alertMessage: String
        if(message == nil){
            if KUpdater.forceUpdate {
                alertMessage = "A new update is required to continue using this app."
            } else {
                alertMessage = "A new update is available. Would you like to update now?"
            }
        } else{
            alertMessage = message!
        }
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)

        if !force {
            let notNowButton = UIAlertAction(title: "Not now", style: .default)
            alertController.addAction(notNowButton)
        }

        let updateButton = UIAlertAction(title: "Update", style: .default) { _ in
            guard let url = URL(string: appURL) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)

//            // Only call showUpdate again if forceUpdate is true
            if KUpdater.forceUpdate {
                KUpdater.shared.showUpdate(forceUpdate: true)
            }
        }

        alertController.addAction(updateButton)
            self.present(alertController, animated: true, completion: nil)

    }
}
