//
//  Appointment.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//

import Foundation
import FirebaseFirestore

struct Appointment: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var date: Date
    var userId: String      // ID del usuario al que pertenece la cita (paciente o terapeuta)
    var relatedUserId: String?  // ID del otro usuario relacionado (terapeuta o paciente)
    var notes: String?      // Notas opcionales sobre la cita
    var isCompleted: Bool   // Si la cita ya ha ocurrido o no
    var reminderSet: Bool   // Si tiene configurado un recordatorio
    var appointmentType: AppointmentType
    
    enum AppointmentType: String, Codable, CaseIterable {
        case therapy        // Sesión de terapia
        case medication     // Recordatorio de medicación (solo para pacientes)
        case generalNote    // Nota general en el calendario
    }
    
    // Inicializador estándar
    init(id: String = UUID().uuidString,
         title: String,
         date: Date,
         userId: String,
         relatedUserId: String? = nil,
         notes: String? = nil,
         isCompleted: Bool = false,
         reminderSet: Bool = false,
         appointmentType: AppointmentType = .therapy) {
        self.id = id
        self.title = title
        self.date = date
        self.userId = userId
        self.relatedUserId = relatedUserId
        self.notes = notes
        self.isCompleted = isCompleted
        self.reminderSet = reminderSet
        self.appointmentType = appointmentType
    }
    
    // Inicializador desde Firestore
    init?(document: [String: Any], id: String) {
        guard
            let title = document["title"] as? String,
            let timestamp = document["date"] as? Timestamp,
            let userId = document["userId"] as? String,
            let typeString = document["appointmentType"] as? String,
            let appointmentType = AppointmentType(rawValue: typeString),
            let isCompleted = document["isCompleted"] as? Bool,
            let reminderSet = document["reminderSet"] as? Bool
        else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.date = timestamp.dateValue()
        self.userId = userId
        self.relatedUserId = document["relatedUserId"] as? String
        self.notes = document["notes"] as? String
        self.isCompleted = isCompleted
        self.reminderSet = reminderSet
        self.appointmentType = appointmentType
    }
    
    // Convertir a diccionario para Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "date": Timestamp(date: date),
            "userId": userId,
            "appointmentType": appointmentType.rawValue,
            "isCompleted": isCompleted,
            "reminderSet": reminderSet
        ]
        
        // Agregamos opcionales solo si tienen valor
        if let relatedUserId = relatedUserId {
            dict["relatedUserId"] = relatedUserId
        }
        
        if let notes = notes {
            dict["notes"] = notes
        }
        
        return dict
    }
    
    // Cita vacía por defecto (para previsualización o inicialización)
    static let empty = Appointment(
        id: "",
        title: "",
        date: Date(),
        userId: "",
        appointmentType: .therapy
    )
    
    // Función de ayuda para formatear la fecha
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
