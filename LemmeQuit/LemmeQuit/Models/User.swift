//
//  User.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct User: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var email: String
    var role: UserType
    
    // Datos adicionales (solo para pacientes)
    var sex: String?
    var age: Int?
    var sport: String?
    var addiction: String?  // Corregido "adiction" a "addiction"
    var hobbies: [String]?
    
    // Para manejo de relaciones terapeuta-paciente
    var therapistId: String?
    var patientIds: [String]?
    
    var activePatientId: String?
    var relationshipStatus: RelationshipStatus?
    
    enum UserType: String, Codable, CaseIterable {
        case patient
        case therapist
    }
    
    enum RelationshipStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case active = "active"
        case rejected = "rejected"
    }
    
    // Inicializador estándar
    init(id: String, name: String, email: String, role: UserType,
         sex: String? = nil, age: Int? = nil, sport: String? = nil,
         addiction: String? = nil, hobbies: [String]? = nil,
         therapistId: String? = nil, patientIds: [String]? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.sex = sex
        self.age = age
        self.sport = sport
        self.addiction = addiction
        self.hobbies = hobbies
        self.therapistId = therapistId
        self.patientIds = patientIds
    }
    
    // Inicializador desde Firestore
    init?(document: [String: Any], id: String) {
        guard
            let name = document["name"] as? String,
            let email = document["email"] as? String,
            let roleString = document["role"] as? String
        else {
            print("Error inicializando User: faltan campos obligatorios")
            return nil
        }
        
        // Manejar el caso donde el rol no es válido
        guard let role = UserType(rawValue: roleString) else {
            print("Error inicializando User: rol inválido \(roleString)")
            return nil
        }
        
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        
        // Opcionales (solo si están en Firestore)
        self.sex = document["sex"] as? String
        
        // Evitar force-unwrapping de opcionales
        if let ageValue = document["age"] as? Int {
            self.age = ageValue
        }
        
        self.sport = document["sport"] as? String
        self.addiction = document["addiction"] as? String  // Corrección ortográfica
        self.hobbies = document["hobbies"] as? [String]
        
        // Relaciones
        self.therapistId = document["therapistId"] as? String
        self.patientIds = document["patientIds"] as? [String]
    }
    
    // Convertir a diccionario para Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "email": email,
            "role": role.rawValue
        ]
        
        if role == .patient {
            // Solo guardar valores no nulos o con valores predeterminados apropiados
            if let sex = sex { dict["sex"] = sex }
            if let age = age { dict["age"] = age }
            if let sport = sport { dict["sport"] = sport }
            if let addiction = addiction { dict["addiction"] = addiction }
            if let hobbies = hobbies { dict["hobbies"] = hobbies }
            if let therapistId = therapistId { dict["therapistId"] = therapistId }
        } else if role == .therapist {
            if let patientIds = patientIds { dict["patientIds"] = patientIds }
        }
        
        return dict
    }
    
    // Usuario vacío por defecto
    static let empty = User(id: "", name: "", email: "", role: .patient)
}
