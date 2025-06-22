//
//  FirebaseService.swift
//  LemmeQuit
//
//  Created by Yako on 10/6/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class FirebaseService {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    private init() {}
    
    // MARK: - Autenticación
    
    func signIn(email: String, password: String) async throws -> User {
        let authResult = try await auth.signIn(withEmail: email, password: password)
        let userId = authResult.user.uid
        
        guard let userData = try await getUserData(userId: userId) else {
            throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No se encontró el perfil de usuario"])
        }
        
        return userData
    }
    
    func signUp(email: String, password: String, userData: User) async throws -> User {
        let authResult = try await auth.createUser(withEmail: email, password: password)
        let userId = authResult.user.uid
        
        var updatedUserData = userData
        updatedUserData.id = userId
        
        try await saveUserData(user: updatedUserData)
        
        return updatedUserData
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    func getCurrentUserId() -> String? {
        return auth.currentUser?.uid
    }
    
    // MARK: - Usuarios
    
    func getUserData(userId: String) async throws -> User? {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return User(document: data, id: userId)
    }
    
    func getUserByEmail(email: String) async throws -> User? {
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        let data = document.data()
        return User(document: data, id: document.documentID)
    }
    
    func saveUserData(user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toDictionary(), merge: true)
    }
    
    // MARK: - Citas
    
    func saveAppointment(_ appointment: Appointment) async throws -> String {
        if appointment.id.isEmpty {
            // Nueva cita
            let docRef = db.collection("appointments").document()
            let id = docRef.documentID
            var updatedAppointment = appointment
            updatedAppointment.id = id
            try await docRef.setData(updatedAppointment.toDictionary())
            return id
        } else {
            // Actualizar cita existente
            try await db.collection("appointments").document(appointment.id).setData(appointment.toDictionary(), merge: true)
            return appointment.id
        }
    }
    
    func deleteAppointment(id: String) async throws {
        try await db.collection("appointments").document(id).delete()
    }
    
    func getAppointmentsForUser(userId: String) async throws -> [Appointment] {
        let query = db.collection("appointments")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: false)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            Appointment(document: document.data(), id: document.documentID)
        }
    }
    
    func getAppointmentsForDate(userId: String, date: Date) async throws -> [Appointment] {
        // Obtener fecha de inicio (00:00:00) y fin (23:59:59) del día
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
        
        let query = db.collection("appointments")
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endOfDay))
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            Appointment(document: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Notas
    
    func saveNote(_ note: Note) async throws -> String {
        if note.id.isEmpty {
            // Nueva nota
            let docRef = db.collection("notes").document()
            let id = docRef.documentID
            var updatedNote = note
            updatedNote.id = id
            try await docRef.setData(updatedNote.toDictionary())
            return id
        } else {
            // Actualizar nota existente
            try await db.collection("notes").document(note.id).setData(note.toDictionary(), merge: true)
            return note.id
        }
    }
    
    func deleteNote(id: String) async throws {
        try await db.collection("notes").document(id).delete()
    }
    
    func getNotesForUser(userId: String) async throws -> [Note] {
        let query = db.collection("notes")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            Note(document: document.data(), id: document.documentID)
        }
    }
    
    func getButtonPressNotesForDate(userId: String, date: Date) async throws -> [Note] {
        // Obtener fecha de inicio (00:00:00) y fin (23:59:59) del día
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
        
        let query = db.collection("notes")
            .whereField("userId", isEqualTo: userId)
            .whereField("isButtonPress", isEqualTo: true)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endOfDay))
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            Note(document: document.data(), id: document.documentID)
        }
    }
    
    func getNotesForPatient(patientId: String) async throws -> [Note] {
        let query = db.collection("notes")
            .whereField("patientId", isEqualTo: patientId)
            .order(by: "date", descending: true)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            Note(document: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Relaciones Terapeuta-Paciente
    
    func assignTherapistToPatient(patientId: String, therapistId: String) async throws {
        // Actualizar el paciente con el ID del terapeuta
        try await db.collection("users").document(patientId).updateData([
            "therapistId": therapistId,
            "relationshipStatus": "active"
        ])
        
        // Obtener el terapeuta actual y actualizar su lista de pacientes
        let therapistDoc = try await db.collection("users").document(therapistId).getDocument()
        var patientIds = (therapistDoc.data()?["patientIds"] as? [String]) ?? []
        
        // Añadir el paciente si no está ya añadido
        if !patientIds.contains(patientId) {
            patientIds.append(patientId)
            try await db.collection("users").document(therapistId).updateData([
                "patientIds": patientIds
            ])
        }
    }
    
    func removeTherapistFromPatient(patientId: String, therapistId: String) async throws {
        // Remover el terapeuta del paciente
        try await db.collection("users").document(patientId).updateData([
            "therapistId": FieldValue.delete(),
            "relationshipStatus": FieldValue.delete()
        ])
        
        // Actualizar la lista de pacientes del terapeuta
        let therapistDoc = try await db.collection("users").document(therapistId).getDocument()
        var patientIds = (therapistDoc.data()?["patientIds"] as? [String]) ?? []
        
        // Remover el paciente de la lista
        patientIds.removeAll { $0 == patientId }
        try await db.collection("users").document(therapistId).updateData([
            "patientIds": patientIds
        ])
    }
    
    func getPatientsForTherapist(therapistId: String) async throws -> [User] {
        // Buscar pacientes que tengan este terapeuta asignado
        let snapshot = try await db.collection("users")
            .whereField("role", isEqualTo: "patient")
            .whereField("therapistId", isEqualTo: therapistId)
            .whereField("relationshipStatus", isEqualTo: "active")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            User(document: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Paciente Activo (Seleccionado)
    
    func setActivePatient(therapistId: String, patientId: String?) async throws {
        var updateData: [String: Any] = [:]
        
        if let patientId = patientId {
            updateData["activePatientId"] = patientId
        } else {
            updateData["activePatientId"] = FieldValue.delete()
        }
        
        try await db.collection("users").document(therapistId).updateData(updateData)
    }

    func getActivePatient(for therapistId: String) async throws -> User? {
        let therapistDoc = try await db.collection("users").document(therapistId).getDocument()
        
        guard let activePatientId = therapistDoc.data()?["activePatientId"] as? String else {
            return nil
        }
        
        return try await getUserData(userId: activePatientId)
    }
    
    // MARK: - Métodos de invitación (para funcionalidad futura)
    
    func sendTherapistInvitation(from therapistId: String, to patientId: String) async throws {
        // Actualizar paciente con estado pendiente
        try await db.collection("users").document(patientId).updateData([
            "therapistId": therapistId,
            "relationshipStatus": "pending"
        ])
        
        // Añadir a lista del terapeuta
        let therapistDoc = try await db.collection("users").document(therapistId).getDocument()
        var patientIds = (therapistDoc.data()?["patientIds"] as? [String]) ?? []
        
        if !patientIds.contains(patientId) {
            patientIds.append(patientId)
            try await db.collection("users").document(therapistId).updateData([
                "patientIds": patientIds
            ])
        }
    }
    
    func acceptTherapistInvitation(patientId: String) async throws {
        try await db.collection("users").document(patientId).updateData([
            "relationshipStatus": "active"
        ])
    }
}
