//
//  ChoreApp.swift
//  Chore
//
//  Created by Sriram P H on 12/22/24.
//

import SwiftUI

@main
struct ChoreApp: App {
    @StateObject private var choreViewModel = ChoreViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedLogin {
                // Show login first
                LoginView()
                    .environmentObject(choreViewModel)
            } else if !hasCompletedOnboarding {
                // Show onboarding after login if not completed
                OnboardingView()
                    .environmentObject(choreViewModel)
            } else {
                // Show main content if both login and onboarding are completed
                ContentView()
                    .environmentObject(choreViewModel)
            }
        }
    }
}
