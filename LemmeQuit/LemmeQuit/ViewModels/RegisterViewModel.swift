//
//  R.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//
import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import Combine

class RegisterViewModel: ObservableObject {
    // Datos comunes
    @Published var userName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var repeatPassword = ""
    @Published var userType: User.UserType = .patient
    
    // Datos específicos de paciente
    @Published var sex = ""
    @Published var age = 18
    @Published var sport = ""
    @Published var addiction = "" 
    @Published var hobby1 = ""
    @Published var hobby2 = ""
    @Published var hobby3 = ""
    
    // Estado
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    @Published var isRegistered = false
    
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Validaciones
    var isEmailValid: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var isPasswordValid: Bool {
        // Mínimo 6 caracteres
        return password.count >= 6
    }
    
    var isFormValid: Bool {
        // Comprobar campos comunes
        guard !userName.isEmpty && isEmailValid && isPasswordValid && password == repeatPassword else {
            return false
        }
        
        // Para pacientes, verificar campos adicionales
        if userType == .patient {
            return !sex.isEmpty && !addiction.isEmpty && age > 0
        }
        
        return true
    }
    
    // MARK: - Métodos de registro
    
    // Versión async/await
    func registerUser() async {
        guard isFormValid else {
            if password != repeatPassword {
                errorMessage = "Las contraseñas no coinciden."
            } else if !isEmailValid {
                errorMessage = "El correo electrónico no es válido."
            } else if !isPasswordValid {
                errorMessage = "La contraseña debe tener al menos 6 caracteres."
            } else {
                errorMessage = "Por favor completa todos los campos obligatorios."
            }
            return
        }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Crear User con datos comunes
            var user = User(
                id: "",
                name: userName,
                email: email,
                role: userType
            )
            
            // Añadir datos específicos de paciente si es necesario
            if userType == .patient {
                user.sex = sex
                user.age = age
                user.sport = sport
                user.addiction = addiction
                user.hobbies = [hobby1, hobby2, hobby3].filter { !$0.isEmpty }
            }
            
            // Registrar usuario
            let _ = try await firebaseService.signUp(email: email, password: password, userData: user)
            
            await MainActor.run {
                self.successMessage = "Registro exitoso."
                self.errorMessage = ""
                self.isRegistered = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.successMessage = ""
                self.isLoading = false
            }
        }
    }
    
    // MÉTODO MENOS RECOMENDADO - Comentado
    // Este método usa completion handlers y es menos adecuado porque:
    // 1. Requiere dependencia adicional de AuthViewModel
    // 2. Código más verboso y complejo
    // 3. Manejo de threading manual con DispatchQueue
    // 4. Menos integración nativa con SwiftUI
    /*
    func registerUser(using authViewModel: AuthViewModel) {
        guard isFormValid else {
            if password != repeatPassword {
                errorMessage = "Las contraseñas no coinciden."
            } else if !isEmailValid {
                errorMessage = "El correo electrónico no es válido."
            } else if !isPasswordValid {
                errorMessage = "La contraseña debe tener al menos 6 caracteres."
            } else {
                errorMessage = "Por favor completa todos los campos obligatorios."
            }
            return
        }
        
        isLoading = true
        
        // Crear User con datos comunes
        var user = User(
            id: "",
            name: userName,
            email: email,
            role: userType
        )
        
        // Añadir datos específicos de paciente si es necesario
        if userType == .patient {
            user.sex = sex
            user.age = age
            user.sport = sport
            user.addiction = addiction
            user.hobbies = [hobby1, hobby2, hobby3].filter { !$0.isEmpty }
        }
        
        authViewModel.register(
            name: userName,
            email: email,
            password: password,
            role: userType,
            extraUserData: user
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success:
                    self.successMessage = "Registro exitoso."
                    self.errorMessage = ""
                    self.isRegistered = true
                case .failure(let error):
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.successMessage = ""
                }
            }
        }
    }
    */
    
    // MARK: - Utilidades
    
    func resetForm() {
        userName = ""
        email = ""
        password = ""
        repeatPassword = ""
        userType = .patient
        sex = ""
        age = 18
        sport = ""
        addiction = ""
        hobby1 = ""
        hobby2 = ""
        hobby3 = ""
        errorMessage = ""
        successMessage = ""
        isRegistered = false
    }
}
