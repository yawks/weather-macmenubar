# Instructions pour compiler WeatherBar sur votre Mac

Ce projet est conçu pour fonctionner sur macOS 13.0 ou plus récent. Comme vous l'avez souhaité, il utilise Swift, SwiftUI, SwiftCharts et MapKit.

## Prérequis
- Un Mac avec **Xcode 14.0** ou plus récent installé.
- Une clé API **OpenWeatherMap One Call 3.0**.

## Étapes de compilation
1. Créez un nouveau projet dans Xcode : **File > New > Project...**
2. Choisissez le template **App** sous l'onglet **macOS**.
3. Nommez le projet `WeatherBar`.
4. Dans les options du projet, assurez-vous que :
   - Interface : **SwiftUI**
   - Language : **Swift**
5. Supprimez les fichiers créés par défaut (`ContentView.swift` et `WeatherBarApp.swift`).
6. Copiez tous les fichiers du dossier `WeatherBar/` que j'ai générés dans votre projet Xcode.
7. Dans les réglages du projet (onglet **General**), assurez-vous que la version minimale de déploiement est **macOS 13.0**.
8. Dans l'onglet **Signing & Capabilities**, ajoutez la capability **App Sandbox** (ou désactivez-la si vous préférez, mais assurez-vous que **Outgoing Connections** est coché pour permettre les appels API).
9. Appuyez sur `Cmd + R` pour lancer l'application.

## Fonctionnement
- Au premier lancement, une fenêtre de réglages s'ouvrira.
- Saisissez votre clé API OpenWeatherMap.
- Recherchez votre ville (l'autocomplétion utilise MapKit).
- Une fois configuré, l'icône météo apparaîtra dans votre barre de menus.
- Cliquez sur l'icône pour ouvrir le widget détaillé.

## Structure des fichiers
- `Models/` : Définition des données et types.
- `Services/` : Logique réseau (OpenWeatherMap) et recherche de lieux (MapKit).
- `Views/` : Interface SwiftUI (Widget principal, Graphiques, Réglages).
- `App/` : Logique système macOS (Barre de menus, Fenêtre flottante).
