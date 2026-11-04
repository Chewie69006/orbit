//
//  ContentView.swift
//  Orbit
//
//  Created by David Rodrigues on 04/11/2026.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(OrbitStore.self) private var store
    @State private var selectedTeamID: UUID?
    @State private var isCreatingTeam = false

    var body: some View {
        NavigationSplitView {
            TeamSidebar(selection: $selectedTeamID)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 320)
        } detail: {
            detail
        }
        .onAppear(perform: ensureSelection)
        .onChange(of: store.teams) { _, _ in
            ensureSelection()
        }
        .sheet(isPresented: $isCreatingTeam) {
            NameSheet(title: "Nouvelle équipe", actionTitle: "Créer") { name in
                selectedTeamID = store.addTeam(name: name).id
            }
        }
        .alert(
            "Données mises de côté",
            isPresented: Binding(
                get: { store.loadIssue != nil },
                set: { if !$0 { store.loadIssue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.loadIssue ?? "")
        }
        .overlay(alignment: .bottom) {
            if let saveError = store.saveError {
                Label(saveError, systemImage: "exclamationmark.triangle.fill")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let team = store.team(selectedTeamID) {
            TeamView(team: team)
                .id(team.id)
        } else if store.teams.isEmpty {
            ContentUnavailableView {
                Label("Bienvenue dans Orbit", systemImage: "circle.dashed")
            } description: {
                Text("Créez une équipe, ajoutez ses développeurs, chiffrez les tâches : Orbit les place sur le calendrier de chacun et apprend de leurs écarts.")
            } actions: {
                Button("Créer une équipe") { isCreatingTeam = true }
                    .buttonStyle(.borderedProminent)
                Button("Explorer une équipe d'exemple") {
                    selectedTeamID = store.addSampleTeam().id
                }
            }
        } else {
            ContentUnavailableView("Aucune équipe sélectionnée", systemImage: "sidebar.left")
        }
    }

    private func ensureSelection() {
        if store.team(selectedTeamID) == nil {
            selectedTeamID = store.teams.first?.id
        }
    }
}

#Preview("Équipe d'exemple") {
    ContentView()
        .environment(OrbitStore(data: SampleData.make().data))
        .frame(width: 1200, height: 700)
}

#Preview("Premier lancement") {
    ContentView()
        .environment(OrbitStore(data: OrbitData()))
        .frame(width: 1000, height: 600)
}
