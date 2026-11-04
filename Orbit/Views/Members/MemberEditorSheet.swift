//
//  MemberEditorSheet.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Ajout ou modification d'un membre de l'équipe.
struct MemberEditorSheet: View {
    let isNew: Bool
    let onSave: (Member) -> Void

    @State private var member: Member
    @Environment(\.dismiss) private var dismiss

    init(member: Member, isNew: Bool, onSave: @escaping (Member) -> Void) {
        self.isNew = isNew
        self.onSave = onSave
        self._member = State(initialValue: member)
    }

    private var trimmedName: String {
        member.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sheetTitle: String { isNew ? "Nouveau membre" : "Modifier le membre" }
    private var saveTitle: String { isNew ? "Ajouter" : "Enregistrer" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                MemberAvatar(member: member, size: 40)
                Text(sheetTitle)
                    .font(.headline)
            }
            .padding([.horizontal, .top], 20)

            Form {
                TextField("Nom", text: $member.name, prompt: Text("Prénom Nom"))
                TextField("Rôle", text: $member.role, prompt: Text("Ex. : Back-end, iOS…"))
                LabeledContent("Couleur") {
                    HStack(spacing: 6) {
                        ForEach(0..<MemberPalette.colors.count, id: \.self) { index in
                            Button {
                                member.colorIndex = index
                            } label: {
                                Circle()
                                    .fill(MemberPalette.color(for: index))
                                    .frame(width: 18, height: 18)
                                    .padding(3)
                                    .overlay {
                                        if member.colorIndex == index {
                                            Circle().stroke(Color.primary, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(saveTitle) {
                    onSave(member)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 440, height: 320)
    }
}
