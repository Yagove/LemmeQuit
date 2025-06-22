//
//  NewNoteView.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//

import SwiftUI
import FirebaseFirestore

struct AddNoteView: View {
    // Propiedades del entorno
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    // Estado local
    @State private var newNote: String = ""
    @State private var selectedDate: Date = Date()
    @State private var isLoading = false
    @State private var showDatePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
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
                    
                    // Editor de texto para la nota
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nota")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextEditor(text: $newNote)
                            .padding()
                            .frame(minHeight: 200)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                    
                    // Información adicional
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Esta nota aparecerá en tu calendario")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Text("Puedes usarla para registrar tu estado de ánimo, pensamientos o cualquier información relevante sobre tu día.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Botón de guardar
                    Button(action: saveNote) {
                        Text("Guardar Nota")
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(newNote.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(newNote.isEmpty || isLoading)
                    .opacity(newNote.isEmpty ? 0.5 : 1)
                    .padding(.bottom)
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
            .navigationTitle("Nueva Nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Métodos
    
    private func saveNote() {
        guard let userId = userVM.currentUser?.id, !newNote.isEmpty else {
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Crear una nueva nota
                let newNoteObj = Note(
                    title: "Nota del día",
                    content: newNote,
                    date: selectedDate,
                    userId: userId
                )
                
                // Guardar en Firebase
                _ = try await FirebaseService.shared.saveNote(newNoteObj)
                
                // Cerrar vista
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("Error guardando nota: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct AddNoteView_Previews: PreviewProvider {
    static var previews: some View {
        AddNoteView()
            .environmentObject(UserViewModel())
    }
}
