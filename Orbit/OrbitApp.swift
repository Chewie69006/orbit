//
//  OrbitApp.swift
//  Orbit
//
//  Created by David Rodrigues on 04/11/2026.
//

import SwiftUI

@main
struct OrbitApp: App {
    @State private var store = OrbitStore.live()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 960, minHeight: 560)
        }
        .commands {
            // ⌘N crée une tâche (bouton de la barre d'outils) plutôt qu'une nouvelle fenêtre.
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
