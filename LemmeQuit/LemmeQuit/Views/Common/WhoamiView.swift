//
//  Whoami.swift
//  LemmeQuit
//
//  Created by Yako on 18/3/25.
//

import SwiftUI

struct WhoamiView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Spacer()
                    Text("Acerca de esta App")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 30)
                    Spacer()
                }
                
                // Content
                VStack(alignment: .leading, spacing: 16) {
                    Text("""
                    Este es un trabajo que ha surgido de la motivación personal. No trata de lucrarse a costa de nadie, tan solo del puro estímulo de ayudar y ser ayudado.
                    
                    En situaciones complicadas se recurre a veces a soluciones poco ortodoxas y que perjudican más que ayudar. Personalmente sé lo que es eso, y la sensación de salir de ese pozo gracias a la ayuda de alguien.
                    
                    Así que si eres el que ayuda, como el que quiere ser ayudado, espero que esta herramienta te sea de utilidad.
                    """)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(5)
                    
                    // Final message with emphasis
                    VStack(alignment: .center, spacing: 8) {
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("Gracias,")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("¡Y mucho ánimo, coraje y fuerza!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .padding()
                
                // Optional decorative elements
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
            .padding()
        }
        .navigationTitle("Quiénes Somos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WhoamiView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WhoamiView()
        }
    }
}
