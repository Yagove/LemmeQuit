//
//  MainTherapistView.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//
import Foundation
import SwiftUI
import AVFoundation
import Speech
import Combine
import FirebaseAuth

struct MainTherapistView: View {
    // ViewModels
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var userVM: UserViewModel
    @StateObject private var voiceRecorderVM = VoiceRecorderViewModel()
    
    // Estados de navegación
    @State private var showCalendarView = false
    @State private var showPatientsView = false
    @State private var showNotesView = false
    @State private var showSettingsView = false
    @State private var showWhoamiView = false
    
    // Estados de UI
    @State private var selectedPatientName: String = "Ninguno seleccionado"
    @State private var showPatientPicker = false
    @State private var showTranscriptionSuccess = false
    
    // Propiedades computadas
    private var currentUser: User? {
        userVM.currentUser
    }
    
    private var userName: String {
        currentUser?.name ?? "Terapeuta"
    }
    
    private var selectedPatient: User? {
        userVM.selectedPatient
    }
    
    private var recordButtonColor: Color {
        voiceRecorderVM.isRecording ? Color.red : Color.green
    }
    
    var body: some View {
        ZStack {
            // Fondo
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 15) {
                // Header con saludo y paciente seleccionado
                headerView
                
                // Botón principal de grabación de voz
                voiceRecorderButton
                    .padding(.vertical, 20)
                
                // Botones de navegación
                navigationButtonsRow
                    .padding(.horizontal)
                
                Spacer()
                
                // Footer con ajustes y perfil
                footerView
                    .padding(.horizontal)
                    .padding(.bottom, 5)
            }
            .padding(.top, 20)
            
            // Toast de transcripción exitosa
            if showTranscriptionSuccess {
                transcriptionSuccessToast
            }
        }
        .onAppear {
            setupView()
            voiceRecorderVM.checkPermissions()
        }
        // Modales
        .sheet(isPresented: $showCalendarView) {
            CalendarTView()
                .environmentObject(userVM)
        }
        .sheet(isPresented: $showPatientsView) {
            MyPatientsView()
                .environmentObject(userVM)
        }
        .sheet(isPresented: $showNotesView) {
            NotesView()
                .environmentObject(userVM)
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView()
                .environmentObject(authVM)
                .environmentObject(userVM)
        }
        .sheet(isPresented: $showWhoamiView) {
            WhoamiView()
                .environmentObject(authVM)
                .environmentObject(userVM)
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: userVM.selectedPatient) { newValue in
            if let patient = newValue {
                selectedPatientName = patient.name
            } else {
                selectedPatientName = "Ninguno seleccionado"
            }
        }
    }
    
    // MARK: - Componentes de UI
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Hola,")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text(userName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Contador de pacientes
                
                if !userVM.patientsList.isEmpty {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.green)
                        
                        Text("\(userVM.patientsList.count) paciente\(userVM.patientsList.count != 1 ? "s" : "")")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .stroke(Color.green, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            
            // Selector de paciente activo
            patientSelector
        }
    }
    
    private var patientSelector: some View {
        Button(action: {
            showPatientPicker.toggle()
        }) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.green)
                
                Text("Paciente: \(selectedPatientName)")
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal)
        }
        .actionSheet(isPresented: $showPatientPicker) {
            ActionSheet(
                title: Text("Seleccionar paciente"),
                buttons: userVM.patientsList.isEmpty
                    ? [.cancel(Text("Cancelar"))]
                    : createPatientButtons()
            )
        }
    }
    
    private func createPatientButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        
        // Añadir botón para cada paciente
        for patient in userVM.patientsList {
            buttons.append(.default(Text(patient.name)) {
                userVM.selectPatient(patient)
            })
        }
        
        // Añadir botón para deseleccionar
        buttons.append(.destructive(Text("Ninguno")) {
            userVM.selectedPatient = nil
            selectedPatientName = "Ninguno seleccionado"
        })
        
        // Añadir botón de cancelar
        buttons.append(.cancel(Text("Cancelar")))
        
        return buttons
    }
    
    private var voiceRecorderButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: voiceRecorderVM.isRecording
                                ? [Color.red, Color.red.opacity(0.7)]
                                : [Color.green, Color.green.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 220)
                    .shadow(color: recordButtonColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                
                if voiceRecorderVM.isRecording {
                    // Visualización del audio mientras graba
                    ForEach(0..<6) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white)
                            .frame(width: 6, height: 20 + CGFloat.random(in: 5...40))
                            .offset(x: CGFloat(i * 10) - 25)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(i) * 0.05),
                                value: voiceRecorderVM.isRecording
                            )
                    }
                }
                
                VStack(spacing: 12) {
                    Image(systemName: voiceRecorderVM.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    Text(voiceRecorderVM.isRecording ? "Grabando..." : "Grabar nota de voz")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if voiceRecorderVM.isRecording {
                        // Temporizador
                        Text(voiceRecorderVM.formattedRecordingTime)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 5)
                    } else {
                        Text("Pulsa para grabar una nota")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .disabled(selectedPatient == nil || !voiceRecorderVM.hasPermissions)
        .opacity(selectedPatient == nil || !voiceRecorderVM.hasPermissions ? 0.5 : 1.0)
        .overlay(
            Group {
                if !voiceRecorderVM.hasPermissions {
                    VStack {
                        Text("Se requieren permisos de micrófono")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                    }
                    .offset(y: 120)
                } else if selectedPatient == nil {
                    VStack {
                        Text("Selecciona un paciente primero")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                    }
                    .offset(y: 120)
                }
            }
        )
    }
    
    private var navigationButtonsRow: some View {
        HStack(spacing: 30) {
            NavigationButton(
                title: "Calendario",
                systemImage: "calendar",
                action: { showCalendarView = true }
            )
            
            NavigationButton(
                title: "Pacientes",
                systemImage: "person.3.fill",
                action: { showPatientsView = true }
            )
            
            NavigationButton(
                title: "Notas",
                systemImage: "note.text",
                action: { showNotesView = true }
            )
        }
        .padding(.top, 20)
    }
    
    private var footerView: some View {
        HStack {
            // Botón de configuración
            Button(action: { showSettingsView = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.primary.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Botón de perfil
            Button(action: { showWhoamiView = true }) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.primary.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }
    
    private var transcriptionSuccessToast: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nota guardada correctamente")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Se ha transcrito y guardado tu nota de voz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 0)
            )
            .padding(.horizontal)
            .padding(.bottom, 80)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Métodos
    
    private func setupView() {
        // Si no hay usuario actual, cargarlo
        if currentUser == nil {
            if let firebaseUserId = authVM.currentUser?.id ?? Auth.auth().currentUser?.uid {
                Task {
                    do {
                        if let userData = try await FirebaseService.shared.getUserData(userId: firebaseUserId) {
                            await MainActor.run {
                                userVM.currentUser = userData
                                
                                // Cargar datos de pacientes si es terapeuta
                                if userData.role == .therapist {
                                    loadPatients(userId: userData.id)
                                }
                            }
                        }
                    } catch {
                        print("Error cargando usuario: \(error.localizedDescription)")
                    }
                }
            }
        } else if currentUser?.role == .therapist {
            // Cargar pacientes para terapeuta
            loadPatients(userId: currentUser!.id)
        }
    }
    
    private func loadPatients(userId: String) {
        Task {
            do {
                let patients = try await FirebaseService.shared.getPatientsForTherapist(therapistId: userId)
                await MainActor.run {
                    userVM.patientsList = patients
                }
            } catch {
                print("Error cargando pacientes: \(error.localizedDescription)")
            }
        }
    }
    
    private func toggleRecording() {
        guard let patient = selectedPatient else { return }
        
        if voiceRecorderVM.isRecording {
            // Detener grabación
            voiceRecorderVM.stopRecording { success, url, transcription in
                if success, let url = url, let transcription = transcription {
                    saveTranscribedNote(patientId: patient.id, url: url, transcription: transcription)
                }
            }
        } else {
            // Iniciar grabación
            voiceRecorderVM.startRecording()
        }
    }
    
    private func saveTranscribedNote(patientId: String, url: URL, transcription: String) {
        guard let userId = currentUser?.id else { return }
        
        Task {
            do {
                // Crear una nota de voz transcrita
                let voiceNote = Note.createVoiceNote(
                    title: "Nota de voz",
                    transcription: transcription,
                    userId: userId,
                    patientId: patientId,
                    voiceUrl: url.absoluteString
                )
                
                // Guardar en Firebase
                let _ = try await FirebaseService.shared.saveNote(voiceNote)
                
                // Mostrar toast de éxito
                await MainActor.run {
                    withAnimation {
                        showTranscriptionSuccess = true
                    }
                    
                    // Ocultar después de 3 segundos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showTranscriptionSuccess = false
                        }
                    }
                }
            } catch {
                print("Error guardando nota transcrita: \(error.localizedDescription)")
            }
        }
    }
}

// Componente de botón de navegación
struct NavigationButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// ViewModel para grabadora de voz
class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var hasPermissions = false
    @Published var recordingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private var recordingTimer: Timer?
    private var currentTranscription = ""
    
    var formattedRecordingTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func checkPermissions() {
        // Verificar permisos de micrófono
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermissions = granted
            }
        }
        
        // Verificar permisos de reconocimiento de voz
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.hasPermissions = self?.hasPermissions ?? false && (status == .authorized)
            }
        }
    }
    
    func startRecording() {
        guard hasPermissions else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error configuring audio session: \(error.localizedDescription)")
            return
        }
        
        // Configurar ruta del archivo
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
        
        // Configurar grabación
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            // Iniciar reconocimiento de voz
            startSpeechRecognition()
            
            isRecording = true
            recordingTime = 0
            
            // Iniciar temporizador
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingTime += 1
            }
            
        } catch {
            print("Error starting recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording(completion: @escaping (Bool, URL?, String?) -> Void) {
        // Detener grabador de audio
        audioRecorder?.stop()
        let recordingURL = audioRecorder?.url
        
        // Detener reconocimiento de voz
        stopSpeechRecognition()
        
        // Detener temporizador
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Resetear estado
        isRecording = false
        
        // Añadir a lista de grabaciones
        if let url = recordingURL {
            recordings.append(url)
            completion(true, url, currentTranscription)
        } else {
            completion(false, nil, nil)
        }
        
        // Reiniciar transcripción
        currentTranscription = ""
    }
    
    private func startSpeechRecognition() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.currentTranscription = result.bestTranscription.formattedString
            }
            
            if error != nil {
                print("Recognition error: \(String(describing: error))")
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
    }
    
    private func stopSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
    }
}

// Estilo de botón con animación de escala
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct MainTherapistView_Previews: PreviewProvider {
    static var previews: some View {
        MainTherapistView()
            .environmentObject(AuthViewModel())
            .environmentObject(UserViewModel())
    }
}
