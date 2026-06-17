// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Cmandili';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get fullName => 'Nom complet';

  @override
  String get or => 'OU';

  @override
  String pleaseEnter(Object field) {
    return 'Veuillez entrer votre $field';
  }

  @override
  String get validEmail => 'Veuillez entrer un email valide';

  @override
  String get passwordLength =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get lightMode => 'Mode clair';

  @override
  String get profile => 'Profil';

  @override
  String get logout => 'Déconnexion';

  @override
  String get home => 'Accueil';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get search => 'Rechercher...';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get noNotifications => 'Aucune notification';

  @override
  String get notificationsWillAppearHere =>
      'Les notifications apparaîtront ici';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get retry => 'Réessayer';

  @override
  String get availableOrders => 'Commandes disponibles';

  @override
  String get noOrdersAvailable => 'Aucune commande disponible pour l\'instant';

  @override
  String get pullDownToRefresh => 'Tirez vers le bas pour actualiser';

  @override
  String get acceptOrder => 'Accepter la commande';

  @override
  String get failedToAcceptOrder => 'Échec de l\'acceptation de la commande';

  @override
  String get markPickedUp => 'Marquer comme récupéré';

  @override
  String get startDelivery => 'Démarrer la livraison (En route)';

  @override
  String get confirmDelivery => 'Confirmer la livraison';

  @override
  String get deliveryCompleted => 'Livraison terminée !';

  @override
  String get deliveringOrder => 'Livraison de la commande';

  @override
  String get deliveryLocation => 'Adresse de livraison';

  @override
  String get orderMarkedPickedUp => 'Commande marquée comme récupérée !';

  @override
  String get deliveryStarted => 'Livraison démarrée !';

  @override
  String get deliveryConfirmed => 'Livraison confirmée !';

  @override
  String get earnings => 'Revenus';

  @override
  String get totalEarnings => 'Revenus totaux';

  @override
  String get deliveriesCompleted => 'livraisons effectuées';

  @override
  String get recentDeliveries => 'Livraisons récentes';

  @override
  String get noDeliveriesYet => 'Aucune livraison pour l\'instant';

  @override
  String get couldNotLoadEarnings => 'Impossible de charger les revenus';

  @override
  String get couldNotLoadHistory => 'Impossible de charger l\'historique';

  @override
  String get driverProfileNotFound => 'Profil chauffeur introuvable';

  @override
  String get locationPermissionDenied => 'Permission de localisation refusée';

  @override
  String get savedAddresses => 'Adresses enregistrées';

  @override
  String get noAddressesSaved => 'Aucune adresse enregistrée';

  @override
  String get addressRemoved => 'Adresse supprimée';

  @override
  String get setDefault => 'Définir par défaut';

  @override
  String get addNewAddress => 'Ajouter une nouvelle adresse';

  @override
  String get labelHint => 'Étiquette (ex. Maison, Travail)';

  @override
  String get fullAddressLabel => 'Adresse complète';

  @override
  String get defaultLabel => 'Par défaut';

  @override
  String get paymentMethods => 'Moyens de paiement';

  @override
  String get noPaymentMethods => 'Aucun moyen de paiement enregistré';

  @override
  String get addNewCard => 'Ajouter une nouvelle carte';

  @override
  String get cardholderName => 'Nom du titulaire';

  @override
  String get cardNumber => 'Numéro de carte';

  @override
  String get expiryDate => 'Date d\'expiration (MM/AA)';

  @override
  String get vehicleInfoSaved => 'Informations du véhicule enregistrées';

  @override
  String get vehicleInfo => 'Informations du véhicule';

  @override
  String get vehicleType => 'Type de véhicule';

  @override
  String get vehicleMakeHint => 'Marque (ex. Yamaha)';

  @override
  String get required => 'Requis';

  @override
  String get vehicleModelHint => 'Modèle (ex. NMAX)';

  @override
  String get licensePlate => 'Plaque d\'immatriculation';

  @override
  String get color => 'Couleur';

  @override
  String get saveVehicleInfo => 'Enregistrer les informations';

  @override
  String get pleaseSignInFirst => 'Veuillez vous connecter d\'abord.';

  @override
  String get supportTicketSent =>
      'Ticket d\'assistance envoyé ! Nous vous contacterons bientôt.';

  @override
  String get helpSupport => 'Aide et support';

  @override
  String get howCanWeHelp => 'Comment pouvons-nous vous aider ?';

  @override
  String get fillFormDescription =>
      'Remplissez le formulaire ci-dessous et notre équipe vous répondra dans les 24 heures.';

  @override
  String get subject => 'Sujet';

  @override
  String get pleaseEnterSubject => 'Veuillez entrer un sujet';

  @override
  String get message => 'Message';

  @override
  String get pleaseEnterMessage => 'Veuillez entrer votre message';

  @override
  String get submitTicket => 'Envoyer le ticket';

  @override
  String get profileUpdated => 'Profil mis à jour avec succès !';

  @override
  String get failedToUpdateProfile => 'Échec de la mise à jour du profil.';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get phoneNumberLabel => 'Numéro de téléphone';

  @override
  String get bio => 'Bio';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get pleaseEnterName => 'Veuillez entrer votre nom';

  @override
  String get payoutInfoSaved => 'Informations de paiement enregistrées';

  @override
  String get earningsAndStatus => 'Revenus et statut';

  @override
  String get youAreOnline => 'Vous êtes en ligne';

  @override
  String get youAreOffline => 'Vous êtes hors ligne';

  @override
  String get canReceiveOrders => 'Vous pouvez recevoir de nouvelles commandes';

  @override
  String get turnOnToReceive => 'Activez pour recevoir des commandes';

  @override
  String get bankPayoutInfo => 'Informations bancaires';

  @override
  String get payoutsWeekly =>
      'Les paiements sont envoyés chaque semaine sur votre compte bancaire.';

  @override
  String get accountHolderName => 'Nom du titulaire du compte';

  @override
  String get bankName => 'Nom de la banque';

  @override
  String get ibanRib => 'IBAN / RIB';

  @override
  String get enterValidIban => 'Entrez un IBAN/RIB valide';

  @override
  String get savePayoutInfo => 'Enregistrer les informations';

  @override
  String get account => 'Compte';

  @override
  String get earningsAndPayout => 'Revenus et paiement';

  @override
  String get delivery => 'Livraison';

  @override
  String get you => 'Vous';

  @override
  String get deliveryAddress => 'Adresse de livraison';

  @override
  String get customer => 'Client';

  @override
  String get deliveryHistory => 'Historique des livraisons';

  @override
  String get completedDeliveriesAppearHere =>
      'Les livraisons terminées apparaîtront ici';

  @override
  String get delivered => 'Livré';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get locationOff =>
      'La localisation est désactivée. Activez-la dans les paramètres du téléphone.';

  @override
  String get locationDeniedSettings =>
      'Permission de localisation refusée. Accordez-la dans les paramètres de l\'application.';

  @override
  String get driverDashboard => 'Tableau de bord chauffeur';

  @override
  String get youHaveActiveDelivery => 'Vous avez une livraison active';

  @override
  String get readyForOrders => 'Prêt pour les commandes';

  @override
  String get youreOfflineFlip =>
      'Vous êtes hors ligne — activez le bouton pour commencer';

  @override
  String get available => 'Disponible';

  @override
  String get active => 'Active';

  @override
  String get activeDelivery => 'Livraison active';

  @override
  String get yourLocation => 'Votre position';

  @override
  String get expand => 'Agrandir';

  @override
  String get ordersWaitingForDriver => 'commande(s) en attente d\'un chauffeur';

  @override
  String get viewAvailableOrders => 'Voir les commandes disponibles';

  @override
  String get onTheWay => 'En route';

  @override
  String get noActiveDelivery => 'Aucune livraison active';

  @override
  String get acceptOrderToStart =>
      'Acceptez une commande pour commencer à livrer';

  @override
  String get browseAvailableOrders => 'Parcourir les commandes disponibles';

  @override
  String get orders => 'Commandes';
}
