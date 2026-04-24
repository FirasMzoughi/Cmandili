# Chapitre 3 : Réalisation et mise en œuvre

## 3.1 Introduction

Après la phase d'analyse et de conception détaillée au chapitre précédent, ce troisième chapitre est consacré à la matérialisation concrète de la plateforme **Cmandili**. Il s'agit de décrire le passage d'un ensemble de diagrammes et de spécifications à un produit logiciel fonctionnel, testable et déployable. Cmandili n'est pas une application isolée mais un écosystème composé de **trois applications mobiles** coordonnées autour d'un **backend partagé** :

- une application **Client** destinée au consommateur final, qui permet de commander des repas, de faire ses courses, d'envoyer un colis en coursier ou de demander la collecte d'un paiement de facture ;
- une application **Chauffeur** destinée au livreur, qui permet d'accepter des courses, de se faire guider, de diffuser sa position et de consulter ses gains ;
- une application **Partenaire** destinée au restaurateur ou au gérant de supermarché, qui permet de recevoir et de traiter les commandes, de gérer le catalogue et de piloter l'activité.

Ces trois applications partagent une même base de données PostgreSQL hébergée sur Supabase, ce qui permet une synchronisation en temps réel entre tous les acteurs. Le chapitre s'articule autour des sections suivantes : l'environnement de travail et les technologies retenues (3.2), l'architecture globale du système et son modèle de données (3.3), la présentation fonctionnelle de chaque application (3.4), les captures d'écran commentées des principales interfaces (3.5), une réflexion sur les pistes d'amélioration (3.6), et enfin une conclusion qui fait le bilan du chapitre (3.7).

## 3.2 Environnement et technologies utilisés

Le choix des technologies a été guidé par trois contraintes principales : (i) disposer d'un socle **cross-platform** pour livrer iOS et Android depuis un même code source, (ii) maîtriser le coût d'infrastructure pour un projet de fin d'études tout en conservant des fonctionnalités de niveau production (authentification, temps réel, notifications push, stockage), et (iii) garder une architecture lisible et modulaire afin de faciliter la maintenance et l'évolution.

### 3.2.1 Environnement de développement

Le développement a été mené sous **Visual Studio Code** et **Android Studio**, en s'appuyant sur le SDK **Flutter** en version 3.0 ou supérieure et sur **Dart** 3.0. Le code source des trois applications est versionné avec **Git**. Les plateformes ciblées en priorité sont Android et iOS ; les configurations web, macOS, Linux et Windows sont conservées à titre expérimental mais ne font pas partie du périmètre livré.

### 3.2.2 Technologies front-end

Les trois applications partagent la même pile technologique front-end afin de mutualiser le savoir-faire et les composants réutilisables.

- **Flutter et Dart.** Flutter a été choisi pour sa capacité à produire un rendu natif homogène sur iOS et Android depuis une seule base de code. Le framework fournit nativement le système de design **Material 3**, qui a servi de base à l'identité visuelle des trois applications. La compilation en code natif garantit une fluidité suffisante pour afficher une carte Google Maps tout en recevant un flux de mises à jour en temps réel.
- **Flutter Riverpod (v2.x).** La gestion d'état repose sur Riverpod, qui combine l'injection de dépendances et un modèle de programmation réactif. Les `StreamProvider` sont particulièrement adaptés à notre cas d'usage puisqu'ils permettent d'exposer à l'interface un flux Supabase sans écriture d'un glue-code intermédiaire. Les `StateNotifierProvider` servent, quant à eux, aux états mutables locaux (panier, filtres, toggle ouvert/fermé).
- **Google Maps Flutter, Geolocator et Geocoding.** La cartographie utilise `google_maps_flutter` pour l'affichage, `geolocator` pour la position GPS en haute précision (filtre de distance de 10 mètres) et `geocoding` pour la conversion entre coordonnées et adresses. Côté client, le tracé d'itinéraire est calculé via l'API **Google Directions**, puis dessiné sous forme de polyligne sur la carte.
- **flutter_background_service.** Spécifique à l'application Chauffeur, ce paquet permet de maintenir la diffusion de la position GPS même lorsque l'application est réduite. Il utilise une notification persistante en premier plan sur Android et un mode compatible avec les contraintes d'Apple sur iOS.
- **Image Picker et Cached Network Image.** L'application Partenaire utilise `image_picker` pour permettre au gérant de sélectionner une photo dans la galerie ou via l'appareil photo, avec une compression à 80 % avant envoi. `cached_network_image` met en cache les images téléchargées afin d'éviter de recharger systématiquement les visuels de restaurants ou de produits.
- **Firebase Cloud Messaging et Flutter Local Notifications.** La réception des notifications push repose sur FCM côté système, tandis que `flutter_local_notifications` présente les messages lorsque l'application est au premier plan.
- **Flutter Localizations.** L'internationalisation est assurée par le mécanisme standard de Flutter, avec des fichiers `.arb` pour les trois langues prises en charge : **français, arabe et anglais**.
- **Freezed et JSON Serializable.** Ces deux outils de génération de code produisent les classes de modèles immuables et leur sérialisation JSON, ce qui réduit significativement les erreurs de mapping entre la base PostgreSQL et Dart.

### 3.2.3 Technologies back-end et services tiers

- **Supabase.** Supabase joue le rôle de *Backend as a Service* unique. Il fournit dans une même plateforme : une base **PostgreSQL** managée, un module d'**authentification** (email / mot de passe + fournisseurs OAuth), un moteur **Realtime** basé sur la publication des changements logiques PostgreSQL (*Postgres Changes*), un service de **Storage** pour les images et un environnement d'exécution d'**Edge Functions** écrites en TypeScript sur Deno. Ce choix a été motivé par la volonté d'éviter l'écriture d'une API REST intermédiaire : les applications parlent directement à la base via le client Supabase, avec la sécurité assurée par les règles **Row Level Security** (RLS).
- **Firebase Cloud Messaging (API v1).** Les notifications push sont envoyées par une Edge Function qui s'authentifie auprès de Google avec un compte de service. Chaque appareil enregistre son jeton FCM dans la table `device_tokens` lors de la connexion.
- **Konnect.** Passerelle de paiement en ligne adaptée au marché tunisien, intégrée dans l'application Client via une WebView. Une couche d'abstraction `PaymentGateway` permet d'envisager l'ajout ultérieur d'une autre passerelle sans refonte.
- **Google OAuth et Apple Sign-In.** Fournisseurs d'authentification sociale pour offrir un parcours d'inscription simplifié.
- **Google Directions API.** Utilisée côté client pour tracer l'itinéraire entre le chauffeur et le point de livraison.

Le tableau suivant récapitule les technologies par couche.

**Tableau 3.1 — Technologies utilisées, par couche**

| Couche | Technologie | Rôle principal |
|---|---|---|
| Front-end | Flutter / Dart | Framework UI cross-platform |
| Front-end | Riverpod | Gestion d'état réactive |
| Front-end | Google Maps, Geolocator, Geocoding | Cartographie et localisation |
| Front-end | flutter_background_service | Suivi GPS en arrière-plan (Chauffeur) |
| Front-end | FCM + Flutter Local Notifications | Notifications push |
| Back-end | Supabase (PostgreSQL) | Base de données relationnelle |
| Back-end | Supabase Auth | Authentification centralisée |
| Back-end | Supabase Realtime | Synchronisation en temps réel |
| Back-end | Supabase Storage | Stockage des images |
| Back-end | Supabase Edge Functions | Logique serveur en TypeScript |
| Services | FCM v1 | Canal de notifications push |
| Services | Konnect | Paiement en ligne |
| Services | Google Directions | Calcul d'itinéraires |
| Outils | Git, VS Code, Android Studio | Développement et versioning |

## 3.3 Architecture du système

### 3.3.1 Vue d'ensemble

Le système adopte une architecture à trois tiers orientée mobile. Les trois applications Flutter constituent la couche de présentation. Elles communiquent directement avec la plateforme Supabase, qui regroupe la couche de services (authentification, API générée automatiquement par PostgREST, moteur temps réel, fonctions serverless) et la couche de persistance (base PostgreSQL et bucket de stockage). Deux services tiers complètent le dispositif : Firebase Cloud Messaging pour la distribution des notifications push et Konnect pour le traitement des paiements en ligne.

**[Figure 3.1 : Architecture générale du système Cmandili]**

Les échanges entre les applications et Supabase se font principalement via HTTPS pour les requêtes CRUD et via WebSocket pour les abonnements temps réel. Les Edge Functions sont appelées de deux façons : soit directement par une application cliente lorsqu'une logique métier sensible doit rester côté serveur, soit indirectement par un *trigger* PostgreSQL qui déclenche une requête sortante via l'extension `pg_net`. Les jetons FCM enregistrés par les utilisateurs dans la table `device_tokens` sont ensuite utilisés par l'Edge Function `push-on-order-status` pour cibler les bons destinataires.

### 3.3.2 Architecture applicative : clean architecture par feature

Les trois applications partagent la même organisation logique, inspirée de la *clean architecture* mais simplifiée pour rester pragmatique à l'échelle d'un PFE. Le code est organisé par **feature** plutôt que par couche technique, ce qui permet de faire évoluer une fonctionnalité sans impacter les autres. Chaque feature se subdivise ensuite en trois sous-dossiers : `data/` (accès aux données et modèles), `presentation/` (écrans et widgets) et `providers/` (états Riverpod). Un dossier `core/` rassemble les éléments transverses : configuration Supabase, thème, utilitaires, providers globaux et routeur.

```
lib/
├── core/           # Config, thème, providers globaux, utils
│   ├── config/     # Paramètres Supabase, initialisation
│   ├── providers/  # Thème, langue, session
│   ├── theme/      # Palette, typographie, Material 3
│   └── utils/      # Formatage de devise, services de localisation
└── features/       # Organisation par domaine métier
    ├── auth/
    │   ├── data/            # AuthRepository, modèles utilisateur
    │   ├── presentation/    # AuthScreen, OnboardingScreen
    │   └── providers/       # authStateProvider
    ├── orders/
    │   ├── data/            # OrderRepository, modèle Order
    │   ├── presentation/    # OrderListScreen, OrderDetailScreen
    │   └── providers/       # ordersStreamProvider
    └── ...
```

Cette découpe facilite la lecture du code par un développeur nouvellement arrivé : en ouvrant un dossier de *feature*, il retrouve à la fois la logique, les écrans et l'état associé, sans avoir à naviguer entre plusieurs couches dispersées.

### 3.3.3 Modèle de données

La base PostgreSQL est commune aux trois applications. Elle regroupe une vingtaine de tables organisées en quatre grands ensembles fonctionnels.

- **Acteurs.** `profiles` étend la table `auth.users` de Supabase avec l'avatar et le téléphone. `partners` associe un utilisateur à l'entité commerciale qu'il exploite (restaurant ou supermarché) via un champ `entity_id`. `drivers` contient les informations du chauffeur, dont son véhicule, sa position courante (`current_lat`, `current_lng`) et son état en ligne.
- **Catalogue.** Deux couples de tables décrivent l'offre : `restaurants` avec `food_items` d'un côté, `supermarkets` avec `grocery_items` de l'autre. Chaque entité commerciale possède un statut d'ouverture (`is_open`), des frais de livraison, un minimum de commande et un emplacement géographique.
- **Commandes.** La table `orders` est la pièce centrale. Elle contient le statut du cycle de vie (`pending`, `confirmed`, `preparing`, `ready`, `pickedUp`, `onTheWay`, `delivered`, `cancelled`), les totaux, l'adresse de livraison et les horodatages clés. `order_items` enregistre le détail des lignes. `deliveries` lie une commande à un chauffeur et porte la position GPS courante du livreur, ce qui permet au client de suivre sa commande en direct. `payments` enregistre les opérations financières, qu'elles soient en espèces ou en ligne.
- **Transverses.** `notifications` stocke les notifications applicatives, `device_tokens` les jetons FCM, `reviews` les avis laissés par les clients.

**[Figure 3.2 : Diagramme simplifié du schéma relationnel]**

Trois mécanismes PostgreSQL sont particulièrement importants.

- **Row Level Security (RLS).** Chaque table sensible porte des politiques qui limitent les lignes accessibles selon l'identité de l'utilisateur authentifié. Par exemple, un partenaire ne voit que les commandes dont le `restaurant_id` correspond à son `entity_id`, et un client ne peut lire que ses propres commandes et ses propres paiements.
- **Triggers.** `handle_new_user` crée automatiquement un enregistrement dans `profiles` à chaque inscription. `handle_order_status_timestamps` renseigne les champs `confirmed_at` et `ready_at` quand le statut évolue. `handle_order_status_change` insère une notification dans la table `notifications` et déclenche l'Edge Function `push-on-order-status` via `pg_net`, ce qui envoie une notification push au bon destinataire.
- **Publication Realtime.** Les tables `orders`, `deliveries` et `drivers` sont ajoutées à la publication `supabase_realtime`. Les applications s'y abonnent avec des filtres précis (par `user_id`, par `entity_id` ou par `driver_id`), ce qui leur évite de recevoir des événements inutiles.

### 3.3.4 Flux temps réel et notifications

Pour illustrer l'interaction entre les trois applications et le backend, le scénario suivant retrace la vie d'une commande de bout en bout.

1. **Passage de commande.** Le client finalise son panier dans l'application Client et valide le paiement. Une ligne est insérée dans `orders` avec le statut `pending`.
2. **Réception côté partenaire.** L'application Partenaire maintient un abonnement Realtime sur `orders` filtré par son `entity_id`. L'événement INSERT est reçu en quelques centaines de millisecondes, et la commande apparaît dans la liste des nouvelles commandes. Simultanément, le trigger côté base déclenche une notification push via FCM.
3. **Acceptation.** Le partenaire ouvre la commande, la confirme, puis, après préparation, la marque comme `ready`. À chaque mise à jour de statut, le trigger `handle_order_status_change` exécute l'Edge Function qui pousse une notification au client (« Votre commande est prête ») et publie un événement temps réel consommé par l'application Client.
4. **Prise en charge par le chauffeur.** Dès qu'une commande atteint le statut `ready`, elle apparaît dans la liste des courses disponibles de l'application Chauffeur. L'acceptation crée un enregistrement dans `deliveries` qui lie la commande au chauffeur.
5. **Suivi GPS en direct.** L'application Chauffeur active alors le service d'arrière-plan. Toutes les cinq secondes environ, la position du livreur est écrite dans `deliveries.current_lat` et `deliveries.current_lng`. Ces champs sont écoutés en temps réel par l'application Client, qui met à jour le marqueur sur la carte Google Maps.
6. **Livraison.** Une fois la commande remise, le chauffeur change le statut en `delivered`. Une dernière notification est envoyée au client et au partenaire, et la transaction apparaît dans les gains du chauffeur, calculés par la fonction PostgreSQL `get_driver_earnings`.

**[Figure 3.3 : Séquence temps réel d'une commande]**

## 3.4 Présentation des applications

### 3.4.1 Application Client — cmandili_mobile

**Utilisateurs visés.** L'application Client s'adresse au grand public : toute personne disposant d'un smartphone Android ou iOS et souhaitant commander à domicile. Elle est localisée en français, arabe et anglais pour couvrir la clientèle tunisienne et francophone.

**Fonctionnalités principales.** L'application propose quatre services complémentaires regroupés sur un écran d'accueil unique. Le service **Food** permet de parcourir les restaurants, de consulter leur menu et de commander un repas. Le service **Supermarché** fonctionne sur le même principe pour les courses alimentaires. Le service **Courrier** propose un formulaire d'envoi de colis de point à point, avec saisie des adresses de retrait et de dépôt. Le service **Facture** permet de demander la collecte physique d'un paiement de facture par un coursier. Une fois la commande passée, le client peut suivre en direct le déplacement du chauffeur sur une carte, consulter l'historique de ses commandes, gérer ses adresses enregistrées, ses favoris et son profil.

**Spécificités techniques.** Le suivi de commande repose sur un `StreamProvider` Riverpod qui lit la table `deliveries` en temps réel. La carte Google Maps affiche simultanément trois marqueurs (client, chauffeur, point de retrait) et une polyligne calculée via l'API Directions. Le paiement s'effectue par défaut en espèces à la livraison, avec la possibilité d'ouvrir la WebView Konnect pour un règlement en ligne. L'authentification accepte l'email / mot de passe ainsi que Google OAuth et Apple Sign-In.

### 3.4.2 Application Chauffeur — cmandili_driver

**Utilisateurs visés.** Livreurs partenaires de la plateforme, équipés d'un smartphone avec GPS et connexion données. Une étape d'**enregistrement du véhicule** est obligatoire avant d'accéder aux courses : le chauffeur renseigne le type (moto, voiture, vélo, trottinette), la marque, le modèle, la plaque et la couleur.

**Fonctionnalités principales.** L'écran d'accueil affiche un tableau de bord résumant les courses disponibles et les courses actives. La **liste des commandes disponibles** est alimentée par un flux Supabase filtré sur le statut `pending` ou `ready` ; le chauffeur peut en accepter une par simple appui. Une fois la course acceptée, il bascule sur l'**écran de suivi** qui affiche la carte en direct et les boutons de changement de statut (arrivé au point de retrait, colis récupéré, en route, livré). L'écran **Gains** présente les revenus cumulés sur la journée, la semaine ou le mois, calculés par la fonction PostgreSQL `get_driver_earnings`. Enfin, l'écran **Profil** permet d'éditer ses informations, son véhicule, ses adresses enregistrées et ses méthodes de paiement.

**Spécificités techniques.** La particularité la plus notable est le suivi GPS en arrière-plan. L'application utilise `flutter_background_service` pour exécuter un *isolate* Dart séparé du thread principal. Cet isolate lit périodiquement la position via `Geolocator` et met à jour simultanément `deliveries.current_lat/lng` et `drivers.current_lat/lng` dans Supabase. Un `WidgetsBindingObserver` surveille le cycle de vie de l'application et bascule automatiquement l'état en ligne du chauffeur lorsqu'il ouvre ou ferme l'application.

### 3.4.3 Application Partenaire — cmandili_partner

**Utilisateurs visés.** Restaurateurs et gérants de supermarchés qui reçoivent des commandes via la plateforme. Un parcours d'**onboarding** recueille le nom commercial, l'adresse, le téléphone, le type d'établissement et le logo lors de la première connexion.

**Fonctionnalités principales.** L'accueil présente un **tableau de bord** avec les statistiques du jour (nombre de commandes par statut, chiffre d'affaires) et un interrupteur global **Ouvert / Fermé** qui permet de mettre l'établissement en pause en un seul geste. La **liste des commandes** propose un filtre par statut (Nouvelles, Confirmées, En préparation, Prêtes, En route, Livrées, Annulées). L'**écran de détail** d'une commande affiche les articles, l'adresse de livraison, le mode de paiement et un bouton d'avancement de statut. La **gestion du menu** permet de créer, modifier ou désactiver un produit, avec un formulaire incluant le nom, la description, le prix, la catégorie, une photo et, pour les restaurants, le temps de préparation et les tags diététiques. Une fonctionnalité de **Happy Hour** offre la possibilité de définir une remise temporaire sur un produit. Enfin, l'écran **Rapports** fournit une vue d'analyse financière sur différentes périodes.

**Spécificités techniques.** L'abonnement aux changements de la table `orders` est filtré par `entity_id`, ce qui garantit qu'un partenaire ne reçoit que ses propres événements, même à grande échelle. L'upload des photos de produits passe par `image_picker` (compression à 80 %) puis par Supabase Storage, avec l'URL publique enregistrée dans `food_items.image_url` ou `grocery_items.image_url`. L'interrupteur Ouvert / Fermé est synchronisé sur la table correspondante (`restaurants.is_open` ou `supermarkets.is_open`), ce qui rend l'état cohérent entre tous les appareils connectés au même compte.

## 3.5 Interfaces des applications

Cette section illustre les principales interfaces des trois applications. Chaque figure est un emplacement réservé à remplir avec les captures d'écran réelles, accompagné d'un commentaire descriptif.

### 3.5.1 Interfaces de l'application Client

**[Figure 3.4 : Écran d'authentification]** — Accueille l'utilisateur avec un arrière-plan animé, les champs email et mot de passe, un lien d'inscription et les deux boutons de connexion sociale (Google, Apple). Un sélecteur de langue en haut permet de basculer entre français, arabe et anglais.

**[Figure 3.5 : Écran d'accueil et sélecteur de services]** — Présente en bandeau horizontal les quatre services (Food, Supermarché, Courrier, Factures), une barre de recherche, une liste de catégories filtrables et la liste des restaurants à proximité avec leur note et leurs frais de livraison.

**[Figure 3.6 : Détail d'un restaurant et panier flottant]** — Affiche la bannière du restaurant, son menu regroupé par catégorie, avec pour chaque plat une image, un prix et un bouton d'ajout. Un panier flottant en bas de l'écran récapitule le nombre d'articles et le total.

**[Figure 3.7 : Panier et checkout]** — Permet de vérifier les quantités, de choisir une adresse de livraison parmi celles enregistrées ou d'en ajouter une nouvelle, de sélectionner le mode de paiement (espèces ou en ligne via Konnect) et de confirmer la commande.

**[Figure 3.8 : Suivi en direct de la commande]** — Présente une carte Google Maps avec les marqueurs du chauffeur, du restaurant et de l'adresse de livraison, ainsi qu'une polyligne d'itinéraire. Une feuille coulissante en bas de l'écran affiche la chronologie du statut de la commande et les coordonnées du chauffeur.

**[Figure 3.9 : Profil et historique des commandes]** — Regroupe les informations personnelles, les adresses enregistrées, les méthodes de paiement, l'historique des commandes et l'accès au support.

### 3.5.2 Interfaces de l'application Chauffeur

**[Figure 3.10 : Authentification et enregistrement du véhicule]** — Présente l'écran de connexion, suivi du formulaire d'enregistrement du véhicule obligatoire au premier lancement : type de véhicule, marque, modèle, plaque d'immatriculation, couleur.

**[Figure 3.11 : Tableau de bord du chauffeur]** — Affiche le résumé de la journée : nombre de courses disponibles, course active en cours, revenus du jour et raccourcis vers la liste des commandes.

**[Figure 3.12 : Liste des commandes disponibles]** — Montre les commandes à prendre en charge avec pour chacune le montant de la livraison, l'adresse de retrait et l'adresse de livraison, ainsi qu'un bouton d'acceptation. L'écran supporte le *pull-to-refresh*.

**[Figure 3.13 : Suivi d'une course active]** — Présente la carte en direct avec la position du chauffeur, le point de retrait et le point de livraison, un indicateur de distance et une série de boutons pour faire avancer le statut (arrivé, récupéré, livré).

**[Figure 3.14 : Écran des gains]** — Permet de filtrer les revenus sur la journée, la semaine ou le mois, affiche le total calculé par la fonction `get_driver_earnings` et liste les dernières courses effectuées avec leur rémunération individuelle.

### 3.5.3 Interfaces de l'application Partenaire

**[Figure 3.15 : Tableau de bord partenaire]** — Affiche le statut Ouvert / Fermé commutable en un geste, les statistiques du jour (commandes par statut, chiffre d'affaires) et la liste des commandes en attente de traitement.

**[Figure 3.16 : Liste des commandes avec filtres par statut]** — Présente les commandes sous forme de cartes, avec une barre de chips pour filtrer par statut (Nouvelles, Confirmées, En préparation, Prêtes, En route, Livrées, Annulées).

**[Figure 3.17 : Détail d'une commande et mise à jour de statut]** — Détaille les articles commandés, le total, le mode de paiement, l'adresse du client et propose le bouton contextuel d'avancement du statut (par exemple « Marquer comme prête »).

**[Figure 3.18 : Gestion du menu]** — Affiche la liste des produits filtrable par catégorie, avec leur disponibilité. Un bouton d'ajout ouvre le formulaire de création ou d'édition : nom, description, prix, catégorie, image, temps de préparation, tags.

**[Figure 3.19 : Rapports et analytique]** — Présente les indicateurs financiers sur la période choisie (jour, semaine, mois) : nombre total de commandes, commandes livrées, commandes annulées, chiffre d'affaires, frais de livraison perçus.

## 3.6 Améliorations et perspectives

Le produit actuel répond aux besoins fonctionnels définis dans le cahier des charges, mais plusieurs pistes d'amélioration se dégagent de cette phase de réalisation.

- **Tests automatisés.** Le périmètre actuel ne comporte pas de tests unitaires ou d'intégration systématiques. Une couverture minimale des repositories Supabase et des providers Riverpod, complétée par des tests d'intégration sur les parcours critiques (passage de commande, mise à jour de statut, suivi GPS), renforcerait significativement la confiance dans chaque évolution.
- **Intégration continue et déploiement.** Un pipeline GitHub Actions enchaînant l'analyse statique (`flutter analyze`), le linting, les tests puis la génération des builds, combiné à une diffusion automatique sur TestFlight et Play Store en canal interne, fluidifierait les cycles de livraison.
- **Notifications temps réel côté Chauffeur.** L'application Chauffeur utilise encore un mécanisme de polling pour la table `notifications`, là où le reste de la plateforme s'appuie sur les *streams* Supabase. Harmoniser cette partie améliorerait la réactivité et réduirait la consommation de bande passante.
- **Généralisation du paiement en ligne.** Konnect est intégré techniquement mais le paiement par défaut reste le règlement en espèces à la livraison. Finaliser le parcours en ligne (gestion des remboursements, des échecs de paiement et des statuts intermédiaires) permettrait de proposer un véritable choix à l'utilisateur.
- **Renforcement de la sécurité.** Un audit approfondi des politiques RLS, une rotation régulière des clés stockées dans les fichiers `.env`, et le déplacement de la clé Google Directions derrière une Edge Function proxy éviteraient l'exposition de secrets côté client.
- **Observabilité.** L'intégration d'un outil comme Sentry pour la remontée d'erreurs côté applications mobiles, associée à des logs structurés sur les Edge Functions, faciliterait le diagnostic en production.
- **Expérience utilisateur.** Un mode hors-ligne partiel (consultation du menu déjà chargé, brouillon de commande), des états vides et des *shimmers* plus soignés, ainsi qu'une vérification de la complétude des traductions arabes et du support RTL, apporteraient une finition visible par l'utilisateur final.
- **Fonctionnalités métier.** La plateforme pourrait être enrichie d'un module de gestion des codes promotionnels, d'un système de parrainage, d'une note et d'un commentaire après livraison (la table `reviews` existe déjà mais n'est pas encore exploitée côté interface) et d'une gestion fine des tranches horaires d'ouverture par jour.

## 3.7 Conclusion

Ce chapitre a rendu compte de la mise en œuvre concrète de la plateforme Cmandili. Les trois applications mobiles — Client, Chauffeur, Partenaire — ont été développées avec Flutter et Riverpod, et s'appuient sur un backend Supabase partagé qui centralise l'authentification, la persistance, la synchronisation en temps réel, le stockage des images et la logique métier asynchrone via des Edge Functions. Les notifications push sont livrées par Firebase Cloud Messaging, le paiement en ligne est assuré par Konnect et la cartographie par Google Maps associée à l'API Directions.

La mise en œuvre a permis de lever plusieurs défis techniques : le suivi GPS en arrière-plan côté Chauffeur, la sécurisation par *Row Level Security* du modèle de données, la coordination en temps réel entre trois applications distinctes par l'intermédiaire de flux Supabase et de triggers PostgreSQL, et l'internationalisation sur trois langues. Le système obtenu est fonctionnel, extensible et adapté à un déploiement en phase pilote.

Le chapitre suivant présentera la démarche de tests et de validation mise en place pour éprouver la robustesse du système dans des conditions proches de la production, avant de conclure ce rapport par un bilan général du projet et par les perspectives d'évolution à moyen terme.
