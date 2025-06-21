//
//  LoginView.swift
//  LemmeQuit
//
//  Created by Yako on 22/1/25.
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    // Estados para los campos de entrada
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    // Estados para animar transiciones
    @State private var emailOffset: Double = 0
    @State private var passwordOffset: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo con gradiente
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.white]),
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Logo y título
                    VStack(spacing: 15) {
                        Image(systemName: "heart.text.square.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                            .shadow(radius: 5)
                        
                        Text("LemmeQuit")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("Tu compañero para superar adicciones")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 20)
                    }
                    .padding(.bottom, 30)
                    
                    // Campos de entrada
                    VStack(spacing: 15) {
                        // Campo de email
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            TextField("Email", text: $email)
                                .foregroundColor(.blue.opacity(0.8))
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .disableAutocorrection(true)
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(color: .gray.opacity(0.4), radius: 3, x: 0, y: 2)
                        .offset(x: emailOffset)
                        .animation(.spring(response: 0.3), value: emailOffset)
                        
                        // Campo de contraseña
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            SecureField("Contraseña", text: $password)
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(color: .gray.opacity(0.4), radius: 3, x: 0, y: 2)
                        .offset(x: passwordOffset)
                        .animation(.spring(response: 0.3), value: passwordOffset)
                    }
                    .padding(.horizontal, 20)
                    
                    // Botón de login
                    Button(action: loginUser) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                            
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Iniciar Sesión")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .disabled(isLoading || !isValidInput)
                    .opacity(isValidInput ? 1.0 : 0.6)
                    
                    Spacer()
                    
                    // Botón de registro
                    NavigationLink(destination: RegisterView()) {
                        HStack {
                            Text("¿No tienes cuenta?")
                                .foregroundColor(.gray)
                            
                            Text("Regístrate")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 30)
                    }
                }
                .padding()
            }
            .alert("Error de Login", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    // Animación de "sacudida" para los campos con error
                    if email.isEmpty {
                        shakeField(field: $emailOffset)
                    }
                    if password.isEmpty {
                        shakeField(field: $passwordOffset)
                    }
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // Validación básica de campos
    private var isValidInput: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    // Función de login corregida
    private func loginUser() {
        // Validación preventiva
        guard isValidInput else {
            errorMessage = "Por favor completa todos los campos"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authVM.login(email: email, password: password)
                // El éxito se maneja automáticamente con el estado isAuthenticated del ViewModel
            } catch {
                // Manejar error
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
        
        // Versión con completion handler como alternativa
        /*
        authVM.login(email: email, password: password) { result in
            isLoading = false
            switch result {
            case .success:
                // La navegación ocurrirá automáticamente basada en isAuthenticated
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        */
    }
    
    // Función para animar "sacudida" en campos con error
    private func shakeField(field: Binding<Double>) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
            field.wrappedValue = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                field.wrappedValue = -10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                field.wrappedValue = 5
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                field.wrappedValue = 0
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}



