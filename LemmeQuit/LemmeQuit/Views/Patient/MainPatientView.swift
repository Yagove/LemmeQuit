//
//  MainView.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//
import Network
import SwiftUI
import Combine
import FirebaseAuth

struct MainPatientView: View {
    // ViewModels
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var userVM: UserViewModel
    @StateObject private var chatGPTVM = ChatGPTViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    
    // Estados para las vistas modales
    @State private var showCalendarView = false
    @State private var showAddNoteView = false
    @State private var showAddTherapistView = false
    @State private var showSettingsView = false
    @State private var showWhoamiView = false
    @State private var showAIAdviceToast = false
    
    // Estados para animaciones del botón de emergencia
    @State private var buttonPressAnimating = false
    @State private var showButtonPressSuccess = false
    @State private var buttonPressDisabled = false
    @State private var buttonPressTimer: Timer?
    @State private var progress: CGFloat = 0.0
    @State private var daysInRecovery: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    // Propiedades computadas
    private var currentUser: User? {
        userVM.currentUser
    }
    
    private var userName: String {
        currentUser?.name ?? "Paciente"
    }
    
    private var buttonStyle: some ShapeStyle {
        LinearGradient(
            colors: [.blue, .blue.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Timer para la animación del botón
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        ZStack {
            // Fondo
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 15) {
                // Header con saludo
                headerView
                
                // Botón central
                emergencyButton
                    .padding(.vertical, 20)
                
                // Botones de navegación
                navigationButtonsRow
                    .padding(.horizontal)
                
                // Barra de progreso
                progressView
                    .padding(.horizontal)
                
                Spacer()
                
                // Footer con ajustes y perfil
                footerView
                    .padding(.horizontal)
                    .padding(.bottom, 5)
            }
            .padding(.top, 20)
            
            // Toast de consejo IA
            ToastAIView(
                isPresented: $showAIAdviceToast,
                message: chatGPTVM.currentResponse,
                isLoading: chatGPTVM.isLoading
            )
            
            // Toast de éxito al pulsar botón
            if showButtonPressSuccess {
                buttonPressSuccessToast
            }
        }
        .onAppear {
            setupView()
        }
        // Modales
        .sheet(isPresented: $showCalendarView) {
            CalendarPView()
                .environmentObject(userVM)
        }
        .sheet(isPresented: $showAddNoteView) {
            AddNoteView()
                .environmentObject(userVM)
        }
        .sheet(isPresented: $showAddTherapistView) {
            AddTherapistView()
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
    }
    
    // MARK: - Componentes de UI
    
    private var headerView: some View {
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
            
            // Indicador de conexión - AÑADE ESTO
            HStack {
                Circle()
                    .fill(networkMonitor.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(networkMonitor.isConnected ? "Conectado" : "Sin conexión")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Si tiene terapeuta asignado, muestra un badge
            if userVM.hasTherapist {
                HStack {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .foregroundColor(.green)
                    
                    Text("Acompañado")
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
    }
    
    private var emergencyButton: some View {
        Button(action: handleEmergencyButtonPress) {
            ZStack {
                Circle()
                    .fill(buttonStyle)
                    .frame(height: 220)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                if buttonPressAnimating {
                    // Onda animada
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                            .scaleEffect(scale + CGFloat(i) * 0.1)
                            .opacity(0.5 - Double(i) * 0.15)
                            .animation(
                                Animation.easeOut(duration: 1)
                                    .repeatCount(3, autoreverses: false)
                                    .delay(Double(i) * 0.2),
                                value: scale
                            )
                    }
                }
                
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    Text("¡Necesito ayuda!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(buttonPressDisabled ? "Disponible en 1 hora" : "Pulsa cuando sientas\nimpulsos negativos")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .disabled(buttonPressDisabled)
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var navigationButtonsRow: some View {
        HStack(spacing: 30) {
            NavigationButton(
                title: "Calendario",
                systemImage: "calendar",
                action: { showCalendarView = true }
            )
            
            NavigationButton(
                title: "Añadir Nota",
                systemImage: "plus.square.fill",
                action: { showAddNoteView = true }
            )
            
            NavigationButton(
                title: "Terapeuta",
                systemImage: "person.2.fill",
                action: { showAddTherapistView = true }
            )
        }
        .padding(.top, 20)
    }
    
    private var progressView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Día \(daysInRecovery) de recuperación")
                    .font(.headline)
                
                Spacer()
                
                // Botón para obtener consejos de IA
                Button(action: requestAIAdvice) {
                    HStack {
                        Image(systemName: "brain")
                        Text("IAdvice")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(chatGPTVM.isLoading ? Color.gray : Color.purple)
                    )
                }
                .disabled(chatGPTVM.isLoading)
            }
            
            // Barra de progreso
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fondo
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 15)
                    
                    // Progreso
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(CGFloat(progress) * geometry.size.width, geometry.size.width)), height: 15)
                }
            }
            .frame(height: 15)
            
            Text("¡Mantén tu progreso!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
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
    
    private var buttonPressSuccessToast: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Episodio registrado")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("¡Ánimo! Lo estás haciendo bien")
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
    
    // MARK: - Funciones
    
    private func setupView() {
        // Si no hay usuario actual, cargarlo
        if currentUser == nil && Auth.auth().currentUser != nil {
            // Cargar usuario directamente desde Firebase
            if let firebaseUserId = Auth.auth().currentUser?.uid {
                Task {
                    do {
                        if let userData = try await FirebaseService.shared.getUserData(userId: firebaseUserId) {
                            await MainActor.run {
                                userVM.currentUser = userData
                            }
                        }
                    } catch {
                        print("Error cargando usuario: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        calculateProgress()
        calculateDaysInRecovery()
        feedbackGenerator.prepare()
    }
    
    private func calculateProgress() {
        // 30 días es el objetivo inicial
        let targetDays: CGFloat = 30
        progress = min(CGFloat(daysInRecovery) / targetDays, 1.0)
    }
    
    private func calculateDaysInRecovery() {
        // En una implementación real, debería calcular basado en datos de Firebase
        Task {
            guard let user = currentUser else { return }
            
            do {
                // Obtener todas las notas de "pulsación de botón" de los últimos 30 días
                let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                let buttonPressNotes = try await FirebaseService.shared.getButtonPressNotesForDate(
                    userId: user.id,
                    date: startDate
                )
                
                // Calcular días consecutivos sin pulsaciones
                // Aquí simplemente asignamos un valor simulado para la demo
                await MainActor.run {
                    daysInRecovery = max(1, 30 - buttonPressNotes.count)
                    calculateProgress()
                }
            } catch {
                print("Error al calcular los días: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleEmergencyButtonPress() {
        guard let user = currentUser, !buttonPressDisabled else { return }
        
        // Efecto de vibración
        feedbackGenerator.notificationOccurred(.warning)
        
        // Animación del botón
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 0.95
            buttonPressAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.05
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    scale = 1.0
                }
            }
        }
        
        // Registrar el evento en Firebase
        Task {
            do {
                // Crear una nota de "pulsación de botón"
                let buttonPressNote = Note.createButtonPressNote(userId: user.id)
                
                // Guardar en Firebase
                let _ = try await FirebaseService.shared.saveNote(buttonPressNote)
                
                // Mostrar mensaje de éxito
                await MainActor.run {
                    withAnimation {
                        showButtonPressSuccess = true
                    }
                    
                    // Deshabilitar el botón temporalmente (1 hora)
                    buttonPressDisabled = true
                    
                    // Ocultar mensaje después de unos segundos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showButtonPressSuccess = false
                        }
                    }
                    
                    // Habilitar el botón después de 1 hora
                    buttonPressTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: false) { _ in
                        buttonPressDisabled = false
                    }
                }
            } catch {
                print("Error al guardar el episodio: \(error.localizedDescription)")
            }
        }
    }
    
    private func requestAIAdvice() {
        print("🚀 === INICIANDO SOLICITUD DE IA ===")
        print("🌐 Estado de red: \(networkMonitor.isConnected ? "Conectado" : "Desconectado")")
        print("📶 Tipo de conexión: \(networkMonitor.connectionType)")
        
        // Ejecutar diagnósticos si hay problemas
        if !networkMonitor.isConnected {
            print("⚠️ No hay conexión de red, ejecutando diagnósticos...")
            runNetworkDiagnostics()
            return
        }
        
        guard let currentUser = currentUser else {
            print("❌ No hay usuario actual")
            return
        }
        
        // Ejecutar diagnósticos antes de la llamada normal
        print("🔍 Ejecutando diagnósticos preventivos...")
        runNetworkDiagnostics()
        
        // Continuar con la llamada normal después de un delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Task {
                await self.chatGPTVM.requestAdviceAsync(for: currentUser)
                await MainActor.run {
                    self.showAIAdviceToast = true
                }
            }
        }
    }
}

// MARK: - Componentes adicionales





struct ToastAIView: View {
    @Binding var isPresented: Bool
    var message: String
    var isLoading: Bool
    var errorMessage: String = ""
    
    var body: some View {
        ZStack {
            if isPresented {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                                .font(.title2)
                            
                            Text("IAdvice")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Divider()
                        
                        if isLoading {
                            HStack {
                                Spacer()
                                VStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Obteniendo consejo...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 5)
                                }
                                Spacer()
                            }
                            .padding()
                        } else if !errorMessage.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Error")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }
                                
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else if !message.isEmpty {
                            ScrollView {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                        } else {
                            // Modo debug: mostrar cuando no hay contenido
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundColor(.yellow)
                                    Text("Debug Info")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.yellow)
                                }
                                
                                Text("No se recibió respuesta de la IA")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Text("Estado: isLoading=\(isLoading ? "true" : "false")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Mensaje: '\(message)'")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Error: '\(errorMessage)'")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: isPresented)
                }
                .background(
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                isPresented = false
                            }
                        }
                )
            }
        }
        .animation(.easeInOut, value: isPresented)
        .onAppear {
            print("🎭 ToastAIView apareció con:")
            print("   - isPresented: \(isPresented)")
            print("   - message: '\(message)'")
            print("   - isLoading: \(isLoading)")
            print("   - errorMessage: '\(errorMessage)'")
        }
    }
}

// Placeholders para las vistas que faltan
struct AddTherapistView: View {
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Aquí podrás añadir un terapeuta")
                    .padding()
                
                // Se implementaría la funcionalidad completa
            }
            .navigationTitle("Añadir Terapeuta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}


struct MainPatientView_Previews: PreviewProvider {
    static var previews: some View {
        MainPatientView()
            .environmentObject(AuthViewModel())
            .environmentObject(UserViewModel())
    }
}


// Añade esta clase para monitorear la conectividad
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: String = "Desconocido"
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = "WiFi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = "Celular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = "Ethernet"
                } else {
                    self?.connectionType = "Desconocido"
                }
                
                print("🌐 Estado de red: \(self?.isConnected == true ? "Conectado" : "Desconectado")")
                print("📶 Tipo de conexión: \(self?.connectionType ?? "N/A")")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// Métodos de diagnóstico para añadir a MainPatientView
extension MainPatientView {
    
    // Diagnóstico completo de conectividad
    private func runNetworkDiagnostics() {
        print("🔍 === INICIANDO DIAGNÓSTICOS DE RED ===")
        
        Task {
            await testBasicConnectivity()
            await testDNSResolution()
            await testOpenAIEndpoint()
            await testAPIKeyFormat()
        }
    }
    
    // Test 1: Conectividad básica
    private func testBasicConnectivity() async {
        print("🌐 Test 1: Conectividad básica")
        
        do {
            let url = URL(string: "https://httpbin.org/get")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Conectividad básica OK - Código: \(httpResponse.statusCode)")
                print("📊 Datos recibidos: \(data.count) bytes")
            }
        } catch {
            print("❌ Error conectividad básica: \(error.localizedDescription)")
            print("🔧 Tipo de error: \(type(of: error))")
        }
    }
    
    // Test 2: Resolución DNS
    private func testDNSResolution() async {
        print("🔍 Test 2: Resolución DNS para OpenAI")
        
        do {
            let url = URL(string: "https://api.openai.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ DNS de OpenAI OK - Código: \(httpResponse.statusCode)")
            }
        } catch {
            print("❌ Error DNS OpenAI: \(error.localizedDescription)")
            
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    print("🚫 No hay conexión a internet")
                case .cannotFindHost:
                    print("🚫 No se puede resolver el host de OpenAI")
                case .timedOut:
                    print("⏰ Timeout conectando con OpenAI")
                case .networkConnectionLost:
                    print("📡 Conexión de red perdida")
                default:
                    print("🔧 Error específico: \(urlError.localizedDescription)")
                }
            }
        }
    }
    
    // Test 3: Endpoint específico de OpenAI
    private func testOpenAIEndpoint() async {
        print("🤖 Test 3: Endpoint de OpenAI")
        
        guard let apiKey = Bundle.main.infoDictionary?["OpenAIApiKey"] as? String else {
            print("❌ No se encontró API Key en Info.plist")
            return
        }
        
        print("🔑 API Key encontrada: \(apiKey.count) caracteres")
        print("🔑 Prefijo: \(String(apiKey.prefix(7)))")
        
        do {
            let url = URL(string: "https://api.openai.com/v1/models")!
            var request = URLRequest(url: url)
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 30.0
            
            print("📤 Enviando request a: \(url)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Respuesta OpenAI - Código: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200:
                    print("✅ API Key válida y endpoint accesible")
                case 401:
                    print("🔐 API Key inválida o expirada")
                case 429:
                    print("⏱️ Rate limit excedido")
                case 500...599:
                    print("🛠️ Error del servidor OpenAI")
                default:
                    print("❓ Código inesperado: \(httpResponse.statusCode)")
                }
                
                if let responseText = String(data: data, encoding: .utf8) {
                    print("📄 Respuesta (primeros 200 chars): \(String(responseText.prefix(200)))")
                }
            }
        } catch {
            print("❌ Error en endpoint OpenAI: \(error.localizedDescription)")
        }
    }
    
    // Test 4: Formato de API Key
    private func testAPIKeyFormat() async {
        print("🔐 Test 4: Formato de API Key")
        
        guard let apiKey = Bundle.main.infoDictionary?["OpenAIApiKey"] as? String else {
            print("❌ API Key no encontrada")
            return
        }
        
        print("📏 Longitud de API Key: \(apiKey.count) caracteres")
        print("🏁 Comienza con: \(String(apiKey.prefix(3)))")
        
        // Validaciones básicas
        if apiKey.hasPrefix("sk-") {
            print("✅ Formato correcto: Comienza con 'sk-'")
        } else {
            print("❌ Formato incorrecto: Debería comenzar con 'sk-'")
        }
        
        if apiKey.count >= 40 {
            print("✅ Longitud correcta: \(apiKey.count) caracteres")
        } else {
            print("❌ API Key muy corta: \(apiKey.count) caracteres")
        }
        
        if apiKey.contains(" ") {
            print("⚠️ ADVERTENCIA: API Key contiene espacios")
        }
        
        if apiKey == "YOUR_API_KEY_HERE" || apiKey == "sk-your-key-here" {
            print("❌ API Key es un placeholder - necesitas poner tu key real")
        }
    }
}
