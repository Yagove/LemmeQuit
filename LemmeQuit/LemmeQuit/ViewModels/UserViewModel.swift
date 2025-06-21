//
//  UserVM.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class UserViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    // Para funcionalidades específicas
    @Published var assignedTherapist: User?
    @Published var patientsList: [User] = []
    @Published var selectedPatient: User?
    @Published var activePatient: User?
    
    // MARK: - Private Properties
    private let firebaseService = FirebaseService.shared
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isPatient: Bool {
        currentUser?.role == .patient
    }
    
    var isTherapist: Bool {
        currentUser?.role == .therapist
    }
    
    var hasTherapist: Bool {
        currentUser?.therapistId != nil
    }
    
    var hasPatients: Bool {
        !patientsList.isEmpty
    }
    
    // MARK: - Initialization
    init() {
        setupAuthListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth State Listener
    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (auth, firebaseUser) in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                Task {
                    await self.fetchUserData(uid: firebaseUser.uid)
                }
            } else {
                Task { @MainActor in
                    self.currentUser = nil
                    self.resetUserData()
                }
            }
        }
    }
    
    @MainActor
    private func resetUserData() {
        assignedTherapist = nil
        patientsList = []
        selectedPatient = nil
        activePatient = nil
        clearSelectedPatientFromStorage()
    }
    
    // MARK: - User Data Operations
    @MainActor
    func fetchUserData(uid: String) async {
        isLoading = true
        error = nil
        
        do {
            if let user = try await firebaseService.getUserData(userId: uid) {
                self.currentUser = user
                
                // Cargar datos relacionados dependiendo del rol
                if user.role == .patient {
                    await loadPatientData(user)
                } else if user.role == .therapist {
                    await loadTherapistData(user)
                }
            } else {
                self.error = "No se encontraron datos de usuario"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        self.isLoading = false
    }
    
    @MainActor
    private func loadPatientData(_ patient: User) async {
        // Si el paciente tiene un terapeuta asignado, cargarlo
        if let therapistId = patient.therapistId {
            do {
                assignedTherapist = try await firebaseService.getUserData(userId: therapistId)
            } catch {
                self.error = "Error al cargar datos del terapeuta: \(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    private func loadTherapistData(_ therapist: User) async {
        // Cargar lista de pacientes
        do {
            patientsList = try await firebaseService.getPatientsForTherapist(therapistId: therapist.id)
            
            // Cargar paciente activo
            await loadActivePatient()
        } catch {
            self.error = "Error al cargar pacientes: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Actualización de perfil
    func updateUserProfile() async {
        guard let user = currentUser else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            try await firebaseService.saveUserData(user: user)
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Gestión Terapeuta-Paciente
    
    // Para pacientes: Aceptar solicitud de un terapeuta
    func acceptTherapist(therapistId: String) async {
        guard let userId = currentUser?.id else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            try await firebaseService.assignTherapistToPatient(patientId: userId, therapistId: therapistId)
            // Recargar datos
            if let user = try await firebaseService.getUserData(userId: userId) {
                await MainActor.run {
                    self.currentUser = user
                    // Cargar datos del terapeuta
                    Task {
                        await self.loadPatientData(user)
                    }
                }
            }
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Gestión de Pacientes (Mejorado para MyPatientsView)
    
    // Para terapeutas: Seleccionar paciente activo
    func selectPatient(_ patient: User) {
        Task {
            await setActivePatient(patient)
        }
    }
    
    // Para terapeutas: Añadir nuevo paciente por email
    func addPatientByEmail(_ email: String) async -> Bool {
        guard let therapistId = currentUser?.id else { return false }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Buscar paciente por email
            guard let patient = try await firebaseService.getUserByEmail(email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) else {
                await MainActor.run {
                    self.error = "No se encontró ningún paciente registrado con ese correo electrónico"
                    self.isLoading = false
                }
                return false
            }
            
            // Verificar que sea un paciente
            guard patient.role == .patient else {
                await MainActor.run {
                    self.error = "El correo proporcionado pertenece a un terapeuta, no a un paciente"
                    self.isLoading = false
                }
                return false
            }
            
            // Verificar que no esté ya añadido
            if patientsList.contains(where: { $0.id == patient.id }) {
                await MainActor.run {
                    self.error = "Este paciente ya está en tu lista"
                    self.isLoading = false
                }
                return false
            }
            
            // Asignar terapeuta al paciente
            try await firebaseService.assignTherapistToPatient(patientId: patient.id, therapistId: therapistId)
            
            // Recargar lista de pacientes
            let patients = try await firebaseService.getPatientsForTherapist(therapistId: therapistId)
            
            await MainActor.run {
                self.patientsList = patients
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    // Para terapeutas: Añadir nuevo paciente por ID (mantener compatibilidad)
    func addPatient(patientId: String) async {
        guard let therapistId = currentUser?.id else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            try await firebaseService.assignTherapistToPatient(patientId: patientId, therapistId: therapistId)
            // Recargar lista de pacientes
            let patients = try await firebaseService.getPatientsForTherapist(therapistId: therapistId)
            
            await MainActor.run {
                self.patientsList = patients
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // Para terapeutas: Remover paciente
    func removePatient(_ patient: User) async -> Bool {
        guard let therapistId = currentUser?.id else { return false }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Eliminar relación terapeuta-paciente
            try await firebaseService.removeTherapistFromPatient(patientId: patient.id, therapistId: therapistId)
            
            // Recargar lista de pacientes
            let patients = try await firebaseService.getPatientsForTherapist(therapistId: therapistId)
            
            await MainActor.run {
                self.patientsList = patients
                
                // Si el paciente eliminado era el seleccionado, deseleccionarlo
                if self.selectedPatient?.id == patient.id || self.activePatient?.id == patient.id {
                    Task {
                        await self.setActivePatient(nil)
                    }
                }
                
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - INVITATIONS
    func sendInvitationToPatient(patientId: String) async {
        guard let therapistId = currentUser?.id else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            try await FirebaseService.shared.sendTherapistInvitation(from: therapistId, to: patientId)
            // Recargar pacientes
            let patients = try await FirebaseService.shared.getPatientsForTherapist(therapistId: therapistId)
            await MainActor.run {
                self.patientsList = patients
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func acceptTherapistInvitation() async {
        guard let patientId = currentUser?.id else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            try await FirebaseService.shared.acceptTherapistInvitation(patientId: patientId)
            // Recargar usuario
            if let updatedUser = try await FirebaseService.shared.getUserData(userId: patientId) {
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
    
    // MARK: - ACTIVE PATIENT MANAGEMENT (Mejorado)
    
    func setActivePatient(_ patient: User?) async {
        guard let therapistId = currentUser?.id else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            try await FirebaseService.shared.setActivePatient(therapistId: therapistId, patientId: patient?.id)
            
            await MainActor.run {
                self.activePatient = patient
                self.selectedPatient = patient // Mantener compatibilidad
                self.currentUser?.activePatientId = patient?.id
                self.isLoading = false
                
                // Guardar en storage local para persistencia
                if let patient = patient {
                    self.saveSelectedPatientToStorage(patient)
                } else {
                    self.clearSelectedPatientFromStorage()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadActivePatient() async {
        guard let therapistId = currentUser?.id else { return }
        
        do {
            let activePatient = try await FirebaseService.shared.getActivePatient(for: therapistId)
            await MainActor.run {
                self.activePatient = activePatient
                self.selectedPatient = activePatient
                
                // Si no hay paciente activo en Firebase, verificar UserDefaults
                if activePatient == nil {
                    self.loadSelectedPatientFromStorage()
                }
            }
        } catch {
            print("Error cargando paciente activo: \(error.localizedDescription)")
            // Si hay error, intentar cargar desde storage local
            await MainActor.run {
                self.loadSelectedPatientFromStorage()
            }
        }
    }
    
    // MARK: - Persistencia Local (Nuevo)
    
    private func saveSelectedPatientToStorage(_ patient: User) {
        UserDefaults.standard.set(patient.id, forKey: "selectedPatientId")
        
        // Guardar también los datos del paciente por si acaso
        if let encoded = try? JSONEncoder().encode(patient) {
            UserDefaults.standard.set(encoded, forKey: "selectedPatientData")
        }
    }
    
    private func loadSelectedPatientFromStorage() {
        guard let selectedPatientId = UserDefaults.standard.string(forKey: "selectedPatientId") else {
            return
        }
        
        // Buscar el paciente en la lista actual
        if let patient = patientsList.first(where: { $0.id == selectedPatientId }) {
            selectedPatient = patient
            activePatient = patient
        } else if let data = UserDefaults.standard.data(forKey: "selectedPatientData"),
                  let patient = try? JSONDecoder().decode(User.self, from: data) {
            // Si no está en la lista, usar los datos guardados
            selectedPatient = patient
            activePatient = patient
        }
    }
    
    private func clearSelectedPatientFromStorage() {
        UserDefaults.standard.removeObject(forKey: "selectedPatientId")
        UserDefaults.standard.removeObject(forKey: "selectedPatientData")
    }
    
    // MARK: - Helper Methods
    func clearError() {
        error = nil
    }
    
    // MARK: - Refresh Methods (Útiles para pull-to-refresh)
    
    func refreshPatientsList() async {
        guard let therapistId = currentUser?.id else { return }
        
        do {
            let patients = try await firebaseService.getPatientsForTherapist(therapistId: therapistId)
            await MainActor.run {
                self.patientsList = patients
            }
        } catch {
            await MainActor.run {
                self.error = "Error al actualizar lista de pacientes: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }
        await fetchUserData(uid: userId)
    }
}
