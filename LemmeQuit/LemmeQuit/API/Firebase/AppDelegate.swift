//
//  AppDelegate.swift
//  LemmeQuit
//
//  Created by Yako on 10/4/25.
//


import Foundation
import Firebase
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Inicializar Firebase
        FirebaseApp.configure()
        return true
    }
}
