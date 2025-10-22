//
//  handleVersionCheckFile.swift
//  KUpdater
//
//  Created by Michelle Raouf on 23/10/2025.
//
#if canImport(UIKit)

import UIKit
import Foundation


@MainActor
func handleVersionCheckFile(
    storeVersion: String,
    currentVersion: String,
    force: Bool,
    url: String?,
    title: String?,
    message: String?
) {
    if storeVersion <= currentVersion {
        print("Already on the last version:", currentVersion)
    } else {
        print("Needs update: Version \(storeVersion) > Current version \(currentVersion)")
        guard let topVC = UIApplication.shared.windows.first?.rootViewController else { return }
        topVC.showAppUpdateAlert(
            version: storeVersion,
            force: force,
            appURL: url ?? "",
            isTestFlight: KUpdater.shared.isTestFlight,
            title: title,
            message: message
        )
    }
}



extension UIViewController {
    @objc fileprivate func showAppUpdateAlert(version: String, force: Bool, appURL: String, isTestFlight: Bool, title: String? = nil, message: String? = nil) {
        // The showAppUpdateAlert is now on the MainActor
        // The forceUpdate state is now passed as a parameter
        let alertTitle = title ?? "Update Available"
        let alertMessage = message ?? (force ? "A new update is required to continue using this app." : "A new update is available. Would you like to update now?")
        
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        if !force {
            alertController.addAction(UIAlertAction(title: "Not now", style: .default))
        }
        alertController.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            guard let url = URL(string: appURL) else { return }
            UIApplication.shared.open(url, options: [:])
            if force {
                KUpdater.shared.showUpdate(forceUpdate: true)
            }
        })
        self.present(alertController, animated: true)
    }
}
#endif
