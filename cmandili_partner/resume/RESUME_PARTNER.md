# Résumé du Projet : Cmandili Partner

Ce document fournit une vue d'ensemble détaillée du projet `cmandili_partner`, destinée à servir de point d'entrée pour les prochaines sessions de développement. Il documente l'architecture, les fonctionnalités principales et la structure du code.

## 1. Vue d'ensemble du Projet

`cmandili_partner` est l'application partenaire (restaurant, supermarché, magasin) de l'écosystème Cmandili. Elle permet aux partenaires de gérer leurs commandes, leur menu, leur profil commercial et de consulter leurs rapports financiers. Elle est développée en Flutter.

## 2. Architecture Technique

*   **Framework :** Flutter
*   **Gestion d'état :** Riverpod (`flutter_riverpod`)
*   **Backend / BaaS :** Supabase (Authentification, Base de données PostgreSQL en temps réel)
*   **Architecture :** Feature-first (les dossiers sont regroupés par fonctionnalité, ex: `auth`, `orders`, `menu`).
*   **Thématisation :** Support du mode clair/sombre.
*   **Localisation :** Support multi-langues (Arabe, Anglais, Français) via `flutter_localizations` (fichiers `.arb`).
*   **Cartographie :** Intégration de cartes (Mapbox/Google Maps) pour la gestion des adresses/livraisons.

## 3. Structure des Dossiers (`lib/`)

L'application est structurée de manière modulaire :

*   `main.dart` : Point d'entrée de l'application. Configure Supabase, Riverpod, les thèmes et la navigation.
*   `firebase_options.dart` : Configuration Firebase (probablement pour les notifications push ou Crashlytics).
*   **`core/`** : Code partagé, utilitaires et configurations globales.
    *   `config/` : Configuration Supabase.
    *   `providers/` : Providers globaux (thème, localisation).
    *   `push/` : Service de notifications push.
    *   `theme/` : Couleurs et thèmes de l'application.
    *   `utils/` : Utilitaires (ex: formatage de la monnaie).
    *   `widgets/` : Widgets réutilisables (ex: `app_map.dart`).
*   **`features/`** : Modules de fonctionnalités indépendantes.
    *   **`auth/`** : Authentification et inscription des partenaires.
        *   Models : `user_model`, `partner_model`.
        *   Écrans : `auth_screen`, `partner_onboarding_screen`.
    *   **`home/`** : Tableau de bord principal.
        *   Écrans : `home_screen`.
    *   **`menu/`** : Gestion des articles du menu/catalogue.
        *   Models : `food_item`, `grocery_category`, `grocery_item`, `item_variant`.
        *   Écrans : `menu_screen`, `add_edit_item_screen`, `happy_hour_setup_screen`.
    *   **`notifications/`** : Centre de notifications.
    *   **`orders/`** : Gestion des commandes entrantes et de leur historique.
        *   Models : `order`, `cart_item`, `delivery_address`.
        *   Écrans : `partner_orders_screen`, `order_detail_screen`, `order_tracking_screen`.
        *   Widgets : `voice_note_player` (pour écouter les instructions vocales des clients).
    *   **`profile/`** : Gestion du profil du partenaire et des paramètres.
        *   Écrans : `profile_screen`, `business_info_screen`, `payout_screen`, etc.
    *   **`reports/`** : Analyses et statistiques de vente.
        *   Écrans : `reports_screen`.
*   **`l10n/`** : Fichiers de localisation (`.arb`).

## 4. Fonctionnalités Clés Implémentées

*   **Authentification et Onboarding :** Connexion et écran d'accueil spécifique aux partenaires.
*   **Gestion des Commandes :** Réception des commandes en temps réel, mise à jour du statut, lecture des notes vocales des clients.
*   **Gestion du Menu :** Ajout, modification des articles du menu, gestion des catégories, configuration des "Happy Hours".
*   **Profil Commercial :** Gestion des informations du restaurant/magasin, gestion des paiements (`payout_screen`).
*   **Rapports :** Visualisation des performances.
*   **Support Multi-langues :** Interface traduite en AR, EN, FR.

## 5. Instructions pour la Suite du Développement

Pour toute prochaine session, référez-vous à ce document pour comprendre l'état actuel de `cmandili_partner`.

1.  **Respecter l'Architecture :** Tout nouveau code doit être placé dans la `feature` appropriée ou dans `core` s'il est partagé.
2.  **State Management :** Utiliser Riverpod (`StateNotifierProvider`, `FutureProvider`, etc.) comme défini dans les autres modules.
3.  **Base de données :** Interagir avec Supabase via les fichiers `_repository.dart` dans le dossier `data/` de chaque feature.
4.  **UI/UX :** Utiliser les couleurs de `app_colors.dart` et s'assurer que les écrans supportent les thèmes clairs et sombres ainsi que les langues LTR (anglais/français) et RTL (arabe).

---
*Dernière mise à jour : Mai 2026*
