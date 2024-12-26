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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(choreViewModel)
        }
    }
}
