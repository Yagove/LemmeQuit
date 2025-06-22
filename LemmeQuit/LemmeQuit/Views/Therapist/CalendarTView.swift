//
//  CalendarTView.swift
//  LemmeQuit
//
//  Created by Yako on 10/4/25.
//
import SwiftUI
import FirebaseFirestore

struct CalendarTView: View {
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate = Date()
    @State private var appointments: [Appointment] = []
    @State private var patientNotes: [Note] = []
    @State private var selectedPatientFilter: User?
    @State private var showAddAppointmentSheet = false
    @State private var isLoading = false
    @State private var newAppointmentTitle = ""
    @State private var newAppointmentTime = Date()
    @State private var selectedPatientForAppointment: User?
    
    // Propiedades computadas
    private var appointmentsForSelectedDate: [Appointment] {
        appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    private var notesForSelectedDate: [Note] {
        let filteredNotes = patientNotes.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        
        if let selectedPatient = selectedPatientFilter {
            return filteredNotes.filter { $0.userId == selectedPatient.id }
        }
        return filteredNotes
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Selector de paciente (filtro)
                    if !userVM.patientsList.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Filtrar por paciente")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Picker("Paciente", selection: $selectedPatientFilter) {
                                Text("Todos los pacientes").tag(nil as User?)
                                
                                ForEach(userVM.patientsList) { patient in
                                    Text(patient.name).tag(patient as User?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                    
                    // Calendario
                    DatePicker(
                        "Seleccionar fecha",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    
                    // Botón principal para crear cita - ÚNICA FORMA
                    Button(action: {
                        showAddAppointmentSheet = true
                    }) {
                        Label("Nueva Cita", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(userVM.patientsList.isEmpty)
                    
                    if userVM.patientsList.isEmpty {
                        Text("Necesitas tener pacientes asignados para crear citas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    // Contenido para la fecha seleccionada
                    ScrollView {
                        VStack(spacing: 20) {
                            // Sección de citas
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Citas para \(selectedDate, format: .dateTime.day().month().year())")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text("\(appointmentsForSelectedDate.count)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.green.opacity(0.1))
                                        )
                                }
                                .padding(.horizontal)
                                
                                if appointmentsForSelectedDate.isEmpty {
                                    VStack(spacing: 10) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 40))
                                            .foregroundColor(.secondary)
                                        
                                        Text("No hay citas para este día")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                } else {
                                    ForEach(appointmentsForSelectedDate) { appointment in
                                        AppointmentCard(appointment: appointment, onDelete: {
                                            deleteAppointment(appointment)
                                        })
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Sección de notas de pacientes
                            if !userVM.patientsList.isEmpty {
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Text("Notas de pacientes")
                                            .font(.headline)
                                        
                                        Spacer()
                                        
                                        if let selectedPatient = selectedPatientFilter {
                                            Text(selectedPatient.name)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue.opacity(0.1))
                                                )
                                        } else {
                                            Text("\(notesForSelectedDate.count)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue.opacity(0.1))
                                                )
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    if notesForSelectedDate.isEmpty {
                                        VStack(spacing: 10) {
                                            Image(systemName: "note.text")
                                                .font(.system(size: 30))
                                                .foregroundColor(.secondary)
                                            
                                            Text("No hay notas de pacientes para este día")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                    } else {
                                        ForEach(notesForSelectedDate) { note in
                                            PatientNoteCard(
                                                note: note,
                                                patientName: getPatientName(for: note.userId)
                                            )
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
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
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                // Información en lugar de botón duplicado
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !userVM.patientsList.isEmpty {
                        Text("👥 \(userVM.patientsList.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        EmptyView()
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showAddAppointmentSheet) {
                loadData() // Recargar datos cuando se cierre
            } content: {
                addAppointmentView
            }
        }
    }
    
    // Vista para añadir nueva cita - ÚNICA FORMA
    private var addAppointmentView: some View {
        NavigationView {
            Form {
                Section(header: Text("Nueva Cita")) {
                    TextField("¿Qué tipo de sesión?", text: $newAppointmentTitle)
                        .textInputAutocapitalization(.sentences)
                    
                    DatePicker("Hora", selection: $newAppointmentTime, displayedComponents: .hourAndMinute)
                    
                    Picker("Paciente", selection: $selectedPatientForAppointment) {
                        Text("Selecciona un paciente").tag(nil as User?)
                        
                        ForEach(userVM.patientsList) { patient in
                            Text(patient.name).tag(patient as User?)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                if let selectedPatient = selectedPatientForAppointment {
                    Section(header: Text("Detalles")) {
                        HStack {
                            Text("Paciente:")
                            Spacer()
                            Text(selectedPatient.name)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Fecha:")
                            Spacer()
                            Text(selectedDate, format: .dateTime.day().month().year())
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Hora:")
                            Spacer()
                            Text(newAppointmentTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: addAppointment) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Crear Cita")
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    }
                    .disabled(newAppointmentTitle.isEmpty || selectedPatientForAppointment == nil)
                }
            }
            .navigationTitle("Nueva Cita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        showAddAppointmentSheet = false
                        resetForm()
                    }
                }
            }
        }
    }
    
    // MARK: - Métodos
    
    private func loadData() {
        guard let userId = userVM.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // Cargar citas del terapeuta
                let fetchedAppointments = try await FirebaseService.shared.getAppointmentsForUser(userId: userId)
                
                // Cargar notas de todos los pacientes
                var allPatientNotes: [Note] = []
                for patient in userVM.patientsList {
                    let notes = try await FirebaseService.shared.getNotesForUser(userId: patient.id)
                    allPatientNotes.append(contentsOf: notes)
                }
                
                await MainActor.run {
                    self.appointments = fetchedAppointments.sorted { $0.date < $1.date }
                    self.patientNotes = allPatientNotes.sorted { $0.date > $1.date }
                    self.isLoading = false
                }
            } catch {
                print("Error cargando datos: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addAppointment() {
        guard let therapistId = userVM.currentUser?.id,
              let patient = selectedPatientForAppointment,
              !newAppointmentTitle.isEmpty else {
            return
        }
        
        // Combinar la fecha seleccionada con la hora seleccionada
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: newAppointmentTime)
        
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        guard let combinedDate = Calendar.current.date(from: dateComponents) else {
            return
        }
        
        // Crear nueva cita
        let newAppointment = Appointment(
            title: newAppointmentTitle,
            date: combinedDate,
            userId: therapistId,
            relatedUserId: patient.id,
            notes: "Cita con \(patient.name)",
            appointmentType: .therapy
        )
        
        isLoading = true
        
        Task {
            do {
                // Guardar cita en Firebase
                let _ = try await FirebaseService.shared.saveAppointment(newAppointment)
                
                // Crear cita espejo para el paciente
                let patientAppointment = Appointment(
                    title: "Cita con \(userVM.currentUser?.name ?? "Terapeuta")",
                    date: combinedDate,
                    userId: patient.id,
                    relatedUserId: therapistId,
                    notes: newAppointmentTitle,
                    appointmentType: .therapy
                )
                
                // Guardar cita espejo
                let _ = try await FirebaseService.shared.saveAppointment(patientAppointment)
                
                await MainActor.run {
                    self.isLoading = false
                    self.showAddAppointmentSheet = false
                    self.resetForm()
                    // Recargar citas
                    self.loadData()
                }
            } catch {
                print("Error guardando cita: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func deleteAppointment(_ appointment: Appointment) {
        isLoading = true
        
        Task {
            do {
                // Eliminar la cita
                try await FirebaseService.shared.deleteAppointment(id: appointment.id)
                
                // Si hay un usuario relacionado, eliminar también su cita
                if let relatedUserId = appointment.relatedUserId {
                    // Obtener citas del usuario relacionado para la misma fecha
                    let relatedAppointments = try await FirebaseService.shared.getAppointmentsForDate(
                        userId: relatedUserId,
                        date: appointment.date
                    )
                    
                    // Buscar la cita espejo
                    for relatedAppointment in relatedAppointments where relatedAppointment.relatedUserId == appointment.userId {
                        try await FirebaseService.shared.deleteAppointment(id: relatedAppointment.id)
                        break
                    }
                }
                
                await MainActor.run {
                    // Eliminar la cita de la lista local
                    self.appointments.removeAll { $0.id == appointment.id }
                    self.isLoading = false
                }
            } catch {
                print("Error eliminando cita: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func resetForm() {
        newAppointmentTitle = ""
        newAppointmentTime = Date()
        selectedPatientForAppointment = nil
    }
    
    private func getPatientName(for userId: String) -> String {
        return userVM.patientsList.first { $0.id == userId }?.name ?? "Paciente desconocido"
    }
}

// Componente de tarjeta de cita (simplificado)
struct AppointmentCard: View {
    let appointment: Appointment
    let onDelete: () -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicador de hora
            VStack {
                Text(timeFormatter.string(from: appointment.date))
                    .font(.headline)
                    .foregroundColor(.green)
                
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            .frame(width: 60)
            
            // Contenido de la cita
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let notes = appointment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Sesión de terapia")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Botón de eliminar
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.1))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(radius: 2)
        )
    }
}

// Componente para mostrar notas de pacientes (sin cambios)
struct PatientNoteCard: View {
    let note: Note
    let patientName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Tipo de nota
                Image(systemName: iconForNoteType(note.noteType))
                    .foregroundColor(colorForNoteType(note.noteType))
                
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(note.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Nombre del paciente
            Text("Por: \(patientName)")
                .font(.caption)
                .foregroundColor(.blue)
                .fontWeight(.medium)
            
            // Contenido de la nota
            Text(note.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            // Indicadores especiales
            HStack {
                if note.isButtonPress {
                    Label("Episodio", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if note.isVoiceNote {
                    Label("Nota de voz", systemImage: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                Text(noteTypeDescription(note.noteType))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(colorForNoteType(note.noteType).opacity(0.1))
                    )
                    .foregroundColor(colorForNoteType(note.noteType))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(radius: 2)
        )
    }
    
    private func iconForNoteType(_ type: Note.NoteType) -> String {
        switch type {
        case .general: return "note.text"
        case .therapy: return "person.2"
        case .addiction: return "exclamationmark.triangle.fill"
        case .medication: return "pill.fill"
        case .transcription: return "mic.fill"
        }
    }
    
    private func colorForNoteType(_ type: Note.NoteType) -> Color {
        switch type {
        case .general: return .blue
        case .therapy: return .green
        case .addiction: return .orange
        case .medication: return .purple
        case .transcription: return .cyan
        }
    }
    
    private func noteTypeDescription(_ type: Note.NoteType) -> String {
        switch type {
        case .general: return "General"
        case .therapy: return "Terapia"
        case .addiction: return "Adicción"
        case .medication: return "Medicación"
        case .transcription: return "Transcripción"
        }
    }
}

struct CalendarTView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarTView()
            .environmentObject(UserViewModel())
    }
}
