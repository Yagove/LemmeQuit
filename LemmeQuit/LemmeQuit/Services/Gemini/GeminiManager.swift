//
//  APIManager.swift
//  LemmeQuit
//
//  Created by Yako on 6/5/25.
//
import Foundation

// Estructura para la respuesta de Gemini API
struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
        let finishReason: String?
        let safetyRatings: [SafetyRating]?
    }
    
    struct SafetyRating: Decodable {
        let category: String
        let probability: String
    }
    
    let candidates: [Candidate]
}

class GeminiManager {
    static let shared = GeminiManager()
    private init() {
        loadAPIKey()
    }
    
    // Almacena la API key de forma segura
    private var apiKey: String?
    
    // Carga la API key desde un lugar seguro
    private func loadAPIKey() {
        // Opción 1: Cargar desde Info.plist
        if let key = Bundle.main.infoDictionary?["GeminiApiKey"] as? String, !key.isEmpty {
            self.apiKey = key
            print("✅ Gemini API Key cargada desde Info.plist")
            return
        }
        
        // Opción 2: Cargar desde UserDefaults (si se configuró previamente)
        if let key = UserDefaults.standard.string(forKey: "GeminiApiKey"), !key.isEmpty {
            self.apiKey = key
            print("✅ Gemini API Key cargada desde UserDefaults")
            return
        }
        
        print("⚠️ API Key para Gemini no encontrada")
    }
    
    // Método para configurar la API key manualmente
    func setAPIKey(_ key: String) {
        self.apiKey = key
        UserDefaults.standard.set(key, forKey: "GeminiApiKey")
        print("✅ Gemini API Key configurada manualmente")
    }

    func fetchAIResponse(prompt: String, completion: @escaping (String?) -> Void) {
        print("🤖 GeminiManager: Iniciando fetchAIResponse")
        
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            print("❌ Error: Gemini API Key no configurada")
            completion(nil)
            return
        }
        
        print("🔑 Gemini API Key disponible: \(String(apiKey.prefix(10)))...")
        
        // URL con API key como parámetro de query (formato específico de Gemini)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)") else {
            print("❌ Error: URL de Gemini inválida")
            completion(nil)
            return
        }
        
        print("🔗 URL configurada: \(url)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        // Sistema prompt integrado con el usuario para Gemini
        let systemPrompt = "Eres un asistente terapéutico empático y profesional que ayuda a personas en recuperación de adicciones. Proporciona consejos prácticos, comprensivos y motivadores."
        let fullPrompt = "\(systemPrompt)\n\n\(prompt)"
        
        // Formato específico de Gemini
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": fullPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 250,
                "temperature": 0.7
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("📤 Request body para Gemini configurado correctamente")
        } catch {
            print("❌ Error al serializar JSON: \(error)")
            completion(nil)
            return
        }
        
        print("📝 Prompt enviado: \(prompt)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            print("📥 Respuesta recibida del servidor Gemini")
            
            if let error = error {
                print("❌ Error de red: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Respuesta HTTP inválida")
                completion(nil)
                return
            }
            
            print("📊 Código de estado HTTP: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Error HTTP: \(httpResponse.statusCode)")
                if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                    print("📄 Respuesta de error: \(responseStr)")
                }
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ Error: No hay datos en la respuesta")
                completion(nil)
                return
            }
            
            print("📊 Tamaño de datos recibidos: \(data.count) bytes")

            do {
                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                print("✅ JSON de Gemini decodificado exitosamente")
                print("🔢 Número de candidates: \(decoded.candidates.count)")
                
                if let firstCandidate = decoded.candidates.first,
                   let firstPart = firstCandidate.content.parts.first {
                    let responseText = firstPart.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("📝 Respuesta extraída: '\(responseText)'")
                    print("📏 Longitud de respuesta: \(responseText.count) caracteres")
                    
                    if responseText.isEmpty {
                        print("⚠️ ADVERTENCIA: La respuesta está vacía")
                    }
                    
                    completion(responseText)
                } else {
                    print("❌ Error: No hay candidates o parts en la respuesta de Gemini")
                    completion(nil)
                }
            } catch {
                print("❌ Error al decodificar JSON de Gemini: \(error.localizedDescription)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("📄 Respuesta raw recibida: \(responseStr)")
                }
                completion(nil)
            }
        }.resume()
    }
    
    // Método async/await mejorado con logs detallados para Gemini
    func fetchAIResponseAsync(prompt: String) async -> String? {
        print("🤖 GeminiManager: INICIO fetchAIResponseAsync")
        print("📏 Longitud del prompt: \(prompt.count) caracteres")
        
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            print("❌ Error: Gemini API Key no configurada (async)")
            return nil
        }
        
        print("🔑 Gemini API Key disponible (async): \(String(apiKey.prefix(10)))...")
        
        // URL con API key como parámetro de query (formato específico de Gemini)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)") else {
            print("❌ Error: URL de Gemini inválida (async)")
            return nil
        }
        
        print("🔗 URL configurada (async): \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        print("⏱️ Timeout configurado: 30 segundos")
        
        // Sistema prompt integrado con el usuario para Gemini
        let systemPrompt = "Eres un asistente terapéutico empático y profesional que ayuda a personas en recuperación de adicciones. Proporciona consejos prácticos, comprensivos y motivadores."
        let fullPrompt = "\(systemPrompt)\n\n\(prompt)"
        
        // Formato específico de Gemini
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": fullPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 250,
                "temperature": 0.7
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("📤 Request body para Gemini configurado correctamente (async)")
            print("📐 Tamaño del body: \(request.httpBody?.count ?? 0) bytes")
        } catch {
            print("❌ Error al serializar JSON (async): \(error)")
            return nil
        }
        
        print("📝 Prompt enviado (async): \(String(prompt.prefix(100)))...")
        print("🚀 Iniciando URLSession.shared.data(for: request) con Gemini...")
        
        do {
            print("⏳ Esperando respuesta del servidor Gemini...")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("🎉 DATOS RECIBIDOS DE GEMINI!")
            print("📊 Tamaño de datos: \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Respuesta HTTP inválida (async)")
                return nil
            }
            
            print("📊 Código de estado HTTP (async): \(httpResponse.statusCode)")
            print("📋 Headers de respuesta: \(httpResponse.allHeaderFields)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Error HTTP (async): \(httpResponse.statusCode)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("📄 Respuesta de error (async): \(responseStr)")
                }
                return nil
            }
            
            print("✅ HTTP Status OK, procediendo a decodificar JSON de Gemini...")
            
            do {
                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                print("🎯 JSON de Gemini decodificado exitosamente (async)")
                print("🔢 Número de candidates: \(decoded.candidates.count)")
                
                if let firstCandidate = decoded.candidates.first,
                   let firstPart = firstCandidate.content.parts.first {
                    let responseText = firstPart.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("📝 Respuesta extraída (async): '\(String(responseText.prefix(100)))...'")
                    print("📏 Longitud de respuesta (async): \(responseText.count) caracteres")
                    print("🏁 finishReason: \(firstCandidate.finishReason ?? "nil")")
                    
                    if responseText.isEmpty {
                        print("⚠️ ADVERTENCIA: La respuesta está vacía (async)")
                        return "Error: Respuesta vacía de Gemini"
                    }
                    
                    print("🎊 ÉXITO: Devolviendo respuesta de Gemini")
                    return responseText
                } else {
                    print("❌ Error: No hay candidates o parts en la respuesta de Gemini (async)")
                    return nil
                }
            } catch {
                print("❌ Error al decodificar JSON de Gemini (async): \(error.localizedDescription)")
                print("🔧 Tipo de error de decodificación: \(type(of: error))")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("📄 Respuesta raw para debug: \(responseStr)")
                }
                return nil
            }
            
        } catch {
            print("💥 ERROR CRÍTICO en fetchAIResponseAsync con Gemini: \(error.localizedDescription)")
            print("🔧 Tipo de error: \(type(of: error))")
            
            if let urlError = error as? URLError {
                print("🌐 URLError específico:")
                print("   - Código: \(urlError.code)")
                print("   - Descripción: \(urlError.localizedDescription)")
                
                switch urlError.code {
                case .timedOut:
                    print("⏰ TIMEOUT: La petición tardó más de 30 segundos")
                case .notConnectedToInternet:
                    print("🌐 Sin conexión a internet")
                case .cannotConnectToHost:
                    print("🔌 No se puede conectar al host de Gemini")
                case .networkConnectionLost:
                    print("📡 Conexión perdida durante la petición")
                case .cannotFindHost:
                    print("🔍 No se puede encontrar el host de Gemini")
                case .cannotLoadFromNetwork:
                    print("📥 No se puede cargar desde la red")
                default:
                    print("🛠️ Otro URLError: \(urlError.localizedDescription)")
                }
            }
            
            return nil
        }
    }
}
