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
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(choreViewModel)
            } else {
                OnboardingView()
                    .environmentObject(choreViewModel)
                    .onDisappear {
                        // This ensures the onboarding is only shown once
                        hasCompletedOnboarding = true
                    }
            }
        }
    }
}
