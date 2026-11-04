//
//  SampleData.swift
//  Orbit
//

import Foundation

/// Une équipe d'exemple, pour découvrir l'application et pour les aperçus SwiftUI.
enum SampleData {
    struct Content {
        let team: Team
        let members: [Member]
        let tasks: [TaskItem]

        var data: OrbitData {
            OrbitData(teams: [team], members: members, tasks: tasks)
        }
    }

    static func make(now: Date = Date(), workCalendar: WorkCalendar = AppSettings().workCalendar) -> Content {
        let team = Team(name: "Équipe Apollo")
        let camille = Member(teamID: team.id, name: "Camille Martin", role: "iOS", colorIndex: 0)
        let hugo = Member(teamID: team.id, name: "Hugo Bernard", role: "Back-end", colorIndex: 1)
        let lea = Member(teamID: team.id, name: "Léa Dubois", role: "Front-end", colorIndex: 2)
        let nathan = Member(teamID: team.id, name: "Nathan Petit", role: "DevOps", colorIndex: 3)

        /// Jour ouvré relatif à aujourd'hui (0 = aujourd'hui), à l'heure indiquée.
        func day(_ offset: Int, hour: Int = 17) -> Date {
            let date = workCalendar.workingDay(at: offset, from: now)
            return workCalendar.calendar.date(byAdding: .hour, value: hour, to: date) ?? date
        }

        var tasks: [TaskItem] = []
        var ranks: [UUID: Int] = [:]

        func done(_ title: String, _ member: Member, estimate: Int, actual: Int, on offset: Int) {
            tasks.append(
                TaskItem(
                    teamID: team.id, title: title, assigneeID: member.id,
                    estimate: ManDays(eighths: estimate), status: .done,
                    startedAt: day(offset - max(0, actual / 8 - 1), hour: 9),
                    completedAt: day(offset), actualSpent: ManDays(eighths: actual)
                )
            )
        }

        func open(
            _ title: String, _ member: Member?, estimate: Int,
            subtasks: [(String, Int)] = [], startedOn: Int? = nil, notBefore: Int? = nil, notes: String = ""
        ) {
            let key = member?.id ?? team.id
            let rank = ranks[key, default: 0]
            ranks[key] = rank + 1
            tasks.append(
                TaskItem(
                    teamID: team.id, title: title, notes: notes, assigneeID: member?.id,
                    estimate: ManDays(eighths: estimate),
                    subtasks: subtasks.map { Subtask(title: $0.0, estimate: ManDays(eighths: $0.1)) },
                    status: startedOn == nil ? .todo : .inProgress,
                    rank: rank,
                    notBefore: notBefore.map { day($0, hour: 0) },
                    startedAt: startedOn.map { day($0, hour: 9) }
                )
            )
        }

        // Camille sous-estime un peu ses tâches.
        done("Écran de connexion", camille, estimate: 16, actual: 20, on: -18)
        done("Notifications push", camille, estimate: 24, actual: 34, on: -12)
        done("Mode hors-ligne", camille, estimate: 12, actual: 16, on: -6)
        done("Correctifs App Store", camille, estimate: 8, actual: 11, on: -2)
        open("Refonte du profil", camille, estimate: 24,
             subtasks: [("Maquettes intégrées", 8), ("Édition de l'avatar", 12), ("Tests UI", 8)],
             startedOn: -1)
        open("Widget d'accueil", camille, estimate: 16)
        open("Partage de fichiers", camille, estimate: 24)

        // Hugo chiffre juste.
        done("API d'authentification", hugo, estimate: 16, actual: 16, on: -15)
        done("Migration de la base", hugo, estimate: 24, actual: 26, on: -9)
        done("Webhooks de paiement", hugo, estimate: 12, actual: 11, on: -4)
        open("Export CSV", hugo, estimate: 16, startedOn: -3,
             notes: "Bloqué par l'accès à l'entrepôt de données.")
        open("Cache des requêtes", hugo, estimate: 16)
        open("Pagination des listes", hugo, estimate: 8, notBefore: 6)

        // Léa surestime légèrement.
        done("Tableau de bord", lea, estimate: 24, actual: 19, on: -14)
        done("Thème sombre", lea, estimate: 16, actual: 13, on: -8)
        done("Formulaire d'inscription", lea, estimate: 12, actual: 10, on: -3)
        open("Page de tarifs", lea, estimate: 16,
             subtasks: [("Composants", 6), ("Intégration du paiement", 8), ("Responsive", 4)])
        open("Accessibilité", lea, estimate: 24)

        // Nathan vient d'arriver : pas encore d'historique.
        open("Pipeline d'intégration continue", nathan, estimate: 16)
        open("Supervision", nathan, estimate: 24)

        open("Audit de sécurité", nil, estimate: 40)

        return Content(team: team, members: [camille, hugo, lea, nathan], tasks: tasks)
    }
}
