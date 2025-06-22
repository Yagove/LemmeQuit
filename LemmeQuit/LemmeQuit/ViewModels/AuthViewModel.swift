//
//  AuthVM.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//


import Foundation
import Firebase
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    
    @Published var currentUser: User? = nil
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Verificar si hay una sesión activa al iniciar
        checkCurrentSession()
    }
    
    // MARK: - Verificar sesión actual
    func checkCurrentSession() {
        Task {
            await MainActor.run {
                isLoading = true
                error = nil
            }
            
            if let userId = Auth.auth().currentUser?.uid {
                do {
                    if let user = try await firebaseService.getUserData(userId: userId) {
                        await MainActor.run {
                            self.currentUser = user
                            self.isAuthenticated = true
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run {
                            self.isLoading = false
                            self.isAuthenticated = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.error = error.localizedDescription
                        self.isLoading = false
                        self.isAuthenticated = false
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Registro (versión async)
    func register(name: String, email: String, password: String, role: User.UserType, extraUserData: User) async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            var userData = extraUserData
            userData.name = name
            userData.email = email
            userData.role = role
            
            let user = try await firebaseService.signUp(email: email, password: password, userData: userData)
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Login (versión async) - MEJORADA
    func login(email: String, password: String) async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            // 1. Realizar la autenticación con Firebase Auth
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let userId = authResult.user.uid
            
            // 2. Verificar si los datos del usuario existen antes de intentar recuperarlos
            let documentSnapshot = try await Firestore.firestore().collection("users").document(userId).getDocument()
            
            guard documentSnapshot.exists else {
                // Si el documento no existe, manejar el error de forma segura
                await MainActor.run {
                    self.isLoading = false
                    self.error = "Cuenta de usuario encontrada, pero faltan datos del perfil. Por favor contacta a soporte."
                }
                throw NSError(domain: "AppError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Datos de usuario incompletos"])
            }
            
            // 3. Asegurarse de que la decodificación sea segura
            guard let data = documentSnapshot.data(),
                  let user = User(document: data, id: userId) else {
                await MainActor.run {
                    self.isLoading = false
                    self.error = "Error al procesar los datos del usuario"
                }
                throw NSError(domain: "AppError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Error de deserialización"])
            }
            
            // 4. Todo correcto, actualizar estado
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MÉTODO MENOS RECOMENDADO - Comentado
    // Este método usa completion handlers y es menos adecuado porque:
    // 1. Mezcla async/await con completion handlers
    // 2. Código más verboso y complejo
    // 3. Menos integración nativa con SwiftUI
    /*
    func login(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let _ = try await firebaseService.signIn(email: email, password: password)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    */
    
    // MARK: - Cerrar sesión
    func signOut() {
        do {
            try firebaseService.signOut()
            self.currentUser = nil
            self.isAuthenticated = false
        } catch {
            self.error = error.localizedDescription
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Actualizar datos del usuario
    func updateUserData() async {
        guard let userId = currentUser?.id else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            if let updatedUser = try await firebaseService.getUserData(userId: userId) {
                await MainActor.run {
                    self.currentUser = updatedUser
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

