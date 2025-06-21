//
//  RegisterView.swift
//  LemmeQuit
//
//  Created by Yako on 22/1/25.
//

import SwiftUI
import FirebaseAuth

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var registerVM = RegisterViewModel()
    
    // Controles de navegación y UI
    @State private var showingAlert = false
    @State private var isLoading = false
    @State private var navigateToMainView = false
    @State private var showSuccessMessage = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cabecera
                Text("Crear cuenta")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                // Selector de tipo de usuario
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tipo de usuario")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Picker("Tipo de Usuario", selection: $registerVM.userType) {
                        Text("Paciente").tag(User.UserType.patient)
                        Text("Terapeuta").tag(User.UserType.therapist)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
                
                // Datos de usuario comunes
                VStack(spacing: 20) {
                    // Nombre completo
                    CustomTextField(
                        title: "Nombre completo",
                        text: $registerVM.userName,
                        icon: "person.fill",
                        placeholder: "Tu nombre completo"
                    )
                    
                    // Email
                    CustomTextField(
                        title: "Correo electrónico",
                        text: $registerVM.email,
                        icon: "envelope.fill",
                        placeholder: "ejemplo@correo.com",
                        keyboardType: .emailAddress,
                        autocapitalization: .none
                    )
                    
                    // Contraseña
                    CustomSecureField(
                        title: "Contraseña",
                        text: $registerVM.password,
                        icon: "lock.fill",
                        placeholder: "Mínimo 6 caracteres"
                    )
                    
                    // Repetir contraseña
                    CustomSecureField(
                        title: "Confirmar contraseña",
                        text: $registerVM.repeatPassword,
                        icon: "lock.shield.fill",
                        placeholder: "Debe coincidir"
                    )
                }
                .padding(.horizontal)
                
                // Datos específicos del paciente
                if registerVM.userType == .patient {
                    VStack(spacing: 20) {
                        Text("Información personal")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Sexo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sexo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Sexo", selection: $registerVM.sex) {
                                Text("Masculino").tag("Masculino")
                                Text("Femenino").tag("Femenino")
                                Text("Otro").tag("Otro")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        
                        // Edad
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Edad")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("\(registerVM.age) años")
                                Spacer()
                                Stepper("", value: $registerVM.age, in: 5...99)
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        
                        // Deporte
                        VStack(alignment: .leading, spacing: 8) {
                            Text("¿Practicas deporte?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Deporte", selection: $registerVM.sport) {
                                Text("Sí").tag("Sí")
                                Text("No").tag("No")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        
                        // Adicción
                        CustomTextField(
                            title: "Adicción que quieres superar",
                            text: $registerVM.addiction,
                            icon: "heart.slash.fill",
                            placeholder: "Ej: Tabaco, alcohol, etc."
                        )
                        
                        // Hobbies
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hobbies o intereses")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            CustomTextField(
                                text: $registerVM.hobby1,
                                icon: "star.fill",
                                placeholder: "Hobby 1"
                            )
                            
                            CustomTextField(
                                text: $registerVM.hobby2,
                                icon: "star.fill",
                                placeholder: "Hobby 2"
                            )
                            
                            CustomTextField(
                                text: $registerVM.hobby3,
                                icon: "star.fill",
                                placeholder: "Hobby 3"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Botón de registro
                Button(action: registerUser) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                isFormValid
                                ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing)
                                : LinearGradient(gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing)
                            )
                            
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        } else {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 18))
                                Text("Crear cuenta")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .frame(height: 55)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .disabled(!isFormValid || isLoading)
                
                // Mensaje de error
                if !registerVM.errorMessage.isEmpty {
                    Text(registerVM.errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Botón para volver a login
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Volver al inicio de sesión")
                    }
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 20)
            }
            .padding()
        }
        .navigationBarTitle("Registro", displayMode: .inline)
        .onReceive(registerVM.$isRegistered) { isRegistered in
            if isRegistered {
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .overlay(
            ZStack {
                if showSuccessMessage {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 24))
                            
                            Text("¡Registro exitoso!")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        Spacer()
                    }
                    .animation(.easeInOut(duration: 0.3))
                    .zIndex(100)
                }
            }
        )
    }
    
    // Validación del formulario
    private var isFormValid: Bool {
        let basicFieldsValid = !registerVM.userName.isEmpty &&
                              !registerVM.email.isEmpty &&
                              registerVM.password.count >= 6 &&
                              registerVM.password == registerVM.repeatPassword
        
        if registerVM.userType == .patient {
            return basicFieldsValid && !registerVM.addiction.isEmpty
        }
        
        return basicFieldsValid
    }
    
    // Función para registrar usuario
    private func registerUser() {
        isLoading = true
        
        Task {
            do {
                await registerVM.registerUser()
                isLoading = false
                // La navegación se maneja con onReceive del isRegistered
            } catch {
                isLoading = false
                // El error ya se maneja en el ViewModel
            }
        }
    }
}

// Componente para campo de texto personalizado
struct CustomTextField: View {
    var title: String = ""
    @Binding var text: String
    var icon: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .words
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(autocapitalization)
                    .disableAutocorrection(true)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// Componente para campo de contraseña personalizado
struct CustomSecureField: View {
    var title: String = ""
    @Binding var text: String
    var icon: String
    var placeholder: String
    @State private var showPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                
                if showPassword {
                    TextField(placeholder, text: $text)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                } else {
                    SecureField(placeholder, text: $text)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
