//
//  PromptBuilder.swift
//  LemmeQuit
//
//  Created by Yako on 6/5/25.
//

import Foundation

struct PromptBuilder {
    
    // Construye el prompt personalizado basado en la información del usuario
    static func buildAdictionAssistantPrompt(user: User) -> String {
        // Verificar que sea un paciente con información completa
        guard user.role == .patient,
              let addiction = user.addiction,
              let age = user.age,
              let sex = user.sex,
              let sport = user.sport,
              let hobbies = user.hobbies else {
            return buildDefaultPrompt()
        }
        
        let practicaDeporte = !sport.isEmpty ? "me gusta el deporte" : "no practico deporte"
        let hobbiesText = hobbies.joined(separator: ", ")
        
        return """
        Hola! Soy un \(user.role == .patient ? "paciente" : "terapeuta"), tengo \(age) años, soy \(sex.lowercased()), tengo una adicción a \(addiction), \(practicaDeporte) y mis hobbies son: \(hobbiesText). Según el tiempo meteorológico, ¿qué me recomiendas hacer para entretenerme?
        """
    }
    
    // Prompt por defecto si no hay suficiente información
    static func buildDefaultPrompt() -> String {
        return """
        Soy una persona que está tratando de superar una adicción. 
        ¿Qué actividades me recomiendas hacer según el tiempo meteorológico para mantenerme entretenido y evitar recaer?
        """
    }
}
