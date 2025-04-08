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
    @StateObject private var supabaseManager = SupabaseManager.shared
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
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
            .onOpenURL { url in
                // Handle URL callbacks (e.g., from OAuth)
                print("App received URL: \(url)")
                Task {
                    await handleURL(url)
                }
            }
            .onAppear {
                print("App launched with bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
                if let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
                    print("Registered URL schemes:")
                    for urlType in urlTypes {
                        if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                            for scheme in schemes {
                                print("  - \(scheme)")
                            }
                        }
                    }
                } else {
                    print("No URL schemes found in Info.plist")
                }
            }
        }
    }
    
    @MainActor
    private func handleURL(_ url: URL) async {
        // Log the URL for debugging
        print("Handling URL: \(url)")
        print("URL components:")
        print("  scheme: \(url.scheme ?? "nil")")
        print("  host: \(url.host ?? "nil")")
        print("  path: \(url.path)")
        print("  query: \(url.query ?? "nil")")
        print("  fragment: \(url.fragment ?? "nil")")
        
        // For OAuth callbacks, we need to be more flexible about what we consider valid
        if url.absoluteString.contains("auth/callback") || 
           url.absoluteString.contains("login-callback") ||
           url.absoluteString.contains("auth-callback") ||
           url.scheme == Bundle.main.bundleIdentifier {
            
            print("✅ URL recognized as an auth callback")
            
            // For debugging
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                print("URL query items:")
                components.queryItems?.forEach { item in
                    print("  \(item.name): \(item.value ?? "nil")")
                }
            }
            
            // Try multiple approaches to handle the callback
            var authenticated = false
            
            // Approach 1: Direct session from URL
            do {
                print("Approach 1: Attempting to get session directly from URL...")
                let authResponse = try await supabaseManager.client.auth.session(from: url)
                print("✅ Successfully created session from URL")
                print("  Access token: \(authResponse.accessToken.prefix(15))...")
                print("  User ID: \(authResponse.user.id)")
                
                supabaseManager.authUser = authResponse.user
                supabaseManager.isAuthenticated = true
                authenticated = true
            } catch {
                print("❌ Error with Approach 1: \(error.localizedDescription)")
            }
            
            // Approach 2: Check for existing session anyway
            if !authenticated {
                print("Approach 2: Checking for existing session via Supabase client...")
                await supabaseManager.checkAndSetSession()
                
                if supabaseManager.isAuthenticated {
                    print("✅ Successfully authenticated via existing session check")
                    authenticated = true
                } else {
                    print("❌ No existing session found via session check")
                }
            }
            
            // If any approach worked, set as completed login
            if authenticated {
                print("Authentication successful! Setting hasCompletedLogin to true")
                hasCompletedLogin = true
            } else {
                print("❌ All authentication approaches failed for the callback URL")
            }
        } else {
            print("❌ URL not recognized as an auth callback: \(url)")
        }
    }
}
