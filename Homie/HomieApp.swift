//
//  ChoreApp.swift
//  Chore
//
//  Created by Sriram P H on 12/22/24.
//

import SwiftUI

@main
struct HomieApp: App {
    @StateObject var choreViewModel = ChoreViewModel()
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
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
                HomeView()
                    .environmentObject(choreViewModel)
            }
        }
    }
}
