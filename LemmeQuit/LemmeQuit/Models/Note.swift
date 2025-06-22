//
//  Note.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//

import Foundation
import FirebaseFirestore

struct Note: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var content: String
    var date: Date
    var userId: String          // ID del usuario que creó la nota
    var patientId: String?      // ID del paciente (si es una nota del terapeuta)
    var therapistId: String?    // ID del terapeuta (si es una nota del paciente)
    var isButtonPress: Bool     // Si es un registro de pulsación del botón central (para pacientes)
    var isVoiceNote: Bool       // Si es una nota de voz transcrita (para terapeutas)
    var voiceUrl: String?       // URL a archivo de audio (para notas de voz)
    var noteType: NoteType
    
    enum NoteType: String, Codable, CaseIterable {
        case general           // Nota general
        case therapy           // Nota relacionada con terapia
        case addiction         // Registro de episodio de adicción (pulsación del botón)
        case medication        // Nota sobre medicación
        case transcription     // Transcripción de voz del terapeuta
    }
    
    // Inicializador estándar
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         date: Date = Date(),
         userId: String,
         patientId: String? = nil,
         therapistId: String? = nil,
         isButtonPress: Bool = false,
         isVoiceNote: Bool = false,
         voiceUrl: String? = nil,
         noteType: NoteType = .general) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.userId = userId
        self.patientId = patientId
        self.therapistId = therapistId
        self.isButtonPress = isButtonPress
        self.isVoiceNote = isVoiceNote
        self.voiceUrl = voiceUrl
        self.noteType = noteType
    }
    
    // Inicializador desde Firestore
    init?(document: [String: Any], id: String) {
        guard
            let title = document["title"] as? String,
            let content = document["content"] as? String,
            let timestamp = document["date"] as? Timestamp,
            let userId = document["userId"] as? String,
            let typeString = document["noteType"] as? String,
            let noteType = NoteType(rawValue: typeString),
            let isButtonPress = document["isButtonPress"] as? Bool,
            let isVoiceNote = document["isVoiceNote"] as? Bool
        else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.content = content
        self.date = timestamp.dateValue()
        self.userId = userId
        self.patientId = document["patientId"] as? String
        self.therapistId = document["therapistId"] as? String
        self.isButtonPress = isButtonPress
        self.isVoiceNote = isVoiceNote
        self.voiceUrl = document["voiceUrl"] as? String
        self.noteType = noteType
    }
    
    // Convertir a diccionario para Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "content": content,
            "date": Timestamp(date: date),
            "userId": userId,
            "noteType": noteType.rawValue,
            "isButtonPress": isButtonPress,
            "isVoiceNote": isVoiceNote
        ]
        
        // Agregamos opcionales solo si tienen valor
        if let patientId = patientId {
            dict["patientId"] = patientId
        }
        
        if let therapistId = therapistId {
            dict["therapistId"] = therapistId
        }
        
        if let voiceUrl = voiceUrl {
            dict["voiceUrl"] = voiceUrl
        }
        
        return dict
    }
    
    // Función de ayuda para formatear la fecha
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Función para crear una nota de pulsación de botón (para adicción)
    static func createButtonPressNote(userId: String) -> Note {
        return Note(
            title: "Episodio registrado",
            content: "Se ha registrado un episodio de adicción",
            userId: userId,
            isButtonPress: true,
            noteType: .addiction
        )
    }
    
    // Función para crear una nota de voz transcrita (para terapeutas)
    static func createVoiceNote(title: String, transcription: String, userId: String, patientId: String, voiceUrl: String? = nil) -> Note {
        return Note(
            title: title,
            content: transcription,
            userId: userId,
            patientId: patientId,
            isVoiceNote: true,
            voiceUrl: voiceUrl,
            noteType: .transcription
        )
    }
    
    // Nota vacía por defecto (para previsualización o inicialización)
    static let empty = Note(
        id: "",
        title: "",
        content: "",
        userId: ""
    )
}
