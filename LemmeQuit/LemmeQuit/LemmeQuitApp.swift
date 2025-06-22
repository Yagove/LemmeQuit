//
//  LemmeQuitApp.swift
//  LemmeQuit
//
//  Created by Yako on 20/1/25.
//

import SwiftUI
import Firebase

@main
struct LemmeQuitApp: App {
    // Registrar AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Estado global
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var userViewModel = UserViewModel()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(userViewModel)
        }
    }
}
