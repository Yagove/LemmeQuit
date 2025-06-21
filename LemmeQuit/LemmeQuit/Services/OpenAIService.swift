//
//  OpenAIService.swift
//  LemmeQuit
//
//  Created by Yako on 7/5/25.
//

import Foundation

class OpenAIService {
    private let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAI_API_Key")

    func fetchAdvice(prompt: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil)
            return
        }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "Eres un asistente simpático y motivador."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let choices = json?["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: String]
                let content = message?["content"]
                completion(content)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}
