//
//  LoadingView.swift
//  LemmeQuit
//
//  Created by Yako on 21/5/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
                
                Text("Cargando...")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
