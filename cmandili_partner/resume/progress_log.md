# Journal de Progression (Progress Log) - cmandili_partner

*Ce document sert de source de vérité pour suivre l'état d'avancement des fonctionnalités, décisions techniques et configurations. Il doit être consulté avant chaque nouvelle session de développement pour comprendre le contexte récent.*

---

## Session : Implémentation du "Menu Scanner" (Scanner de Menu par IA)
**Date :** 10 Mai 2026

### 1. Backend (Supabase Edge Functions)
- **Fonction `scan-menu` :** Déployée avec succès.
- **Modèle IA :** Utilisation de Google Gemini (1.5 Flash) pour analyser l'image et extraire les articles du menu.
- **Améliorations du Parsing :** Le prompt a été strictement configuré pour forcer une réponse en JSON brut. Une étape de nettoyage via Regex a été implémentée dans `index.ts` (`extractedText.replace(/```json/gi, '').replace(/```/g, '').trim()`) afin de s'assurer qu'aucun bloc Markdown ne vienne casser la méthode `JSON.parse()`.
- **Logique de Base de Données :** La fonction effectue un `INSERT` en lot (bulk insert). Elle s'adapte dynamiquement pour insérer dans la table `food_items` (pour les restaurants) ou `grocery_items` (pour les supermarchés) en fonction du `partnerType`.

### 2. Frontend (Flutter)
- **`MenuScannerProvider` :** Intégration d'un Riverpod StateNotifier pour gérer le processus de scan (gestion de l'état de chargement, erreurs, et succès) et la conversion de l'image en Base64.
- **Sélection de l'Image :** Le bouton `Scan Menu` dans `menu_screen.dart` n'ouvre plus directement l'appareil photo. Il affiche désormais un `showModalBottomSheet` permettant à l'utilisateur de choisir l'image source entre :
  1. `Take a Photo` (Caméra)
  2. `Choose from Gallery` (Galerie)
- L'utilisation du package `image_picker` gère ces deux sources.
- **UI/UX :** Ajout d'un overlay de chargement bloquant pendant que l'IA traite l'image, et affichage de notifications (SnackBar) pour remonter les éventuelles erreurs ou confirmer l'ajout des articles.

### 3. Configuration
- **Variables d'Environnement :** La clé d'API pour Gemini (`GEMINI_API_KEY`) a été configurée dans les Secrets de Supabase pour que la fonction Edge puisse s'authentifier auprès de Google.

### 4. Localisation (i18n)
- Les traductions suivantes ont été ajoutées dans les fichiers `.arb` (AR, FR, EN) et le code généré via `flutter gen-l10n` :
  - `scanMenu`
  - `scanMenuSuccess`
  - `scanMenuError`
  - `scanMenuLoading`
  - `scanningMenu`
  - `scanMenuEmptyState`
  - `takePhoto`
  - `chooseFromGallery`

---

## Session : Correction du Bug de l'API Gemini (Menu Scanner)
**Date :** 12 Mai 2026

### Ce qui a été corrigé :
- **Propagation de l'Erreur (Flutter) :** Modification de `menu_repository.dart` pour attraper les `FunctionException` de Supabase et extraire le contenu exact de l'erreur (`e.details`). Cela permet d'afficher la véritable erreur de l'Edge Function (ex: "400 Bad Request") au lieu du message masqué et statique "Failed to extract items from image".
- **Format du Payload Gemini (Edge Function) :** L'API Gemini (via Google Cloud API Gateway) rejetait le corps de la requête (erreur `INVALID_ARGUMENT`) car les clés JSON étaient en `snake_case` (`inline_data`, `mime_type`, `response_mime_type`). Elles ont été corrigées pour respecter le format imposé `camelCase` (`inlineData`, `mimeType`, `responseMimeType`).
- **Fiabilité de la Clé API :** Ajout d'une protection dans `index.ts` qui supprime par Regex (`.replace(/^["']+|["']+$/g, '')`) les guillemets accidentels autour de la variable d'environnement `GEMINI_API_KEY` (souvent insérés par erreur lors du `supabase secrets set` sur Windows) et utilisation de `encodeURIComponent()` dans l'URL.

## Session : Correction du Bug 400 "Failed to Process Image with Gemini"
**Date :** 13 Mai 2026

### Problèmes identifiés :
- **Bug #1 — `mimeType` hardcodé :** L'Edge Function déclarait toujours `"image/jpeg"` dans le payload Gemini, même si l'utilisateur sélectionnait une image PNG ou WebP depuis la galerie. Gemini rejetait alors la requête avec une erreur 400 `INVALID_ARGUMENT`.
- **Bug #2 — `responseMimeType: "application/json"` :** Ce paramètre dans `generationConfig`, combiné à une requête multimodale (image + texte), causait des erreurs 400 sur certaines versions de Gemini 1.5 Flash. Il a été retiré.
- **Bug #3 — Parsing des erreurs Flutter :** `e.details` dans un `FunctionException` Supabase peut être un `Map<String,dynamic>` (JSON parsé), une `String` brute, ou `null`. L'ancien code faisait `.toString()` directement, produisant des messages comme `{error: ...}` au lieu du vrai message.
- **Bug #4 — Payload trop lourd :** Images 1200×1200 en qualité 85 pouvant dépasser 1 Mo, ce qui augmente les risques de timeout ou de rejet.

### Ce qui a été corrigé :

#### `supabase/functions/scan-menu/index.ts`
1. **Détection dynamique du MIME type** — Via regex sur le préfixe `data:image/xxx;base64,`. Si absent, inspection via magic numbers (PNG = `\x89PNG`, WebP = `RIFF`). Fallback : `image/jpeg`.
2. **Suppression de `responseMimeType`** — La réponse JSON est maintenant extraite manuellement du texte retourné par Gemini.
3. **Extraction JSON robuste** — Nettoyage des backticks Markdown + extraction de la sous-chaîne `{ ... }` en cas de texte parasite autour.
4. **Messages d'erreur précis** — En cas d'erreur Gemini, le `message` interne de l'objet erreur Google est extrait et renvoyé au client Flutter.
5. **`finishReason` loggé** — Permet de détecter les blocages par les filtres de sécurité Gemini.

#### `lib/features/menu/data/menu_repository.dart`
- Ajout de la méthode `_extractErrorMessage()` qui gère `Map`, `String`, et `null` pour extraire proprement le champ `error` renvoyé par l'Edge Function.
- `data['count'] as num).toInt()` — Évite un crash si Gemini retourne `count: 0` comme entier Dart/JSON.

#### `lib/features/menu/providers/menu_scanner_provider.dart`
- Résolution réduite à `1024×1024` et qualité à `75` pour alléger le payload et diminuer les erreurs de timeout.

### Déployé :
- `supabase functions deploy scan-menu --project-ref hoqlxxtphskgxktqjpfu` → ✅ Succès

---

## État Actuel & Prochaines Étapes
- **État :** Les corrections du 13 Mai corrigent les causes racines de l'erreur 400. L'Edge Function détecte maintenant le bon format d'image et ne passe plus le paramètre `responseMimeType` conflictuel.
- **Problème Résiduel Potentiel :** Si l'erreur persiste avec le message `API key not valid` ou `PERMISSION_DENIED`, la clé `GEMINI_API_KEY` dans les secrets Supabase est invalide ou expirée → générer une nouvelle clé sur [Google AI Studio](https://aistudio.google.com/app/apikey) et la resetter via `npx supabase secrets set GEMINI_API_KEY=<nouvelle_clé> --project-ref hoqlxxtphskgxktqjpfu`.
- **Prochaine étape prévue :** Poursuivre le développement global du dashboard partenaire.
