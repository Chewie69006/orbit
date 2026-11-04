//
//  TeamSidebar.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Liste des équipes.
struct TeamSidebar: View {
    @Binding var selection: UUID?

    @Environment(OrbitStore.self) private var store
    @State private var isCreatingTeam = false
    @State private var teamToRename: Team?
    @State private var teamToDelete: Team?

    var body: some View {
        List(selection: $selection) {
            Section("Équipes") {
                ForEach(store.teams) { team in
                    Label(team.name, systemImage: "person.3")
                        .badge(store.members(in: team.id).count)
                        .tag(team.id)
                        .contextMenu {
                            Button("Renommer…", systemImage: "pencil") { teamToRename = team }
                            Divider()
                            Button("Supprimer…", systemImage: "trash", role: .destructive) { teamToDelete = team }
                        }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isCreatingTeam = true
            } label: {
                Label("Nouvelle équipe", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .sheet(isPresented: $isCreatingTeam) {
            NameSheet(title: "Nouvelle équipe", actionTitle: "Créer") { name in
                selection = store.addTeam(name: name).id
            }
        }
        .sheet(item: $teamToRename) { team in
            NameSheet(title: "Renommer l'équipe", initialName: team.name, actionTitle: "Renommer") { name in
                store.renameTeam(team.id, to: name)
            }
        }
        .confirmationDialog(
            "Supprimer l'équipe « \(teamToDelete?.name ?? "") » ?",
            isPresented: Binding(isPresenting: $teamToDelete),
            titleVisibility: .visible,
            presenting: teamToDelete
        ) { team in
            Button("Supprimer l'équipe", role: .destructive) {
                store.deleteTeam(team.id)
            }
        } message: { _ in
            Text("Ses membres et toutes ses tâches seront supprimés définitivement.")
        }
    }
}
