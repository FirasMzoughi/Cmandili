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
}
