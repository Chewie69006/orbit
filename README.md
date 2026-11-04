# Orbit

Application macOS (SwiftUI) pour planifier le travail d'une ou plusieurs équipes de développeurs.

On ajoute les membres de son équipe, chacun chiffre ses tâches, et Orbit les place sur un calendrier : une rangée par personne, les tâches enchaînées dans l'ordre de sa file. Ça ressemble à un kanban sans en être un. Quand une tâche est terminée, la personne indique le temps réellement passé, et Orbit ajuste ses chiffrages suivants grâce à une moyenne mobile exponentielle (EMA).

## Fonctionnalités

- **Équipes** : plusieurs équipes, chacune avec ses membres (nom, rôle, couleur).
- **Planning** : calendrier sur 1 à 6 semaines. Les week-ends (jours non travaillés) sont grisés, aujourd'hui est mis en avant, les tâches en retard sont entourées de rouge.
- **Files** : les tâches ouvertes de chacun dans l'ordre où elles seront faites. On les réordonne par glisser-déposer, et le planning suit. On y trouve aussi les tâches non assignées et les dernières tâches terminées.
- **Tâches** : titre, personne assignée, chiffrage, sous-tâches, notes, date « pas avant le ». Cycle de vie : à faire → en cours → terminée (avec le temps passé), et on peut la rouvrir.
- **Pondération** : coefficient par membre, avec son historique (graphique) dans une fenêtre qui s'ouvre en cliquant sur le nom.
- **Réglages** (⌘,) : jours travaillés (du lundi au vendredi par défaut), réactivité α de l'EMA, activation de la pondération dans le planning.
- Une **équipe d'exemple** permet de découvrir l'application au premier lancement.

## Règles de calcul

### Unité : le jour-homme, au ⅛ de journée

Les durées sont stockées en huitièmes de journée (`ManDays`). La saisie accepte `2`, `1,5`, `1 3/8`, `⅜`, `2⅜ j` ou des heures (`6h` = ¾ j). L'affichage utilise les fractions : `2⅜ j`.

### Chiffrage retenu d'une tâche

```
chiffrage retenu = max(chiffrage de la tâche, somme des chiffrages des sous-tâches)
```

La somme des sous-tâches ne remplace le chiffrage de la tâche que si elle est supérieure.

### Pondération (EMA)

Pour chaque tâche terminée d'une personne, on calcule `ratio = temps passé / chiffrage retenu`. Le coefficient de la personne est une moyenne mobile exponentielle de ces ratios, dans l'ordre où les tâches ont été terminées :

```
coefficient₀ = 1 (neutre)
coefficientₙ = α × ratioₙ + (1 − α) × coefficientₙ₋₁        (α = 0,3 par défaut)
```

Les dernières tâches pèsent donc plus que les premières. Avec un coefficient de ×1,25, une tâche chiffrée à 2 j est planifiée sur 2½ j. Le chiffrage d'une tâche terminée est figé, puisqu'il sert à ce calcul. Les tâches sans temps passé ou sans chiffrage sont ignorées.

### Planification

- Les tâches ouvertes d'une personne s'enchaînent à partir d'aujourd'hui, dans l'ordre de sa file, avec leur durée pondérée, et seulement sur les jours travaillés.
- Démarrer une tâche la place en tête de file, juste après les autres tâches en cours.
- Une tâche en cours commence le jour où elle a été démarrée. Si elle aurait déjà dû être terminée, elle est signalée en retard et prolongée jusqu'à ce soir.
- Une date « pas avant le » repousse le début d'une tâche.
- Une tâche terminée apparaît en grisé : elle se termine le jour où elle a été finie et dure le temps réellement passé.
- Quand des tâches se chevauchent (plusieurs tâches en cours, par exemple), elles sont affichées sur plusieurs lignes.

## Architecture

```
Orbit/
├── Model/        Logique métier pure (Foundation uniquement), entièrement testée
│   ├── ManDays.swift           Durées au ⅛ de jour : calcul, affichage, saisie
│   ├── Entities.swift          Team, Member, TaskItem, Subtask
│   ├── Calibration.swift       Pondération EMA
│   ├── WorkCalendar.swift      Jours travaillés, index de jours ouvrés
│   ├── Scheduler.swift         Placement des tâches dans le temps
│   ├── TimelineGeometry.swift  Conversion du planning en positions à l'écran
│   └── …
├── Store/        OrbitStore (@Observable) : état, actions et enregistrement JSON
└── Views/        Interface SwiftUI (planning, files, inspecteur, feuilles, réglages)
OrbitTests/       Tests Swift Testing du modèle et du store
```

Toutes les modifications passent par `OrbitStore`, qui les enregistre aussitôt dans `~/Library/Containers/com.littlebig.Orbit/Data/Library/Application Support/Orbit/orbit.json` (l'app est sandboxée). Si ce fichier devient illisible, il est mis de côté (`orbit-illisible-<date>.json`) au lieu d'être écrasé.

## Développement

Ouvrir `Orbit.xcodeproj` avec Xcode, puis ⌘R pour lancer l'app et ⌘U pour les tests. Les dossiers du projet sont synchronisés : tout fichier ajouté sous `Orbit/` ou `OrbitTests/` est automatiquement inclus dans la cible.

## Pistes

- Jours fériés et absences par personne.
- Export du planning (PDF, CSV).
- Synchronisation entre plusieurs postes (CloudKit).
