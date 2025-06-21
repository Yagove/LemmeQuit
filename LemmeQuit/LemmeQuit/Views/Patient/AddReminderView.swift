//
//  AddReminder.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//

import SwiftUI
import FirebaseFirestore
import UserNotifications

struct AddReminderView: View {
    // Propiedades del entorno
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    // Estado local
    @State private var reminderTitle: String = ""
    @State private var selectedDate: Date = Date()
    @State private var reminderTime = Date()
    @State private var isLoading = false
    @State private var showDatePicker = false
    @State private var reminderType: ReminderType = .medication
    @State private var showNotificationWarning = false
    
    // Tipos de recordatorio
    enum ReminderType: String, CaseIterable, Identifiable {
        case medication = "Medicación"
        case appointment = "Cita"
        case other = "Otro"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .medication: return "pill.fill"
            case .appointment: return "calendar.badge.clock"
            case .other: return "bell.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .medication: return .blue
            case .appointment: return .green
            case .other: return .orange
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Selector de fecha
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fecha")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Button(action: {
                                withAnimation {
                                    showDatePicker.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                    
                                    Text(selectedDate, format: .dateTime.day().month().year())
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                            
                            if showDatePicker {
                                DatePicker(
                                    "Seleccionar fecha",
                                    selection: $selectedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // Tipo de recordatorio
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tipo de recordatorio")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Picker("Tipo", selection: $reminderType) {
                                ForEach(ReminderType.allCases) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                            .foregroundColor(type.color)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                        }
                        
                        // Campo de texto para el recordatorio
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Descripción")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            TextField("Escribe tu recordatorio aquí", text: $reminderTitle)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal)
                        }
                        
                        // Selector de hora
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hora")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            DatePicker(
                                "Hora del recordatorio",
                                selection: $reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Información sobre notificaciones
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: "bell.badge")
                                    .foregroundColor(.orange)
                                
                                Text("Recibirás una notificación a la hora seleccionada")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            if showNotificationWarning {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    
                                    Text("Debes permitir notificaciones en la configuración de tu dispositivo para recibir alertas")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                        
                        Spacer()
                        
                        // Botón de guardar
                        Button(action: saveReminder) {
                            Text("Guardar Recordatorio")
                                .fontWeight(.semibold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(reminderTitle.isEmpty ? Color.gray.opacity(0.5) : reminderType.color)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .disabled(reminderTitle.isEmpty || isLoading)
                        .opacity(reminderTitle.isEmpty ? 0.5 : 1)
                        .padding(.bottom)
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
            .navigationTitle("Nuevo Recordatorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
        }
    }
    
    // MARK: - Métodos
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus != .authorized {
                    self.showNotificationWarning = true
                }
            }
        }
    }
    
    private func saveReminder() {
        guard let userId = userVM.currentUser?.id, !reminderTitle.isEmpty else {
            return
        }
        
        isLoading = true
        
        // Combinar fecha y hora
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        guard let combinedDate = Calendar.current.date(from: dateComponents) else {
            isLoading = false
            return
        }
        
        // Determinar el tipo de cita según el tipo de recordatorio
        let appointmentType: Appointment.AppointmentType = {
            switch reminderType {
            case .medication: return .medication
            case .appointment: return .therapy
            case .other: return .generalNote
            }
        }()
        
        // Crear una cita/recordatorio
        let appointment = Appointment(
            title: reminderTitle,
            date: combinedDate,
            userId: userId,
            notes: "Recordatorio agregado el \(Date().formatted(date: .long, time: .shortened))",
            reminderSet: true,
            appointmentType: appointmentType
        )
        
        Task {
            do {
                // Guardar en Firebase
                let _ = try await FirebaseService.shared.saveAppointment(appointment)
                
                // Programar notificación local
                scheduleReminderNotification(title: reminderTitle, date: combinedDate, type: reminderType)
                
                // Cerrar vista
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("Error guardando recordatorio: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func scheduleReminderNotification(title: String, date: Date, type: ReminderType) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Recordatorio: \(type.rawValue)"
                content.body = title
                content.sound = .default
                
                // Icono según el tipo
                content.categoryIdentifier = type.rawValue
                
                // Crear el trigger para la fecha exacta
                let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                
                // Crear la solicitud
                let identifier = UUID().uuidString
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                // Programar la notificación
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error al programar notificación: \(error.localizedDescription)")
                    }
                }
            } else {
                print("Permiso de notificación denegado")
            }
        }
    }
}

struct AddReminderView_Previews: PreviewProvider {
    static var previews: some View {
        AddReminderView()
            .environmentObject(UserViewModel())
    }
}
