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
        Hola! Soy un \(user.role == .patient ? "paciente" : "terapeuta"), tengo \(age) años, soy \(sex.lowercased()), tengo una adicción a \(addiction), \(practicaDeporte) y mis hobbies son: \(hobbiesText). Según el tiempo meteorológico de hoy, ¿qué me recomiendas hacer para entretenerme?
        """
    }
    
    // Prompt por defecto si no hay suficiente información
    static func buildDefaultPrompt() -> String {
        return """
        Soy una persona que está tratando de superar una adicción. 
        ¿Qué actividades me recomiendas hacer según el tiempo meteorológico actual para mantenerme entretenido y evitar recaer?
        """
    }
    
    // Prompt para terapeutas que quieren consejos sobre cómo ayudar a un paciente específico
    static func buildTherapistAssistancePrompt(therapist: User, patient: User) -> String {
        guard let addiction = patient.addiction,
              let age = patient.age,
              let sex = patient.sex,
              let sport = patient.sport,
              let hobbies = patient.hobbies else {
            return "Necesito consejos para ayudar a un paciente con un problema de adicción."
        }
        
        let practicaDeporte = !sport.isEmpty ? "le gusta el deporte" : "no practica deporte"
        let hobbiesText = hobbies.joined(separator: ", ")
        
        return """
        Soy un terapeuta que está tratando a un paciente con las siguientes características:
        - Edad: \(age) años
        - Sexo: \(sex)
        - Adicción: \(addiction)
        - \(practicaDeporte)
        - Hobbies: \(hobbiesText)
        
        ¿Qué actividades puedo recomendarle basadas en el tiempo meteorológico actual para que se mantenga entretenido y evite su adicción?
        """
    }
}
