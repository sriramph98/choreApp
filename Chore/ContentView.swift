//
//  ContentView.swift
//  Chore
//
//  Created by Sriram P H on 12/22/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var isAuthenticated = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Logo and App Name
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("Chore Manager")
                    .font(.largeTitle)
                    .bold()
                
                Text("Assign tasks effortlessly")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Guest Sign In
                Button {
                    Task {
                        await viewModel.signInAsGuest()
                        isAuthenticated = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                        Text("Continue as Guest")
                    }
                }
                .buttonStyle(SocialButtonStyle())
                
                // Divider
                HStack {
                    VStack { Divider() }
                    Text("or")
                        .foregroundColor(.gray)
                    VStack { Divider() }
                }
                
                // Email Sign In Form
                VStack(spacing: 15) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                    
                    Button {
                        Task {
                            await viewModel.signInWithEmail()
                        }
                    } label: {
                        Text("Sign In with Email")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding()
            .navigationDestination(isPresented: $isAuthenticated) {
                HomeView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

#Preview {
    ContentView()
}
