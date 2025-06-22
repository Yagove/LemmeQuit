//
//  NotesView.swift
//  LemmeQuit
//
//  Created by Yako on 9/4/25.
//
import SwiftUI
import FirebaseFirestore

struct NotesView: View {
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var notes: [Note] = []
    @State private var showAddNoteSheet = false
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedNoteForDetail: Note?
    @State private var showNoteDetail = false
    @State private var filterByPatient: User? = nil
    @State private var showFilterOptions = false
    
    var filteredNotes: [Note] {
        var result = notes
        
        // Filtrar por paciente si hay uno seleccionado
        if let patient = filterByPatient {
            result = result.filter { $0.patientId == patient.id }
        }
        
        // Filtrar por texto de búsqueda
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Ordenar por fecha (más reciente primero)
        return result.sorted { $0.date > $1.date }
    }
    
    var groupedNotes: [Date: [Note]] {
        Dictionary(grouping: filteredNotes) { note in
            // Agrupar por día
            Calendar.current.startOfDay(for: note.date)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Selector de paciente para filtrar
                    HStack {
                        if let filterPatient = filterByPatient {
                            // Mostrar el filtro activo
                            HStack {
                                Image(systemName: "person.fill")
                                Text("Mostrando notas de \(filterPatient.name)")
                                    .font(.subheadline)
                                
                                Button(action: {
                                    filterByPatient = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(8)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                        } else {
                            // Mostrar indicación para filtrar
                            Button(action: {
                                showFilterOptions = true
                            }) {
                                HStack {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text("Filtrar por paciente")
                                        .font(.subheadline)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Botón para añadir nueva nota
                        Button(action: {
                            showAddNoteSheet = true
                        }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if notes.isEmpty {
                        // Vista para cuando no hay notas
                        VStack(spacing: 20) {
                            Image(systemName: "note.text")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No hay notas")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Añade notas sobre tus pacientes para llevar un seguimiento de su progreso")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                showAddNoteSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                    Text("Añadir nota")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.top, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                    } else if filteredNotes.isEmpty {
                        // Vista para cuando no hay resultados de búsqueda
                        VStack(spacing: 15) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No se encontraron notas")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Prueba con diferentes términos de búsqueda o filtros")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Lista de notas agrupadas por fecha
                        List {
                            ForEach(groupedNotes.keys.sorted(by: >), id: \.self) { date in
                                Section(header:
                                    Text(dateFormatter(date: date))
                                        .font(.headline)
                                ) {
                                    ForEach(groupedNotes[date] ?? []) { note in
                                        NoteRow(note: note)
                                            .onTapGesture {
                                                selectedNoteForDetail = note
                                                showNoteDetail = true
                                            }
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .searchable(text: $searchText, prompt: "Buscar en las notas")
                
                // Indicador de carga
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Notas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddNoteSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddNoteSheet) {
                addNoteView
            }
            .sheet(isPresented: $showNoteDetail) {
                if let note = selectedNoteForDetail {
                    NoteDetailView(note: note)
                }
            }
            .actionSheet(isPresented: $showFilterOptions) {
                createFilterActionSheet()
            }
            .onAppear {
                loadNotes()
            }
        }
    }
    
    // Vista para añadir nota
    private var addNoteView: some View {
        AddTherapistNoteView { addedNote in
            if let note = addedNote {
                notes.append(note)
            }
        }
        .environmentObject(userVM)
    }
    
    // MARK: - Métodos
    
    private func loadNotes() {
        guard let userId = userVM.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // Cargar todas las notas del terapeuta
                let fetchedNotes = try await FirebaseService.shared.getNotesForUser(userId: userId)
                
                await MainActor.run {
                    self.notes = fetchedNotes
                    self.isLoading = false
                }
            } catch {
                print("Error cargando notas: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func dateFormatter(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func createFilterActionSheet() -> ActionSheet {
        var buttons: [ActionSheet.Button] = []
        
        // Añadir botón para cada paciente
        for patient in userVM.patientsList {
            buttons.append(.default(Text(patient.name)) {
                filterByPatient = patient
            })
        }
        
        // Añadir botón para mostrar todos
        buttons.append(.default(Text("Mostrar todos")) {
            filterByPatient = nil
        })
        
        // Añadir botón de cancelar
        buttons.append(.cancel(Text("Cancelar")))
        
        return ActionSheet(
            title: Text("Filtrar por paciente"),
            message: Text("Selecciona un paciente para ver sus notas"),
            buttons: buttons
        )
    }
}

// Componente para fila de nota
struct NoteRow: View {
    let note: Note
    
    var patientName: String {
        // En un escenario real, obtendrías el nombre del paciente a través del ViewModel
        guard let patientId = note.patientId else { return "Paciente" }
        return "Paciente \(patientId.prefix(4))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icono según tipo de nota
                Image(systemName: note.isVoiceNote ? "mic.fill" : "note.text")
                    .foregroundColor(note.isVoiceNote ? .red : .blue)
                
                Text(note.title)
                    .font(.headline)
                
                Spacer()
                
                // Hora de la nota
                Text(note.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Contenido truncado
            Text(note.content)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.secondary)
            
            // Badge del paciente
            if let patientId = note.patientId {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    
                    Text(patientName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// Vista para añadir nueva nota
struct AddTherapistNoteView: View {
    @EnvironmentObject var userVM: UserViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var noteTitle: String = ""
    @State private var noteContent: String = ""
    @State private var selectedPatient: User?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var onNoteSaved: (Note?) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Detalles de la nota")) {
                    TextField("Título", text: $noteTitle)
                    
                    if userVM.patientsList.isEmpty {
                        Text("No tienes pacientes asignados")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Paciente", selection: $selectedPatient) {
                            Text("Selecciona un paciente").tag(nil as User?)
                            
                            ForEach(userVM.patientsList) { patient in
                                Text(patient.name).tag(patient as User?)
                            }
                        }
                    }
                }
                
                Section(header: Text("Contenido")) {
                    TextEditor(text: $noteContent)
                        .frame(minHeight: 200)
                }
                
                Section {
                    Button(action: saveNote) {
                        Text("Guardar nota")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .disabled(noteTitle.isEmpty || noteContent.isEmpty || selectedPatient == nil)
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
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay(
                ZStack {
                    if isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                    }
                }
            )
        }
    }
    
    private func saveNote() {
        guard let userId = userVM.currentUser?.id,
              let patient = selectedPatient,
              !noteTitle.isEmpty,
              !noteContent.isEmpty else {
            return
        }
        
        isLoading = true
        
        // Crear la nueva nota
        let newNote = Note(
            title: noteTitle,
            content: noteContent,
            date: Date(),
            userId: userId,
            patientId: patient.id,
            noteType: .therapy
        )
        
        Task {
            do {
                // Guardar nota en Firebase
                let _ = try await FirebaseService.shared.saveNote(newNote)
                
                await MainActor.run {
                    isLoading = false
                    onNoteSaved(newNote)
                    dismiss()
                }
            } catch {
                print("Error guardando nota: \(error.localizedDescription)")
                
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error al guardar la nota: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// Vista detallada de una nota
struct NoteDetailView: View {
    let note: Note
    @Environment(\.dismiss) var dismiss
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Cabecera con título y fecha
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            
                            Text(dateFormatter.string(from: note.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if note.isVoiceNote {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.red)
                                
                                Text("Nota de voz transcrita")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 5)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    
                    // Contenido de la nota
                    Text(note.content)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Detalles de la Nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NotesView_Previews: PreviewProvider {
    static var previews: some View {
        NotesView()
            .environmentObject(UserViewModel())
    }
}
