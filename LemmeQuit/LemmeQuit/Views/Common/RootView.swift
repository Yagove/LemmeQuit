//
//  RootView.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        ZStack {
            // Contenido principal
            if authViewModel.isLoading {
                LoadingView()
            } else if authViewModel.isAuthenticated {
                Group {
                    if authViewModel.currentUser?.role == .patient {
                        MainPatientView()
                    } else if authViewModel.currentUser?.role == .therapist {
                        MainTherapistView()
                    }
                }
                .transition(.opacity)
                .environmentObject(authViewModel)
                .environmentObject(userViewModel)
            } else {
                LoginView()
                    .transition(.opacity)
                    .environmentObject(authViewModel)
            }
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
        .animation(.easeInOut, value: authViewModel.isLoading)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(AuthViewModel())
            .environmentObject(UserViewModel())
    }
}
