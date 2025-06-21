//
//  ChatGPTVM.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//

import Foundation
import SwiftUI
import Combine

class ChatGPTViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var currentResponse: String = ""
    @Published var errorMessage: String = ""
    @Published var showResponse = false
    
    // Historial de respuestas para posible referencia futura
    @Published var responseHistory: [ChatResponse] = []
    
    // MARK: - Private Properties
    private let openAIManager = OpenAIManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Inicialización, si es necesaria
    }
    
    // MARK: - Public Methods
    
    /// Solicita un consejo personalizado para el paciente basado en su perfil
    /// - Parameter user: El usuario (paciente) que solicita el consejo
    func requestAdvice(for user: User) {
        guard user.role == .patient else {
            errorMessage = "Solo los pacientes pueden solicitar consejos personalizados."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        // Construir el prompt usando el PromptBuilder
        let prompt = PromptBuilder.buildAdictionAssistantPrompt(user: user)
        
        // Enviar solicitud a OpenAI
        openAIManager.fetchAIResponse(prompt: prompt) { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let response = response {
                    self.currentResponse = response
                    self.showResponse = true
                    
                    // Guardar en historial
                    let newResponse = ChatResponse(
                        id: UUID().uuidString,
                        userId: user.id,
                        prompt: prompt,
                        response: response,
                        timestamp: Date()
                    )
                    self.responseHistory.append(newResponse)
                    
                    // Opcionalmente guardar en FireStore si se desea persistencia
                    self.saveResponseToFirestore(newResponse)
                } else {
                    self.errorMessage = "No se pudo obtener una respuesta. Inténtalo de nuevo."
                }
            }
        }
    }
    
    /// Versión asíncrona para solicitar consejo (iOS 15+)
    func requestAdviceAsync(for user: User) async {
        print("🔄 ChatGPTViewModel: Iniciando requestAdviceAsync")
        print("🔄 Usuario: \(user.name), Role: \(user.role)")
        
        guard user.role == .patient else {
            print("❌ Error: Usuario no es paciente")
            await MainActor.run {
                errorMessage = "Solo los pacientes pueden solicitar consejos personalizados."
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        // Construir el prompt
        let prompt = PromptBuilder.buildAdictionAssistantPrompt(user: user)
        print("📝 Prompt generado: \(prompt)")
        
        do {
            if #available(iOS 15.0, *) {
                print("🌐 Llamando a fetchAIResponseAsync...")
                if let response = await openAIManager.fetchAIResponseAsync(prompt: prompt) {
                    print("✅ Respuesta recibida: \(response)")
                    let newResponse = ChatResponse(
                        id: UUID().uuidString,
                        userId: user.id,
                        prompt: prompt,
                        response: response,
                        timestamp: Date()
                    )
                    
                    await MainActor.run {
                        self.currentResponse = response
                        self.showResponse = true
                        self.responseHistory.append(newResponse)
                        self.isLoading = false
                    }
                    
                    // Guardar en Firestore
                    self.saveResponseToFirestore(newResponse)
                } else {
                    await MainActor.run {
                        self.errorMessage = "No se pudo obtener una respuesta. Inténtalo de nuevo."
                        self.isLoading = false
                    }
                }
            } else {
                // Recurrir a la versión con completion handler en iOS < 15
                await withCheckedContinuation { continuation in
                    openAIManager.fetchAIResponse(prompt: prompt) { [weak self] response in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        
                        Task {
                            if let response = response {
                                let newResponse = ChatResponse(
                                    id: UUID().uuidString,
                                    userId: user.id,
                                    prompt: prompt,
                                    response: response,
                                    timestamp: Date()
                                )
                                
                                await MainActor.run {
                                    self.currentResponse = response
                                    self.showResponse = true
                                    self.responseHistory.append(newResponse)
                                    self.isLoading = false
                                }
                                
                                self.saveResponseToFirestore(newResponse)
                            } else {
                                await MainActor.run {
                                    self.errorMessage = "No se pudo obtener una respuesta. Inténtalo de nuevo."
                                    self.isLoading = false
                                }
                            }
                            
                            continuation.resume()
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Para terapeutas: Obtener un consejo personalizado para ayudar a un paciente específico
    func requestTherapistAdvice(therapist: User, patient: User, issue: String) {
        guard therapist.role == .therapist else {
            errorMessage = "Solo los terapeutas pueden solicitar este tipo de consejos."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        // Construir el prompt para el terapeuta
        let prompt = PromptBuilder.buildTherapistAssistancePrompt(therapist: therapist, patient: patient)
        
        // Enviar solicitud a OpenAI
        openAIManager.fetchAIResponse(prompt: prompt) { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let response = response {
                    self.currentResponse = response
                    self.showResponse = true
                    
                    // Guardar en historial
                    let newResponse = ChatResponse(
                        id: UUID().uuidString,
                        userId: therapist.id,
                        patientId: patient.id,
                        prompt: prompt,
                        response: response,
                        timestamp: Date()
                    )
                    self.responseHistory.append(newResponse)
                    
                    // Opcionalmente guardar en FireStore
                    self.saveResponseToFirestore(newResponse)
                } else {
                    self.errorMessage = "No se pudo obtener una respuesta. Inténtalo de nuevo."
                }
            }
        }
    }
    
    /// Oculta la respuesta actual
    func dismissResponse() {
        showResponse = false
    }
    
    /// Limpia el mensaje de error
    func clearError() {
        errorMessage = ""
    }
    
    // MARK: - Private Methods
    
    /// Guarda la respuesta en Firestore para historial (opcional)
    private func saveResponseToFirestore(_ response: ChatResponse) {
        // Implementar si se desea persistencia
        // Se podría usar FirebaseService si se extiende para soportar esta funcionalidad
        
        // Ejemplo de implementación:
        /*
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("chatResponses").document(response.id).setData([
                    "userId": response.userId,
                    "patientId": response.patientId ?? "",
                    "prompt": response.prompt,
                    "response": response.response,
                    "timestamp": Timestamp(date: response.timestamp)
                ])
            } catch {
                print("Error guardando respuesta: \(error.localizedDescription)")
            }
        }
        */
    }
}

// MARK: - Modelos auxiliares

/// Modelo para almacenar las respuestas de ChatGPT
struct ChatResponse: Identifiable, Codable {
    let id: String
    let userId: String
    var patientId: String? = nil // Solo para respuestas de terapeutas
    let prompt: String
    let response: String
    let timestamp: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
