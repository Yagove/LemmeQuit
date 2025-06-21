//
//  PacientsListView.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//
import SwiftUI
import FirebaseFirestore

struct MyPatientsView: View {
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var showAddPatientSheet = false
    @State private var showPatientDetails = false
    @State private var selectedPatientForDetails: User?
    @State private var isLoading = false
    @State private var showingActionSheet = false
    @State private var patientEmailToAdd = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    
    var filteredPatients: [User] {
        if searchText.isEmpty {
            return userVM.patientsList
        } else {
            return userVM.patientsList.filter { $0.name.localizedCaseInsensitiveContains(searchText) ||
                                              $0.email.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Cabecera informativa si hay pacientes
                    if !userVM.patientsList.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            
                            Text("Mantén pulsado sobre un paciente para seleccionarlo como activo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Lista de pacientes
                    if userVM.patientsList.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("Aún no tienes pacientes")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Añade pacientes para poder llevar un seguimiento de su progreso")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                showAddPatientSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Añadir paciente")
                                }
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.top, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                    } else {
                        List {
                            ForEach(filteredPatients) { patient in
                                PatientListRow(
                                    patient: patient,
                                    isSelected: patient.id == userVM.selectedPatient?.id,
                                    onSelect: {
                                        selectPatient(patient)
                                    },
                                    onTap: {
                                        selectedPatientForDetails = patient
                                        showPatientDetails = true
                                    }
                                )
                                .contextMenu {
                                    Button(action: {
                                        selectPatient(patient)
                                    }) {
                                        Label("Seleccionar como activo", systemImage: "checkmark.circle")
                                    }
                                    
                                    Button(action: {
                                        selectedPatientForDetails = patient
                                        showPatientDetails = true
                                    }) {
                                        Label("Ver detalles", systemImage: "person.text.rectangle")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: {
                                        removePatient(patient)
                                    }) {
                                        Label("Eliminar paciente", systemImage: "person.badge.minus")
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        .searchable(text: $searchText, prompt: "Buscar paciente")
                    }
                }
                
                // Indicador de carga
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Mis Pacientes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddPatientSheet = true
                    }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Éxito", isPresented: $showSuccessMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(successMessage)
            }
            .sheet(isPresented: $showAddPatientSheet) {
                addPatientView
            }
            .sheet(isPresented: $showPatientDetails) {
                if let patient = selectedPatientForDetails {
                    PatientDetailView(patient: patient)
                        .environmentObject(userVM)
                }
            }
        }
        .onAppear {
            loadPatients()
        }
    }
    
    // Vista para añadir paciente
    private var addPatientView: some View {
        NavigationView {
            Form {
                Section(header: Text("Correo electrónico del paciente")) {
                    TextField("ejemplo@correo.com", text: $patientEmailToAdd)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                    
                    Text("Introduce el correo electrónico del paciente que deseas añadir. El paciente debe estar registrado en la aplicación.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: addPatient) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 5)
                            }
                            Text("Añadir paciente")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .disabled(patientEmailToAdd.isEmpty || isLoading)
                }
            }
            .navigationTitle("Añadir Paciente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        patientEmailToAdd = ""
                        showAddPatientSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Métodos
    
    private func loadPatients() {
        guard let therapistId = userVM.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                let patients = try await FirebaseService.shared.getPatientsForTherapist(therapistId: therapistId)
                
                await MainActor.run {
                    userVM.patientsList = patients
                    isLoading = false
                }
            } catch {
                print("Error cargando pacientes: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Error al cargar pacientes: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func addPatient() {
        guard let therapistId = userVM.currentUser?.id, !patientEmailToAdd.isEmpty else { return }
        
        // Validar formato de email
        if !isValidEmail(patientEmailToAdd) {
            errorMessage = "Por favor, introduce un correo electrónico válido"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Buscar usuario por correo electrónico
                if let patient = try await FirebaseService.shared.getUserByEmail(email: patientEmailToAdd.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) {
                    
                    // Verificar que sea un paciente, no un terapeuta
                    if patient.role == .patient {
                        // Verificar que no esté ya añadido
                        if userVM.patientsList.contains(where: { $0.id == patient.id }) {
                            await MainActor.run {
                                isLoading = false
                                errorMessage = "Este paciente ya está en tu lista"
                                showError = true
                            }
                            return
                        }
                        
                        // Asignar terapeuta al paciente
                        try await FirebaseService.shared.assignTherapistToPatient(
                            patientId: patient.id,
                            therapistId: therapistId
                        )
                        
                        // Recargar los pacientes
                        let updatedPatients = try await FirebaseService.shared.getPatientsForTherapist(therapistId: therapistId)
                        
                        await MainActor.run {
                            userVM.patientsList = updatedPatients
                            patientEmailToAdd = ""
                            isLoading = false
                            showAddPatientSheet = false
                            successMessage = "Paciente \(patient.name) añadido correctamente"
                            showSuccessMessage = true
                        }
                    } else {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = "El correo proporcionado pertenece a un terapeuta, no a un paciente"
                            showError = true
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "No se encontró ningún paciente registrado con ese correo electrónico"
                        showError = true
                    }
                }
            } catch {
                print("Error añadiendo paciente: \(error.localizedDescription)")
                
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error al añadir paciente: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func removePatient(_ patient: User) {
        guard let therapistId = userVM.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // Eliminar relación terapeuta-paciente
                try await FirebaseService.shared.removeTherapistFromPatient(
                    patientId: patient.id,
                    therapistId: therapistId
                )
                
                // Recargar los pacientes
                let updatedPatients = try await FirebaseService.shared.getPatientsForTherapist(therapistId: therapistId)
                
                await MainActor.run {
                    userVM.patientsList = updatedPatients
                    
                    // Si el paciente eliminado era el seleccionado, deseleccionarlo
                    if userVM.selectedPatient?.id == patient.id {
                        userVM.selectedPatient = nil
                    }
                    
                    isLoading = false
                    successMessage = "Paciente \(patient.name) eliminado correctamente"
                    showSuccessMessage = true
                }
            } catch {
                print("Error eliminando paciente: \(error.localizedDescription)")
                
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error al eliminar paciente: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func selectPatient(_ patient: User) {
        userVM.selectPatient(patient)
        successMessage = "Paciente \(patient.name) seleccionado como activo"
        showSuccessMessage = true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// Fila de paciente en la lista
struct PatientListRow: View {
    let patient: User
    let isSelected: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Avatar
            ZStack {
                Circle()
                    .fill(isSelected ? Color.green : Color.blue)
                    .frame(width: 40, height: 40)
                
                Text(String(patient.name.prefix(1)))
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(patient.name)
                    .font(.headline)
                    .fontWeight(isSelected ? .bold : .medium)
                
                Text(patient.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isSelected {
                    Text("Paciente activo")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onSelect()
        }
    }
}

// Vista de detalles del paciente
struct PatientDetailView: View {
    let patient: User
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var appointments: [Appointment] = []
    @State private var notes: [Note] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Encabezado con información del paciente
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(patient.id == userVM.selectedPatient?.id ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Text(String(patient.name.prefix(1)))
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(patient.id == userVM.selectedPatient?.id ? .green : .blue)
                        }
                        
                        Text(patient.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(patient.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if patient.id == userVM.selectedPatient?.id {
                            Text("Paciente activo")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.1))
                                )
                        }
                        
                        // Información adicional
                        HStack(spacing: 20) {
                            if let age = patient.age {
                                PatientInfoBadge(icon: "person.fill", text: "\(age) años")
                            }
                            
                            if let sex = patient.sex {
                                PatientInfoBadge(icon: "person.crop.circle", text: sex)
                            }
                            
                            if let addiction = patient.addiction {
                                PatientInfoBadge(icon: "exclamationmark.triangle", text: addiction)
                            }
                        }
                        .padding(.top, 5)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .padding()
                    
                    // Pestañas: Citas | Notas
                    Picker("Sección", selection: $selectedTab) {
                        Text("Citas").tag(0)
                        Text("Notas").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Contenido según pestaña seleccionada
                    if selectedTab == 0 {
                        // Citas
                        appointmentsSection
                    } else {
                        // Notas
                        notesSection
                    }
                }
                
                // Indicador de carga
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Detalles del Paciente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        userVM.selectPatient(patient)
                        dismiss()
                    }) {
                        HStack {
                            if patient.id == userVM.selectedPatient?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Label("Seleccionar", systemImage: "checkmark.circle")
                            }
                        }
                    }
                    .disabled(patient.id == userVM.selectedPatient?.id)
                }
            }
            .onAppear {
                loadPatientData()
            }
        }
    }
    
    // Vista de citas
    private var appointmentsSection: some View {
        ScrollView {
            VStack(spacing: 15) {
                HStack {
                    Text("Próximas citas")
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                if appointments.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No hay citas programadas")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else {
                    ForEach(appointments.sorted { $0.date > $1.date }) { appointment in
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appointment.title)
                                    .font(.headline)
                                
                                Text(appointment.date, style: .date)
                                    .font(.subheadline)
                                
                                Text(appointment.date, style: .time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let notes = appointment.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // Vista de notas
    private var notesSection: some View {
        ScrollView {
            VStack(spacing: 15) {
                HStack {
                    Text("Notas del paciente")
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                if notes.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No hay notas para este paciente")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else {
                    ForEach(notes.sorted { $0.date > $1.date }) { note in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                // Icono según tipo de nota
                                Image(systemName: note.isVoiceNote ? "mic.fill" : "note.text")
                                    .foregroundColor(note.isVoiceNote ? .red : .blue)
                                
                                Text(note.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(note.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            Text(note.content)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Métodos
    
    private func loadPatientData() {
        isLoading = true
        
        Task {
            async let appointmentsTask = loadAppointments()
            async let notesTask = loadNotes()
            
            let (fetchedAppointments, fetchedNotes) = await (appointmentsTask, notesTask)
            
            await MainActor.run {
                self.appointments = fetchedAppointments
                self.notes = fetchedNotes
                self.isLoading = false
            }
        }
    }
    
    private func loadAppointments() async -> [Appointment] {
        do {
            // Cargar citas para el terapeuta que tienen este paciente como relacionado
            let appointments = try await FirebaseService.shared.getAppointmentsForUser(userId: userVM.currentUser?.id ?? "")
            
            // Filtrar las citas para mostrar solo las relacionadas con este paciente
            return appointments.filter { $0.relatedUserId == patient.id }
        } catch {
            print("Error cargando citas: \(error.localizedDescription)")
            return []
        }
    }
    
    private func loadNotes() async -> [Note] {
        do {
            // Cargar notas para este paciente
            return try await FirebaseService.shared.getNotesForPatient(patientId: patient.id)
        } catch {
            print("Error cargando notas: \(error.localizedDescription)")
            return []
        }
    }
}

// Componente para mostrar información del paciente
struct PatientInfoBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.1))
        )
    }
}

struct MyPatientsView_Previews: PreviewProvider {
    static var previews: some View {
        MyPatientsView()
            .environmentObject(UserViewModel())
    }
}
