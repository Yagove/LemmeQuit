//
//  APIManager.swift
//  LemmeQuit
//
//  Created by Yako on 6/5/25.
//
import Foundation

// Estructuras actualizadas para la respuesta de la API chat/completions
struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
        let finish_reason: String?
    }
    let choices: [Choice]
}

class OpenAIManager {
    static let shared = OpenAIManager()
    private init() {
        loadAPIKey()
    }
    
    // Almacena la API key de forma segura
    private var apiKey: String?
    
    // Carga la API key desde un lugar seguro
    private func loadAPIKey() {
        // Opción 1: Cargar desde Info.plist
        if let key = Bundle.main.infoDictionary?["OpenAIApiKey"] as? String, !key.isEmpty {
            self.apiKey = key
            print("✅ API Key cargada desde Info.plist")
            return
        }
        
        // Opción 2: Cargar desde UserDefaults (si se configuró previamente)
        if let key = UserDefaults.standard.string(forKey: "OpenAIApiKey"), !key.isEmpty {
            self.apiKey = key
            print("✅ API Key cargada desde UserDefaults")
            return
        }
        
        print("⚠️ API Key para OpenAI no encontrada")
    }
    
    // Método para configurar la API key manualmente
    func setAPIKey(_ key: String) {
        self.apiKey = key
        UserDefaults.standard.set(key, forKey: "OpenAIApiKey")
        print("✅ API Key configurada manualmente")
    }

    func fetchAIResponse(prompt: String, completion: @escaping (String?) -> Void) {
        print("🌐 OpenAIManager: Iniciando fetchAIResponse")
        
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            print("❌ Error: API Key no configurada")
            completion(nil)
            return
        }
        
        print("🔑 API Key disponible: \(String(apiKey.prefix(10)))...")
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ Error: URL inválida")
            completion(nil)
            return
        }
        
        print("🔗 URL configurada: \(url)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "Eres un asistente terapéutico empático y profesional que ayuda a personas en recuperación de adicciones. Proporciona consejos prácticos, comprensivos y motivadores."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 250,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("📤 Request body configurado correctamente")
        } catch {
            print("❌ Error al serializar JSON: \(error)")
            completion(nil)
            return
        }
        
        print("📝 Prompt enviado: \(prompt)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            print("📥 Respuesta recibida del servidor")
            
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
                let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                print("✅ JSON decodificado exitosamente")
                print("🔢 Número de choices: \(decoded.choices.count)")
                
                if let firstChoice = decoded.choices.first {
                    let responseText = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("📝 Respuesta extraída: '\(responseText)'")
                    print("📏 Longitud de respuesta: \(responseText.count) caracteres")
                    
                    if responseText.isEmpty {
                        print("⚠️ ADVERTENCIA: La respuesta está vacía")
                    }
                    
                    completion(responseText)
                } else {
                    print("❌ Error: No hay choices en la respuesta")
                    completion(nil)
                }
            } catch {
                print("❌ Error al decodificar JSON: \(error.localizedDescription)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("📄 Respuesta raw recibida: \(responseStr)")
                }
                completion(nil)
            }
        }.resume()
    }
    
    // Método async/await mejorado con logs detallados
    func fetchAIResponseAsync(prompt: String) async -> String? {
        print("🌐 OpenAIManager: INICIO fetchAIResponseAsync")
        print("📏 Longitud del prompt: \(prompt.count) caracteres")
        
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            print("❌ Error: API Key no configurada (async)")
            return nil
        }
        
        print("🔑 API Key disponible (async): \(String(apiKey.prefix(10)))...")
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ Error: URL inválida (async)")
            return nil
        }
        
        print("🔗 URL configurada (async): \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        print("⏱️ Timeout configurado: 30 segundos")
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "Eres un asistente terapéutico empático y profesional que ayuda a personas en recuperación de adicciones. Proporciona consejos prácticos, comprensivos y motivadores."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 250,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("📤 Request body configurado correctamente (async)")
            print("📐 Tamaño del body: \(request.httpBody?.count ?? 0) bytes")
        } catch {
            print("❌ Error al serializar JSON (async): \(error)")
            return nil
        }
        
        print("📝 Prompt enviado (async): \(String(prompt.prefix(100)))...")
        print("🚀 Iniciando URLSession.shared.data(for: request)...")
        
        do {
            print("⏳ Esperando respuesta del servidor...")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("🎉 DATOS RECIBIDOS!")
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
            
            print("✅ HTTP Status OK, procediendo a decodificar JSON...")
            
            do {
                let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                print("🎯 JSON decodificado exitosamente (async)")
                print("🔢 Número de choices: \(decoded.choices.count)")
                
                if let firstChoice = decoded.choices.first {
                    let responseText = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("📝 Respuesta extraída (async): '\(String(responseText.prefix(100)))...'")
                    print("📏 Longitud de respuesta (async): \(responseText.count) caracteres")
                    print("🏁 finish_reason: \(firstChoice.finish_reason ?? "nil")")
                    
                    if responseText.isEmpty {
                        print("⚠️ ADVERTENCIA: La respuesta está vacía (async)")
                        return "Error: Respuesta vacía de OpenAI"
                    }
                    
                    print("🎊 ÉXITO: Devolviendo respuesta")
                    return responseText
                } else {
                    print("❌ Error: No hay choices en la respuesta (async)")
                    return nil
                }
            } catch {
                print("❌ Error al decodificar JSON (async): \(error.localizedDescription)")
                print("🔧 Tipo de error de decodificación: \(type(of: error))")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("📄 Respuesta raw para debug: \(responseStr)")
                }
                return nil
            }
            
        } catch {
            print("💥 ERROR CRÍTICO en fetchAIResponseAsync: \(error.localizedDescription)")
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
                    print("🔌 No se puede conectar al host")
                case .networkConnectionLost:
                    print("📡 Conexión perdida durante la petición")
                case .cannotFindHost:
                    print("🔍 No se puede encontrar el host")
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
