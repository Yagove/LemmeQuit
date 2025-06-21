//
//  SettingsView.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingDeleteAlert = false
    @State private var showingNotificationsSettings = false
    @State private var notificationsEnabled = true
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Appearance Section
                Section(header: Text("Appearance")) {
                    Toggle("Modo Oscuro", isOn: $isDarkMode)
                }
                
                // Notifications Section
                Section(header: Text("Notificaciones")) {
                    Toggle("Habilitar Notificaciones", isOn: $notificationsEnabled)
                    
                    Button("Notification Settings") {
                        showingNotificationsSettings = true
                    }
                }
                
                // Account Section
                Section(header: Text("Cuenta")) {
                    NavigationLink("Cambiar correo electrónico") {
                        Text("Change Email View")
                            .navigationTitle("Change Email")
                    }
                    
                    NavigationLink("Cambiar contraseña") {
                        Text("Change Password View")
                            .navigationTitle("Change Password")
                    }
                    Button(role: .destructive, action: {
                        // Muestra una alerta de confirmación
                        showingLogoutAlert = true
                    }) {
                        Text("Cerrar Sesión")
                    }
                    .alert("¿Cerrar sesión?", isPresented: $showingLogoutAlert) {
                        Button("Cancelar", role: .cancel) {}
                        Button("Cerrar Sesión", role: .destructive) {
                            authViewModel.signOut()
                        }
                    } message: {
                        Text("¿Estás seguro de que quieres cerrar la sesión?")
                    }
                }
                
                // Support Section
                Section(header: Text("Ayuda")) {
                    NavigationLink("Centro de ayuda") {
                        Text("Help Center View")
                            .navigationTitle("Help Center")
                    }
                    
                    NavigationLink("Contáctanos") {
                        Text("Contact Form View")
                            .navigationTitle("Contact Us")
                    }
                    
                }
                
                // Danger Zone Section
                Section(header: Text("I QUIT")) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Text("Delete Account")
                    }
                    .alert("Delete Your Account?", isPresented: $showingDeleteAlert) {
                        Button("Delete", role: .destructive) {
                            // Handle account deletion here
                            print("Account deletion requested")
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingNotificationsSettings) {
                NotificationsSettingsView(notificationsEnabled: $notificationsEnabled)
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// Notifications Settings View (example of a sub-view)
struct NotificationsSettingsView: View {
    @Binding var notificationsEnabled: Bool
    @State private var soundEnabled = true
    @State private var vibrationEnabled = true
    @State private var badgeEnabled = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                }
                
                if notificationsEnabled {
                    Section(header: Text("Notification Preferences")) {
                        Toggle("Sound", isOn: $soundEnabled)
                        Toggle("Vibration", isOn: $vibrationEnabled)
                        Toggle("Badge App Icon", isOn: $badgeEnabled)
                    }
                    
                    Section(header: Text("Notification Types")) {
                        Toggle("Promotions", isOn: .constant(true))
                        Toggle("Messages", isOn: .constant(true))
                        Toggle("Updates", isOn: .constant(true))
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
