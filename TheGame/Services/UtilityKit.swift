//
//  Utility.swift
//  TheGame
//
//  Created by Alek Sai on 18.09.2022.
//

import Foundation
//import Amplitude
import WidgetKit

#if os(iOS)
import UIKit
//import ProgressHUD
#endif

let utilityVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"]!
let utilityBuild = Bundle.main.infoDictionary!["CFBundleVersion"]!

class U {
    
    static func log(event: String, _ message: Any...) {
        let message = message.map({ String(reflecting: $0) }).joined(separator: " ")
        
        let time = Date().timeIntervalSince1970
        
        print(event, time, "\(utilityVersion)(\(utilityBuild))", message)
//        Amplitude.instance().logEvent(event, withEventProperties: ["message": "\(utilityVersion)(\(utilityBuild)) \(time) \(message)"])
    }
    
    static func reloadWidgets() {
        #if os(watchOS)
        if #available(watchOS 9.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #else
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
    
    #if os(iOS)
    static func present(_ controller: UIViewController?) {
        if let controller {
            DispatchQueue.main.async {
                UIApplication.shared.windows.filter({ $0.isKeyWindow }).first?.rootViewController?.present(controller, animated: true)
            }
        }
    }
    
    static func alert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .dark
        alert.view.tintColor = .cyan
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        
        UIApplication.shared.windows.filter({ $0.isKeyWindow }).first?.rootViewController?.present(alert, animated: true)
    }
    
//    static func startWaiting() {
//        ProgressHUD.show(nil, interaction: false)
//    }
//
//    static func stopWaiting() {
//        ProgressHUD.dismiss()
//    }
    #endif
    
}
