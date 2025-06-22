//
//  CalendarView.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//
import SwiftUI
import FirebaseFirestore

struct CalendarPView: View {
    // Propiedades del estado
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate: Date = Date()
    @State private var notes: [Note] = []
    @State private var appointments: [Appointment] = []
    @State private var showAddNoteSheet: Bool = false
    @State private var showAddReminderSheet: Bool = false
    @State private var stressPressCounts: [Date: Int] = [:]
    @State private var loggedInDates: Set<Date> = []
    @State private var isLoading: Bool = false
    
    // Propiedades computadas
    private var notesForSelectedDate: [Note] {
        notes.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .filter { !$0.isButtonPress && !$0.isVoiceNote }
    }
    
    private var appointmentsForSelectedDate: [Appointment] {
        appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    private var stressCountForSelectedDate: Int {
        stressPressCounts[normalizeDate(selectedDate)] ?? 0
    }
    
    private var hasSessionForSelectedDate: Bool {
        loggedInDates.contains(normalizeDate(selectedDate))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Calendario
                    calendarSection
                    
                    // Métricas del día
                    metricsSection
                    
                    // Botones de acción
                    actionButtonsSection
                    
                    // Contenido del día seleccionado
                    ScrollView {
                        VStack(spacing: 20) {
                            notesSection
                            remindersSection
                            episodesSection
                        }
                        .padding(.vertical)
                    }
                }
                
                // Loading overlay
                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Mi Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    todayIndicator
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showAddNoteSheet) {
                AddNoteView()
                    .environmentObject(userVM)
                    .onDisappear { loadData() }
            }
            .sheet(isPresented: $showAddReminderSheet) {
                AddReminderView()
                    .environmentObject(userVM)
                    .onDisappear { loadData() }
            }
        }
    }
    
    // MARK: - Subcomponentes de la vista
    
    private var calendarSection: some View {
        DatePicker(
            "Selecciona una fecha",
            selection: $selectedDate,
            displayedComponents: .date
        )
        .datePickerStyle(GraphicalDatePickerStyle())
        .accentColor(.blue)
        .padding()
    }
    
    private var metricsSection: some View {
        HStack(spacing: 20) {
            MetricCard(
                icon: "exclamationmark.triangle.fill",
                title: "Episodios",
                value: "\(stressCountForSelectedDate)",
                color: stressCountForSelectedDate > 0 ? .orange : .gray
            )
            
            MetricCard(
                icon: "checkmark.circle.fill",
                title: "Sesión registrada",
                value: hasSessionForSelectedDate ? "Sí" : "No",
                color: hasSessionForSelectedDate ? .green : .gray
            )
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                showAddNoteSheet = true
            }) {
                Label("Nueva Nota", systemImage: "square.and.pencil")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            Button(action: {
                showAddReminderSheet = true
            }) {
                Label("Recordatorio", systemImage: "bell.badge.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(
                title: "Notas",
                count: notesForSelectedDate.count,
                color: .blue
            )
            .padding(.horizontal)
            
            if notesForSelectedDate.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    message: "No hay notas para este día",
                    submessage: "Toca 'Nueva Nota' para añadir una"
                )
            } else {
                ForEach(notesForSelectedDate) { note in
                    NoteCard(note: note)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(
                title: "Recordatorios",
                count: appointmentsForSelectedDate.count,
                color: .orange
            )
            .padding(.horizontal)
            
            if appointmentsForSelectedDate.isEmpty {
                EmptyStateView(
                    icon: "bell",
                    message: "No hay recordatorios para este día",
                    submessage: "Toca 'Recordatorio' para añadir uno"
                )
            } else {
                ForEach(appointmentsForSelectedDate) { appointment in
                    ReminderCard(appointment: appointment)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        if stressCountForSelectedDate > 0 {
            VStack(alignment: .leading, spacing: 15) {
                SectionHeader(
                    title: "Episodios registrados",
                    count: stressCountForSelectedDate,
                    color: .orange
                )
                .padding(.horizontal)
                
                EpisodeCard(count: stressCountForSelectedDate)
                    .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var todayIndicator: some View {
        if Calendar.current.isDateInToday(selectedDate) {
            Text("Hoy")
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
        }
    }
    
    private var loadingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            )
    }
    
    // MARK: - Métodos
    
    func normalizeDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    private func loadData() {
        guard let userId = userVM.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // 1. Cargar todas las notas del usuario
                let allNotes = try await FirebaseService.shared.getNotesForUser(userId: userId)
                
                // 2. Cargar todos los appointments del usuario
                let allAppointments = try await FirebaseService.shared.getAppointmentsForUser(userId: userId)
                
                // 3. Calcular las pulsaciones de estrés por día (últimos 30 días)
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                let buttonPressNotes = allNotes.filter {
                    $0.isButtonPress && $0.date >= thirtyDaysAgo
                }
                
                var counts: [Date: Int] = [:]
                for note in buttonPressNotes {
                    let normalizedDate = normalizeDate(note.date)
                    counts[normalizedDate, default: 0] += 1
                }
                
                // 4. Simular fechas de inicio de sesión
                let loggedInDatesArray = Array(0..<30).compactMap { index -> Date? in
                    let today = Date()
                    return Calendar.current.date(byAdding: .day, value: -index, to: today)
                }.map { normalizeDate($0) }
                
                // 5. Actualizar la UI en el hilo principal
                await MainActor.run {
                    self.notes = allNotes
                    self.appointments = allAppointments
                    self.stressPressCounts = counts
                    self.loggedInDates = Set(loggedInDatesArray)
                    self.isLoading = false
                }
            } catch {
                print("Error cargando datos del calendario: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Componentes auxiliares

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 3, x: 0, y: 2)
        )
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(color)
                )
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String
    let submessage: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Text(submessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
        .padding(.horizontal)
    }
}

struct NoteCard: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text.badge.plus")
                    .foregroundColor(.blue)
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(note.date, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "quote.bubble.fill")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.3))
            }
            
            Text(note.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ReminderCard: View {
    let appointment: Appointment
    
    private func appointmentIconFor(_ type: Appointment.AppointmentType) -> String {
        switch type {
        case .therapy: return "person.2.fill"
        case .medication: return "pill.fill"
        case .generalNote: return "bell.fill"
        }
    }
    
    private func appointmentColorFor(_ type: Appointment.AppointmentType) -> Color {
        switch type {
        case .therapy: return .green
        case .medication: return .blue
        case .generalNote: return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: appointmentIconFor(appointment.appointmentType))
                .font(.title2)
                .foregroundColor(appointmentColorFor(appointment.appointmentType))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(appointmentColorFor(appointment.appointmentType).opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let notes = appointment.notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(appointment.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Image(systemName: "bell.badge")
                    .font(.caption)
                    .foregroundColor(appointmentColorFor(appointment.appointmentType))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(appointmentColorFor(appointment.appointmentType).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(appointmentColorFor(appointment.appointmentType).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct EpisodeCard: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Episodios registrados")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Has registrado \(count) episodio\(count > 1 ? "s" : "") este día")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct CalendarPView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarPView()
            .environmentObject(UserViewModel())
    }
}
