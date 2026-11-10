# Warlock All-in-One 0.7.5

☕ Addon gratuit, développé par Vitam. Pour soutenir son développement :
[ko-fi.com/warlockallinone](https://ko-fi.com/warlockallinone).
*Free add-on by Vitam — support it on [Ko-fi](https://ko-fi.com/warlockallinone).*

## 0.7.5 — réglages par défaut, textes courts, fenêtre verrouillable

Une nouvelle installation reprend les réglages de l'auteur ; les textes de l'addon
sont plus courts dans les 8 langues ; la fenêtre des DoT se déverrouille dans
Ennemis et DoT → Affichage pour être déplacée. [Détails](docs/VERSION-0.7.5.md).

## 0.7.4 — un seul nom, moins d'appels au jeu

Commandes `/waio` et `/warlockallinone` ; réglages repris automatiquement sous leur
nouveau nom au premier chargement. Tableau des DoT, Kit, fragments, référence des
sorts et Does It Die font beaucoup moins d'appels au jeu, à affichage égal.
[Détails et mesures](docs/PERFORMANCE-0.7.4.md).

## 0.6.14 — mises à jour multicibles et Kit allégées

Le multicible regroupe les événements à 100 ms et déplace ses lignes existantes
sans reconstruire tout leur décor. Son interrupteur arrête effectivement le suivi ;
le masquage hors combat conserve le suivi des DoT et des cibles hors écran.
Le Kit partage un inventaire d'affichage invalidé par les changements de sacs,
d'entrée/sortie de combat et de monde. Les contrôles de destruction restent frais.
Kit et Nightfall ne scrutent plus leurs états périodiquement lorsqu'ils sont OFF.
Les gardes de combat, menus, file d'invocation, procs et matrice des six affichages
restent couverts par les tests. `/reload` après installation, puis essai en jeu.
[Modifications et validation](docs/PERFORMANCE-FIX.md).

[Audit des performances du 20 octobre 2026](docs/PERFORMANCE-AUDIT.md) :
57 scénarios synthétiques sur 0.6.13, travail de fond malgré OFF, scans des sacs et
amplification des événements multicibles. Correctifs 0.6.14 décrits ci-dessus ;
mesures CPU/FPS en jeu à réaliser.

## 0.6.13 — messages de chat optionnels depuis l'accueil

En haut de l'accueil, désactivez **Afficher les messages de l'addon dans le chat**
pour masquer immédiatement toutes ses sorties de chat, diagnostics et multicible
compris. Réactivez l'interrupteur pour les retrouver. Préférence conservée après
rechargement et changement de langue ; affichage activé par défaut.
La pause combat des fragments 0.6.12 est conservée. `/reload` après installation.
[Contrat et validation](docs/INTERFACE.md#messages-du-chat-0613).

## 0.6.12 — nettoyage des fragments suspendu pendant le combat

Les suppressions manuelles et automatiques exigent maintenant deux états publics hors
combat : `InCombatLockdown()` et `UnitAffectingCombat('player')`. Un état indisponible
diffère aussi le nettoyage. Contrôle dès l'entrée et juste avant chaque manipulation.
Un combat commencé pendant les vérifications rend `combat`, sans suspendre durablement
l'auto ; notre fragment déjà ramassé est restitué sans destruction. La reprise attend
une nouvelle entrée réelle hors combat. La confirmation d'une suppression précédente
et la suspension pour un véritable refus restent obligatoires.
Après installation, `/reload` hors combat ; vérifier surplus, combat puis reprise.
[Diagnostic, limites et recette](docs/SHARD-FIX.md).

## 0.6.11 — pilote de visibilité sans handle intermédiaire

Corrige le chemin multicible reproduisant `RestrictedFrames.lua: Invalid frame handle`
à l’entrée en combat avec **Masquer hors combat**. Le pilote natif `visibility`
agit directement sur la fenêtre ; le contrôleur et son snippet `GetFrameRef` sont retirés.
Le module garde son aperçu, son interrupteur, le masquage automatique, la position,
le redimensionnement et tout le design 0.6.10. Réglages conservés.
Après installation, `/reload` est nécessaire pour retirer l’ancien pilote en mémoire.
[Cause, reproduction et recette](docs/MULTITARGET-VISIBILITY-HANDLE.md).


## 0.6.10 — présentation multicible revue

- Aperçu animé à chaque image ; mises à jour réelles de vie ciblées sur leur événement.
- **Opacité des fonds** : 100 % réellement opaque, sans atténuer les portraits,
  les icônes, les textes ni les remplissages de vie/DoT.
- **Fonds** : toute la fenêtre, l’espace vide, les panneaux jusqu’aux icônes et les
  pistes vides de vie/DoT, y compris en HUD. Bordures et remplissages restent indépendants.
- Portrait natif du mob dans les trois styles All-in-One.
- **Cartes** : grands portraits, blocs espacés, accent et cadre, noms DoT sur deux lignes.
  **Compact** : portraits réduits, marges serrées, libellés sur une ligne.
  **Lignes épurées** : petit portrait, fond neutre, un séparateur horizontal, sans cadre fermé.
- Noms et décomptes au-dessus des pistes, couleurs par famille. **Largeur identique** :
  pistes complètes pour comparer les fractions restantes. **Proportionnelle** : mêmes
  pixels par seconde selon l’échelle commune affichée du catalogue ; ? sans profil connu.
  Aucune lecture d’aura secrète ni durée fabriquée à partir d’un lancement.

Réglages conservés ; `/reload` requis après installation, aucun nouveau module.
[Contrat, validation et recette](docs/MULTITARGET-REDESIGN.md).


## 0.6.9 — barres de test multicibles en direct

Dans `/waio dots`, activez **Barres de test** en haut de la page.
Trois ennemis explicitement simulés affichent les réglages actuels dans la vraie
fenêtre multicible. Styles HUD/AIO, icônes/barres égales/proportionnelles, vie,
police, fonds/bordures, repère 20 %, ticks, avertissements, familles, échelle,
opacité et redimensionnement réagissent en direct, hors combat.
Les options gardent leurs dépendances ; l’aperçu ne rend pas un réglage inapplicable actif.
Les durées tournent en boucle et ne constituent aucune observation d’aura.
Le masquage hors combat est temporairement contourné sans changer sa préférence.
Le suivi réel continue séparément ; fermer les options, le X de l’aperçu,
désactiver le module ou entrer en combat arrête les exemples. Le mode test
n’est pas sauvegardé. Aucun changement du correctif Kit 0.6.7 ni des réglages migrés.
[Contrat, preuves et recette](docs/MULTITARGET-PREVIEW.md).


## 0.6.8 — dossier au nom CurseForge

Le livrable utilise désormais `Warlock All-in-One/Warlock All-in-One.toc`, comme
le nom du projet [CurseForge](https://www.curseforge.com/wow/addons/warlock-all-in-one).
Logos, son et lecture de version utilisent le vrai nom chargé par WoW. Le correctif
des textes natifs du Kit (0.6.7) et les options MultiTarget (0.6.6) sont conservés.

Les réglages, les commandes et les noms des boutons sécurisés restent stables.
Lors du passage depuis l'ancien dossier, jeu fermé, copier dans chaque dossier
`SavedVariables` le fichier de réglages de l'ancien dossier (et son `.bak`) vers
`Warlock All-in-One.lua` et `Warlock All-in-One.lua.bak`, en conservant les originaux. Ne pas charger les deux
dossiers d'addon ensemble. **Relancer entièrement WoW** après ce changement de nom.
Tests locaux EN/FR réussis ; rendu réel de cette version encore à confirmer.
Aucune publication de cette version sur CurseForge.

## Correctif 0.6.7 — malédictions du Kit et objets interdits

Corrige l’erreur répétée `Kit.lua:432: SetAlpha ... forbidden object` : après
`SetDurationText`, les textes appartiennent au moteur natif et ne sont plus
conservés ni modifiés par Lua. Un parent propre à chaque famille choisit le
minuteur visible sur chacun des deux boutons, y compris après sélection en combat.
Filtres personnels, rangs et temps observés natifs sont conservés. Cadres mis en
cache, aucun nouveau timer Lua. Depuis la 0.6.6, `/reload` suffit après mise à jour.
[Cause, contrat et recette](docs/ACTION-KIT.md#067--textes-natifs-interdits).

## Candidat local 0.6.6 — options Ennemis & DoT

Audit de la page active et corrections du rendu : largeur/hauteur effectives,
fonds, bordures et sélection, dépendances, repère de vie et échelle de fenêtre.
Les familles d’effets et dixièmes utilisent les cadres et liaisons existants.
La police initialisée dès création (0.6.5) et le pilote de visibilité sont conservés.
[Matrice complète, preuves synthétiques et recette en jeu](docs/MULTITARGET-OPTIONS-AUDIT.md).
Historique 0.6.6 : candidat initialement non installé et non publié. Depuis la 0.6.5,
`/reload` suffit après une installation autorisée ; aucun nouveau module au TOC.

## Correctif local 0.6.5 — initialisation des polices

Corrige `FontString:SetText(): Font not set` lors du passage aux barres : chaque
nouveau texte reçoit sa police avant toute écriture ou liaison au conteneur natif.
Après mise à jour depuis la 0.6.4 déjà chargée, `/reload` suffit (TOC inchangé hors version).
Tests synthétiques renforcés ; confirmation du rendu réel encore attendue.

## Version locale de test 0.6.4 — présentation hybride

Dans Ennemis & DoT, deux choix indépendants : vie Warlock HUD / Warlock All-in-One,
et DoT en icônes / barres identiques / barres proportionnelles. Le moteur MultiTarget
et la fenêtre 0.6.3 sont conservés. Les changements sous restrictions sont différés.
Les fantômes hors champ ne reçoivent aucun timer d'aura inventé.

**Quitter complètement WoW puis relancer après installation** : nouveau module dans le TOC.
Tests locaux synthétiques réussis ; rendu réel de cette version encore à valider.
[Limites, audit et recette](docs/MULTITARGET-PRESENTATION.md).

Boîte à outils du démoniste pour WoW Forever (client `_classic_beta_`, interface
16001) : DoT sur les ennemis engagés, kit d'actions sécurisé, fragments d'âme,
alerte Crépuscule, ticks de canalisation et grimoire. Code original, licence MIT, sauf la fenêtre
DoT multi-cibles reprise de **Warlock HUD** (licence Apache 2.0, voir `WarlockAllInOne/MultiTarget/`).

**Installation / mise à jour** : utiliser le dossier `Interface/AddOns/Warlock All-in-One`,
puis **quitter et relancer WoW**. Pour migrer depuis l'ancien dossier, suivre
la copie des réglages décrite en tête de ce document.

## Nouveautés 0.6.3

- **Retour à la fenêtre multi-cibles de la 0.6.0** : avec la 0.6.1 elle ne s'affichait plus.
  Fond, titre, compteur, X et poignée sont de retour, et « Afficher le cadre » est retiré. Le
  masquage hors combat que la 0.6.1 avait activé d'office est désactivé une fois ; l'option
  reste dans Ennemis & DoT.
- Conservés : calculs du build 70450, nombre de pierres d'âme, bouton de minimap LibDBIcon.

## Nouveautés 0.6.2

- **Bouton de minimap standard.** Quand un autre addon a déjà chargé LibDBIcon (Leatrix Plus,
  Questie, Details, AtlasLoot…), le bouton passe par cette bibliothèque sous le nom
  **Warlock All-in-One** : les regroupeurs de boutons (option de Leatrix Plus) affichent ce nom
  et la bulle de l'addon au lieu de `WarlockAllInOneMinimap`. Il garde sa position et le
  réglage Minimap. Sans LibDBIcon, l'ancien bouton reste utilisé. Aucune bibliothèque n'est
  embarquée.

## Nouveautés 0.6.1

- **Calculs des sorts rétablis.** Le client est passé au build 1.60.1.70450 et l'addon
  n'acceptait que le 70425 : grimoire et infobulles n'affichaient plus de dégâts. Données
  régénérées depuis les tables DB2 du 70450 (aucune valeur ne change). Les builds de correctif
  plus récents de la même version 1.60.1 sont désormais acceptés.
- **Fenêtre multi-cibles réduite aux lignes des ennemis** : plus de fond, de titre, de compteur,
  de X ni de poignée. Masquée hors combat par défaut (l'ancien réglage est activé une fois).
  Pour la déplacer ou la redimensionner : **Ennemis & DoT → Afficher le cadre**, hors combat ;
  le combat referme ce mode.
- **Kit : nombre de pierres d'âme dans les sacs** sur le bouton Pierre d'âme (tous rangs),
  comme le nombre de pierres de soins, et dans son infobulle.

## Nouveautés 0.6.0

**Ennemis & DoT = la fenêtre « Multi-Target DoTs » de Warlock HUD.** À ta demande, l'ancien
cadre de cartes ennemies est remplacé par le module multi-cibles de
**Warlock HUD** 0.43.0 (projet CurseForge 1727219, licence
Apache 2.0) : jusqu'à 16 ennemis (barres de nom, cible, cibles du groupe/raid), portrait, marqueur
de raid, barre de vie avec repère 20 %, emplacements natifs de tes DoT avec compte à rebours,
estimation des dégâts restants (ambre Corruption, violet Fléau, turquoise Siphon de vie, rouge
Immolation) et lignes grises « vues en dernier ». Lecture seule : cibler par les barres de nom
ou Tab (le clic sur les cartes disparaît avec elles). Hors combat : glisser le titre pour
déplacer, la poignée en bas à droite pour redimensionner, X pour fermer (= module coupé).
Réglages dans **Ennemis & DoT** : masquer hors combat, opacité, réinitialiser position/taille,
dixièmes de seconde, repère 20 %, familles suivies. Textes traduits dans les 8 langues ; noms
globaux renommés, donc Warlock HUD peut rester installé à côté. Dégâts estimés à partir de
l'identifiant du sort (pas de la description anglaise). Le reste de l'addon est inchangé.
Fichiers repris, licence et modifications : `MultiTarget/LICENSE` et `MultiTarget/NOTICE.txt`.

## Nouveautés 0.5.12

**Calculs identiques dans toutes les langues** : la durée, les ticks et les dégâts
périodiques des DoT viennent de l'identifiant du sort (données du client 1.60.1 et même
calcul que le grimoire : puissance des sorts, niveau, talents), plus du texte anglais ou
français de la description. Mode automatique désactivé, Malédiction funeste et bouton
« Lire cette estimation » fonctionnent donc aussi en allemand, espagnol, italien,
portugais, russe, chinois ou coréen. Le bouton du formulaire manuel devient « Revenir aux
données du sort ». Le grimoire et les infobulles étaient déjà calculés par identifiant.

## Nouveautés 0.5.11

Icônes réparties : l'**icône de classe démoniste** du jeu sur le bouton de minicarte et
dans la barre de titre des fenêtres ; le **sceau** sur le menu Accueil, l'en-tête de la
page d'accueil et sa carte de présentation (affiché entier, sans recadrage).

## Nouveautés 0.5.10

**Nouvelle icône** : un sceau doré autour de l'icône de classe démoniste du jeu, avec
quatre icônes d'outils (fragment d'âme, DoT, Crépuscule, pierre de soins). Elle
apparaît dans la liste des addons, sur le bouton de minicarte, dans la barre de titre
des fenêtres et à l'accueil de l'assistant. Art Blizzard : voir `Media/logo-NOTICE.txt`.

## Nouveautés 0.5.9

**Cliquer une carte d'ennemi la cible**, n'importe où sur la carte, barres de DoT
comprises (les infobulles des barres restent). **Hors combat seulement** : le jeu
interdit aux addons de déplacer un bouton de ciblage ou d'en changer l'unité en
combat, et la position des cartes y devient secrète. Les boutons disparaissent donc
au début du combat (jamais de mauvaise cible) et reviennent après.

## Nouveautés 0.5.8

**Huit langues** : français, anglais, espagnol, portugais (Brésil), allemand,
italien, chinois simplifié et russe. Choix dans une nouvelle première étape de
l'assistant (l'assistant change de langue immédiatement) et dans Général › Langue ;
« Langue du jeu » suit le client. Les textes déjà construits suivent après un
rechargement, proposé par un bouton. Le chinois et le russe utilisent la police de
leur alphabet. Les noms de sorts et d'ennemis restent ceux du client.
**Malédictions du kit** : le temps restant de ta malédiction sur la cible actuelle
s'affiche sur les deux boutons de malédiction, en combat compris (texte dessiné par
le moteur natif, les effets de la cible étant masqués en combat).

## Nouveautés 0.5.7

Nouveau nom affiché : **Warlock All-in-One**. Menus refondus : barre latérale
groupée (Combat, Utilitaires, Système), icône sur chaque page, onglet, carte et
bouton, options illustrées (pictogrammes de disposition et de style, pastilles de
couleur des ticks, icônes réelles des sorts du kit et des canalisations), lignes
surlignées au survol, bouton « Barres de test » sur tous les onglets des ennemis.
Option « Conserver les ennemis hors vue » et message « Aucun ennemi observable
admissible » retirés. Performances : événements du groupe ignorés par l'analyse des
ennemis, vie mise à jour sur place, mise en page des cartes en cache.
**Quitter et relancer WoW** pour voir le nouveau nom dans la liste des addons.

## Nouveautés 0.5.6

Noms des ennemis affichés en combat : le jeu les transmet masqués, ils sont
désormais confiés tels quels au texte (plus de « ? »). Diagnostic : compteurs de
noms/GUID masqués.

## Nouveautés 0.5.5

Ennemis en combat corrigés (barres de nom interdites aux addons en instance) ;
diagnostic des rejets ; zone rouge visible seulement dans les dernières secondes
(3 s par défaut, réglable) avec passage progressif du violet au rouge ; curseurs
des réglages sans molette.

## Nouveautés 0.5.4

Affichage en combat rétabli (courbe de couleur du décompte retirée). Barre rouge
pendant les 6 dernières secondes, largeur identique ou proportionnelle à la durée,
éclair au passage de chaque tick ; option des ennemis renommée et bouton pour
toujours afficher les barres de nom ennemies. [Contrat](docs/DOT-NATIVE-CONTAINER.md).

## Nouveautés 0.5.3

Crépuscule : les deux lames se vident avec le **temps restant du proc** (barre
pilotée par le moteur natif), visuel épuré — dégradé, cœur lumineux, halo et
étincelle en tête. [Contrat](docs/NIGHTFALL.md).

## Nouveautés 0.5.2

Avertissement d'expiration actif sur les DoT natifs (décompte orange sous le seuil,
clignotant avec la pulsation) ; ticks personnalisables (couleur, opacité, épaisseur)
ou masqués ; lignes jusqu'à 10 px et texte jusqu'à 8 px.

## Nouveautés 0.5.1

Affichage natif des DoT **confirmé en jeu** sur la 0.5.0. Cartes d'ennemis dont la
hauteur suit le nombre réel de DoT ; **ticks** sur les barres natives (regroupement
par cadence) ; **barres de test** pour régler l'affichage en direct ; en-tête du
cadre masquable ; « Uniquement les ennemis engagés » décoché affiche désormais tous
les ennemis attaquables visibles. [Contrat](docs/DOT-NATIVE-CONTAINER.md).

## Nouveautés 0.5.0

**DoT : cause de l'échec 0.4.38 corrigée.** Chaque ligne ancrait son conteneur
Blizzard sur elle-même puis s'ancrait sur ce conteneur ; WoW refuse ce cycle dès le
premier ennemi engagé, l'erreur était avalée et le moteur restait en échec jusqu'au
reload. Les cartes ont désormais une géométrie publique fixe et rien n'est ancré au
conteneur. Par défaut, **tous vos effets nuisibles** sont affichés (sélection faite
par le client, sans dépendre des IDs du catalogue) ; option « DoT uniquement ».
Disposition **Barres** ou **Icônes**, 1 à 10 effets par ennemi, reprise automatique
après erreur, message clair si l'affichage natif manque, sonde `/waio dots test`.
[Contrat](docs/DOT-NATIVE-CONTAINER.md).

**Interface entièrement refaite** : fenêtre de réglages avec barre latérale et
état de chaque module, page d'accueil avec tuiles, onglets, cartes, interrupteurs,
curseurs à saisie exacte ; cadre des ennemis, bouton de minicarte et fiche de sort
restylés. **Assistant de premier lancement** pour choisir les modules et l'essentiel
des réglages, affiché une seule fois (relance : `/waio setup`).
[Interface et assistant](docs/INTERFACE.md).

| Commande | Effet |
| --- | --- |
| `/waio` | Réglages (accueil). |
| `/waio dots` · `kit` · `shards` · `nightfall` · `spells` | Page correspondante. |
| `/waio setup` | Relancer l'assistant de démarrage. |
| `/waio demo` | Démonstration de 10 secondes. |
| `/waio dots debug` · `dots test` · `dots retry` | Diagnostic, sonde native sur la cible, relance du moteur natif. |
| `/waio nightfall debug` · `diagnostics` | Diagnostics Crépuscule et général. |

État : tests synthétiques PASS (Lua 5.1, EN/FR/DE) ; **rendu en jeu à confirmer**.

## Historique

### 0.4.38 — candidat de recette

**DoT 0.4.38 — affichage délégué à Blizzard** : la capture `Warlock All-in-One natif:
function function` confirme que le client possède le composant nécessaire.
Chaque ennemi admis par le filtre groupe/raid dispose maintenant d'un AuraContainer
natif : auras personnelles réellement présentes, icône, nom, durée, remplissage
fluide et tri par expiration. Corruption, Immolation, Agonie, Calvaire/Wrack et
les drains connus sont inclus. Un lancement raté/résisté ne crée aucune nouvelle
barre ; l'addon ne lit pas les auras protégées ni la visibilité des widgets.

**À tester après `/reload` hors combat**, puis plusieurs DoT sur deux ennemis.
`/waio dots debug` affiche `DoT natif 0.4.38`, `affichage=ready`, le nombre
d'unités liées et une éventuelle erreur d'initialisation. Ce nombre ne compte pas
les auras et `ready` ne constitue pas une validation du rendu réel.

Le mode natif conserve la vie, la sélection, le déplacement, le verrouillage et
les styles. Ses pistes ont une largeur uniforme et ne portent pas de ticks calculés.
Les options de proportions/ticks/hauteur automatique concernent le repli public et
l'aperçu ; les durées publiques déjà confirmées peuvent encore rester hors portée.
La hauteur du cadre est réglable ; les changements de style attendent la fin des
restrictions. [Contrat, sources et recette](docs/DOT-NATIVE-CONTAINER.md).

**Nightfall 0.4.37 — affichage natif Blizzard** : le client du joueur refuse
explicitement la lecture des auras secrètes en combat. Les deux lames violettes
sont désormais dessinées dans un slot natif filtré sur Transe de l'ombre 17941 :
Blizzard gère leur apparition et retrait, sans exposer la présence du buff à Lua.
Géométrie, opacité et pulsation conservées ; apparition et éclat animés par le moteur.
L'aperçu reste indépendant. Les changements de géométrie attendent la fin des
restrictions ; activation/désactivation visuelle conserve son effet immédiat.

La création du composant natif est confirmée par le joueur ; l'intégration complète
reste à qualifier après **`/reload` hors combat** puis un vrai proc. Diagnostic :
`/waio nightfall debug` → `nativeDisplay=ready` indique la configuration réussie,
pas une lecture de visibilité réelle. Son/volume et toute la 0.4.36 conservés ;
l'affichage natif ne permet pas de déclencher un son Lua depuis un buff secret.
[Contrat et limites](docs/NIGHTFALL.md).

**DoT 0.4.36 — diagnostic après capture réelle** : les ennemis passent le filtre,
mais aucune aura personnelle n'est récupérée. Le lecteur PLAYER poursuit maintenant
après une entrée entièrement masquée. Sans effet personnel trouvé par index, une
recherche par nom exact localisé et filtre PLAYER complète la lecture. Aucune durée
n'est déduite d'un lancement. Les refus/valeurs secrètes restent inconnus.

`/waio dots debug` ajoute les lignes **Lecture v2** et **Horloge**, avec les
compteurs d'entrées, masquages, erreurs, identifiants/instances/durées illisibles,
effets retenus et premiers messages d'erreur publics (bornés). À exécuter pendant
que les DoT sont actifs sur la cible, après `/reload` hors combat. Cette étape
historique a permis de confirmer le refus de lecture, traité par le mode natif 0.4.38.
Le correctif Nightfall 0.4.35 et les options/filtre du groupe restent inclus.

**Ennemis et DoT 0.4.34** : uniquement les ennemis engagés avec vous, votre groupe,
votre raid ou leurs familiers (menace, cible attaquée ou aura hostile de votre groupe).
Le simple état en combat ne suffit plus. **Verrouiller** masque tous les boutons ;
rouvrir `/waio dots` → Style pour déverrouiller et retrouver les poignées.

Les auras personnelles sont aussi lues avec le filtre natif PLAYER. Une propriété
masquée ne les élimine plus. Lorsque les horloges sont masquées mais affichables,
la durée et le remplissage sont confiés aux widgets natifs : aucune expiration
inventée depuis le lancement. Les horloges opaques restent en largeur uniforme,
sans ticks calculés ni classement par durée secrète. Si l'accès natif lui-même est
refusé, ce correctif ne peut pas rendre une information indisponible. Diagnostic
`/waio dots debug`. Tests synthétiques ; rendu/combat réel à qualifier.

**Nightfall en combat** : après un faux négatif observé avec le buff actif, une
recherche par ID vide laisse maintenant passer la recherche par nom localisé exact,
les auras publiques et les ajouts/retraits d'instances. Les masquages globaux de
l'interface native ne prouvent plus la disparition du buff. Détection indépendante,
son/volume et deux barres violettes conservés, ainsi que toute la 0.4.34.
**`/reload` hors combat.** Vérification du correctif sur un proc réel encore nécessaire.
`/waio nightfall debug` distingue les sources et les lectures indisponibles.

**Ennemis et DoT → Style** : Cartes, Compact ou Lignes épurées ; bordures et fonds
indépendants. **Modifier**, dans le cadre, révèle la poignée **+** pour déplacer
et **//** en bas à droite pour redimensionner ; **Verrouiller** termine.
Le coin supérieur gauche reste fixe pendant le redimensionnement. Contour violet et
flèches de défilement retirés ; la molette conserve le défilement. Dimensions et position sauvegardées. Ticks pleine hauteur, prochain doré,
message « Aucun effet périodique personnel pris en charge » retiré.

**Effets confirmés uniquement**, activé par défaut dans Avancé : une fin de lancement
ne prouve pas l'impact. Nouveau timer après aura personnelle lisible, sans faux
rafraîchissement d'une aura déjà active. Les auras publiques restent utilisables
même si une autre aura est masquée ; les vues cible/focus/survol de même GUID
complètent la nameplate. Une expiration déjà confirmée est conservée si masquée,
même sans estimations de lancement. Si la confirmation est masquée par Forever,
le timer reste absent. Désactiver rétablit les estimations et leurs faux positifs
possibles. Aucun contournement du journal de combat restreint. `/reload` suffit.
[Contrat et recette](docs/DOT-DISPLAY.md).

**Calculs en combat** : si le client masque les données, les fiches et infobulles
utilisent une référence complète capturée hors combat, avec la mention discrète
« Estimation · valeurs avant combat ». Talents, SP, Esprit et auras restent cohérents.
Les valeurs actuelles lisibles sont prioritaires ; actualisation automatique à la
sortie du combat. `/reload` hors combat pour appliquer.

Nightfall : détection et animation indépendantes, recherche ciblée de l’aura 17941
et événements natifs facultatifs. Son et volume conservés. [Recette](docs/NIGHTFALL.md).



**Fiches de sorts** : résumé en cartes, total doré et bonus nominal des talents
violet ; onglet Calcul détaillé et description à la demande. Plaie d’agonie affiche
son total sur 24 s et sa moyenne par tick. Connexion détaille Vie → Mana à partir
de l’Esprit et de Connexion améliorée. Les mentions générales et le rappel « sort
absent des barres » sont retirés des affichages concernés. `/reload` pour appliquer.

**Ennemis et DoT** : blocs distincts par ennemi, icônes recadrées, noms et durées
en colonnes, ticks clairs et prochain tick doré. Remplissage fluide à chaque image,
scans d'auras inchangés. Mode proportionnel : largeur de fond basée sur la durée
totale, seul le remplissage diminue pendant le décompte ; fin d'un effet sans étirer
les autres barres. Dans `/waio dots` → Affichage, option **Conserver les ennemis
avec timers hors vue**, désactivée par défaut. Timers connus conservés jusqu'à leur
expiration, mention Hors vue et vie indisponible. `/reload` suffit.
[Contrat et limites](docs/DOT-DISPLAY.md).

Nightfall : vrai son du proc davantage renforcé (niveau moyen +64 %), volume sauvegardé
0–100 %, deux lames violettes effilées avec cœur lumineux et apparition progressive.
[Réglages et recette](docs/NIGHTFALL.md). Les préférences existantes sont conservées.


**Ennemis et DoT** : `/waio dots` propose quatre onglets Affichage, Vie, DoT et
Avancé, avec exemples de vie, aperçu des modes, curseurs et saisie précise. Le mode
proportionnel utilise les durées totales, avec des pistes stables pendant le décompte.
Le mode Largeur identique reste inchangé. `/reload` suffit.
[Contrat et recette](docs/DOT-DISPLAY.md).

**Grimoire et infobulles** : `/waio spells` → **Sorts** pour rechercher et
consulter ; **Affichage** pour les trois réglages indépendants, avec explications,
états Activé/Désactivé et aperçu illustratif. Icônes, rangs/ID, bouton Effacer et
pagination explicite. Choix existants conservés. `/reload` pour appliquer.

**Menus du kit** : choisir un sort change seulement la sélection, sans lancer ni utiliser.
Cliquer ensuite sur le bouton principal pour agir. Les pierres gardent le meilleur rang
automatique. [Contrat](docs/ACTION-KIT.md). `/reload` pour appliquer.

Nightfall : son du proc Transe de l’ombre corrigé (SoundKit 3219 / fichier 569668), volume réglable de **0 à 100 % par pas de 10 %** dans
`/waio nightfall`, avec bouton Écouter et choix sauvegardé. 100 % garde le niveau
renforcé existant ; 0 % coupe uniquement cette alerte. [Réglages](docs/NIGHTFALL.md).


**Infobulles compactes** : total doré en tête, valeurs alignées, SP bleu et talents
violets. Maintenir **Maj avant le survol** affiche les formules et les talents
détaillés. Calculs conservés, fiche du grimoire complète. `/reload` pour appliquer.

`/waio dots` : contour de sélection désactivable, drains (vie/âme/mana) et Calvaire
avec option dédiée, choix **Largeur identique** ou **Proportionnelle à la durée**.
Le mode proportionnel partage une échelle en secondes entre les timers visibles.
[Contrat et recette](docs/DOT-DISPLAY.md).

**Talents dans les infobulles et le grimoire** : rangs appris, bonus appliqués,
contribution SP effective, dégâts directs/par tick et total. Auras personnelles
lisibles incluses ; conditions de cible et critiques signalés séparément. États
illisibles : résultat inconnu. [Calculs et limites](docs/SPELL-TALENTS.md).
Quitter complètement WoW puis le relancer pour charger les deux nouveaux modules.

La cible sélectionnée est encadrée en doré dans Ennemis et DoT, autour de sa vie et
de ses effets. Le contour suit le changement de cible et respecte les nameplates.



**Bouton Invocation 123** : position indépendante, taille 60–180 %, designs Complet /
Compact / Icône. Clic droit → Déplacer le bouton 123, puis glisser la poignée dorée.
Clic droit sur la poignée pour terminer ; position, taille et design sauvegardés.

Vie compacte : le nom réduit est intégré à gauche dans la barre, sans bandeau supérieur par
défaut. `/waio dots` → **Bandeau de nom séparé** pour retrouver le titre au-dessus.
Nouveau format **Valeur + % + maximum**, par exemple `416 (34%) / 1223` ; choix existant conservé.
[Contrat et recette](docs/NAMEPLATE-HEALTH.md).


**Fenêtre 123** : clic droit sur **Invocation 123** ou `/waio kit` pour régler
largeur, hauteur et échelle. Bouton **Fermer ×** en haut à droite, utilisable en combat.
[Réglages et recette](docs/ACTION-KIT.md).

Suivi multicible corrigé : homonymes suivis par GUID, minuteurs conservés quand les auras
hors cible deviennent illisibles/vides. DoT triés par échéance croissante, légende inférieure
retirée. [Comportement et recette 0.4.4](docs/MULTITARGET.md).

Détail SP et ticks dans les infobulles des sorts, activé par défaut. Option indépendante
dans `/waio spells`. [Contrat et recette](docs/SPELL-TOOLTIPS.md).

`/waio spells` → Grimoire → **Afficher base, puissance des sorts et ticks**.
Base + bonus nominal de SP (coefficient en %) = dégâts nominaux, avec détail par tick
et total des effets uniformes ; initial/périodique séparés pour Immolation.
81 rangs / 89 composantes, données client 1.60.1.70425. Puissance actualisée dans la fiche.
[Sources, limites et validation](docs/SPELL-DETAILS.md). Tests locaux simulés PASS ;
version réunissant les réglages du kit et demandes 123 de la 0.3.6, rendu en jeu non validé.

Addon autonome pour démoniste, ciblant **Forever 1.60.1 / Interface 16001**.
Dernier client contrôlé sur disque : **1.60.1.70425**, le 16 octobre 2026.
Développement isolé, aucune dépendance au site ou au compagnon Forever Pulse.
**Le critère « utilisable et vérifié en jeu » n'est pas atteint : aucun essai en jeu n'a été effectué.**
Les tests Lua utilisent des API simulées. Les coefficients du grimoire ont une provenance client ;
les canalisations du cadre ennemis sont associées au lancement, avec repli estimé si nécessaire. Les repères de ticks 0.1.3 sont basés sur WarlockTicks,
pas des impacts observés ni une mesure validée en jeu.

## Nightfall : son Blizzard et deux barres latérales — 0.4.13

`/waio nightfall` : deux barres verticales violettes à gauche/droite du centre,
avec hauteur, largeur, écart et opacité réglables. Ancienne carte et halo périphérique retirés.
Son d’alerte Blizzard repris depuis le même enregistrement, amplifié avec limitation des pics,
une lecture par proc sur Principal, sans changer les volumes du jeu. Les anciens sons
personnalisés ne sont plus proposés ni lus. [Provenance et recette](docs/NIGHTFALL.md).
Toute la 0.4.10 est conservée, bouton 123 indépendant et nouveaux réglages Kit compris.

## Affichage simplifié et canalisations dans les DoT — 0.4.1

Dégâts restants estimés retirés du cadre et des options. Nouveau format de vie
**Valeur + pourcentage**, par exemple `750 (75%)`, dans `/waio dots`.
Drain de vie, Drain d'âme et Wrack apparaissent aussi sous l'ennemi pendant leur
canalisation, avec durée du client et ticks prévisionnels. Arrêt/interruption/expiration
retirent la ligne ; cible conservée au lancement, nameplate et filtre combat respectés.
[Contrat et recette](docs/DOT-DISPLAY.md). `/reload` après installation.

## Correction affichage et lancements 0.3.1

`/waio dots` : ennemis limités aux nameplates disponibles, filtre combat facultatif,
largeur de vie 100–600, hauteur 12–48, valeur nominale / pourcentage / actuels-maximum.
Le texte est formaté nativement par le client, y compris les nombres protégés acceptés.
Les minuteurs démarrent aussi via START/SUCCEEDED lorsque SENT ne fournit pas de nom,
sans dépendre de la lecture des auras. L'association de repli à la cible reste estimée (~).
Durées/ticks automatiques sur les 33 ID existants, sans profils manuels.
[Contrat, diagnostic de la capture et recette](docs/NAMEPLATE-HEALTH.md).

## Nouveau : boutons de sorts 0.3.0

Tous les groupes demandés : pierres, démons/talents, deux malédictions, protection,
armure, pierres d'arme, invocation et utilitaires. Quatre présentations, taille et visibilité
par groupe dans `/waio kit`. Icône de fragment seule avec compte superposé : clic
pour replier/déplier, clic droit pour les réglages, Maj-clic pour le nettoyage existant.
`/waio summons` ou bouton **123** : demandes du groupe/raid/instance et chuchotements,
dédoublonnées, expiration après dix minutes. Clic gauche pour cibler exactement/invoquer
un membre du groupe hors combat ; clic droit pour retirer. Aucun message automatique.
Choix/raccourcis sécurisés, préférences conservées ; [contrat et recette](docs/ACTION-KIT.md).
Le suivi DoT et son timing automatique 0.2.1 sont inclus dans cette version.

## Suivi DoT natif 0.2.0

`/waio dots` : minuteurs multi-cibles estimés, auras lisibles, malédictions/fléaux,
vie graphique native, prévision linéaire des dégâts restants, avertissements et ticks,
repères focus/familier. Implémentation originale inspirée des fonctions de DoTimer,
sans dépendance. Canalisations sur la barre WoW originale uniquement.
Depuis 0.2.1, durées/ticks automatiques sur 33 ID/rangs, sans réglage manuel.
[Couverture et limites](docs/AUTOMATIC-TIMING.md) ; hors catalogue,
aucune valeur inconnue n'est présentée comme zéro. [Fonctions, limites et recette](docs/DOT-TRACKER.md).
**Quitter entièrement le jeu puis relancer** après installation : nouveau fichier dans le TOC.

## Installation manuelle

1. Quitter le jeu. Conserver les autres addons et leurs réglages.
2. Extraire `dist/Warlock-All-in-One-0.6.11.zip` dans
   `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`.
3. Vérifier le chemin final `AddOns\Warlock All-in-One\Warlock All-in-One.toc`, sans dossier intermédiaire.
4. Relancer le client, activer Warlock All-in-One pour un démoniste. Une autre classe reste inactive.
5. Ouvrir `/waio`, puis suivre [la recette](docs/RECETTE.md). Aucune installation n'est effectuée par les outils de ce dépôt.

Pour retirer l'addon, quitter le jeu puis retirer uniquement son dossier. Ses réglages utilisent
`WarlockAllInOneDB`, sans partage avec ShardManager ou ForeverPulse. La suppression des réglages
est facultative ; ne pas toucher aux SavedVariables d'autres addons.

## Utilisation

- Bouton violet sur la minimap : clic pour ouvrir/fermer, glisser pour déplacer. Position/visibilité sauvegardées.
- Général : activation, verrouillage, échelle/opacité des cadres de combat, remise à zéro des positions et démo de 10 s.
- Fragments : maximum 0–200 (**0 conserve zéro**), curseur, saisie directe, boutons −/+ et
  valeurs rapides 10/20/30/40. Accès par `/waio shards` ou la rubrique Fragments. Chaque changement
  est enregistré immédiatement, sans suppression ; l'excédent est actualisé.
- Nettoyage auto activé par défaut en 0.1.2 à la demande du propriétaire : hors combat, les
  touches de jeu et clics gauches dans le monde retirent le surplus. Interrupteur dans Fragments ;
  `/waio auto off` pour arrêter, `auto on` pour reprendre. Le choix OFF reste sauvegardé.
- Grimoire : 119 identifiants historiques vérifiés dans la table de noms 1.60.1.70245,
  complétés par les lignes de classe du grimoire actuel ; recherche nom localisé/ID, détails et infobulle du client.
  La présence dans l'ancien fichier n'atteste pas un sort actuellement apprenable. Familiers exclus.
- Canalisations : barre originale de WoW conservée, interrupteurs par ID/rang candidat, dont Drain Soul, Drain Life, Wrack,
  Drain Mana, Health Funnel, Rain of Fire et Hellfire. Temps fourni par le client, aucun rythme inventé.
- Repères de ticks activés par défaut dans Canalisations, désactivables et sauvegardés : uniquement sur les
  barres WoW horizontales standard `PlayerCastingBarFrame` / `CastingBarFrame`, sans
  déplacer ni redimensionner celles-ci. Drain Life/Soul/Mana : 5 ticks ; Wrack : 6 ; Rain of Fire : 4 ;
  Hellfire : 15, selon [WarlockTicks](https://www.curseforge.com/wow/addons/warlockticks).
  La fin du sort constitue le dernier tick, sans trait supplémentaire. Hâte : durée initiale / nombre
  fixe ; recul : calendrier initial conservé et ticks perdus retirés. Health Funnel et ID inconnus :
  aucun repère. Chargement en cours de canalisation : attendre le prochain lancement.
  WarlockTicks déjà chargé : pas de second overlay sur la barre Blizzard. Aucune dépendance requise.
- Ennemis : nameplates disponibles uniquement, combat seul activé par défaut et désactivable. GUID publics, refus des noms ambigus, 1–12 ennemis visibles,
  16 effets par ligne et compte des surplus. Réglages et limites dans DOT-TRACKER.md.
- Nightfall : aura 17941, deux barres violettes centrées latéralement ; son d’alerte Blizzard
  renforcé sur la transition absent → présent. Essais séparés dans `/waio nightfall`.
- Interface FR complète pour `frFR`, EN complète et repli EN pour les autres locales.
  Les noms de sorts viennent du client ; les identités utilisent ID/GUID, jamais les noms.

Commandes identiques dans toutes les langues :

```text
/waio
/waio shards
/waio max 20
/waio auto on
/waio auto off
/waio prune
/waio demo
/waio reset
/waio diagnostics
```

Macro utilisant exactement le même chemin que le bouton :

```text
/waio prune
```

Alternative matérielle si le client accepte `/click` :

```text
/click WarlockAllInOnePruneButton
```

`/warlockallinone` est toujours enregistré ; il sert de repli si `/waio` appartient déjà à un addon
chargé auparavant. Aucun conflit trouvé dans les addons locaux ni par recherche web le 15 octobre 2026.
Cela ne garantit pas l'unicité mondiale, ni l'absence d'un addon chargé ultérieurement avec la même commande.

## Suppression : limites explicites

Chaque entrée matérielle autorise au plus **une suppression**, bornée par l'excédent recalculé.
**23/20 avec trois fragments individuels : 23 → 22 → 21 → 20 au fil de trois entrées éligibles**,
puis arrêt. Avec une pile unique de 23, seuls 3 sont séparés ; le total et la pile de 20 restants sont
vérifiés avant destruction. Fractionnement non observable immédiatement = remise en place et arrêt.
Le client exige une entrée réelle : aucun nettoyage au repos. Touches transmises au jeu, aucun
raccourci remplacé, répétition d'une touche maintenue ignorée. Saisie, réglages Warlock All-in-One, menu du jeu,
caméra, combat et curseur occupé suspendent les tentatives auto. Un refus ou changement d'inventaire
durant la transaction suspend le mode auto pour la session : désactiver/réactiver pour réessayer.
Chaque action relit l'inventaire, l'emplacement, le verrou, le curseur et la quantité. Aucun appel depuis
un événement de sac, une minuterie, une connexion ou une entrée en combat. Banque exclue ; sacs portés
0 à `NUM_TOTAL_EQUIPPED_BAG_SLOTS`, emplacement supplémentaire et boîte d'âme compris.
La suppression privilégie les sacs ordinaires avant les sacs d'âmes (famille 4), pour libérer
les emplacements généraux. Aucune prévention de la création de nouveaux fragments.

Le client peut refuser ou demander une confirmation native ; aucune protection contournée, aucun « un clic
suffit » promis. Sur refus après ramassage, `ClearCursor` demande la remise en place de l'objet pris ; si
le contenu du curseur est inattendu, il est laissé intact et l'utilisateur est averti. Vérifier le curseur.
Ne pas tester une destruction réelle sans décision explicite du joueur. Pour isoler ce test, désactiver
manuellement les nettoyages d'autres addons, notamment ShardManager, pour tester un seul gestionnaire.

## Sources, tests et limites

- [Compatibilité et audit](docs/COMPATIBILITE.md)
- [Coefficients, calculs et données](docs/FORMULES.md)
- [Recette en jeu](docs/RECETTE.md)
- [Validation locale et limitations](docs/VALIDATION.md)
- [Réutilisations et licences](docs/DEPENDANCES.md)
- [Architecture](docs/ARCHITECTURE.md)

Tests reproductibles, avec Lua 5.1 et `luac` présents localement :

```powershell
./tools/test.ps1 -Lua 'chemin\lua5.1.exe' -Luac 'chemin\luac5.1.exe'
python tools/package.py
```

Aucun téléchargement, réseau ou télémétrie depuis l'addon. Les outils Python de recherche/build sont
hors du TOC et ne s'exécutent jamais dans le jeu. L'archive n'inclut aucune bibliothèque tierce.

## English quick start

This is an **untested-in-game candidate**, not a verified Forever release. Extract the ZIP so that
`Interface/AddOns/Warlock All-in-One/Warlock All-in-One.toc` exists, restart the game and log in on a warlock.
Open `/waio`. The whole in-game interface is available in English and French. Other locales use
English UI with client-localized spell names. Drag title strips to move frames; use General to lock them.

`/waio prune` requests deletion of one unlocked whole shard stack that fits the excess above the
configured target. Larger stacks must be split manually. Zero keeps no shards. No automatic deletion,
no deferred work, no bank scan, no combat deletion. Respect any client confirmation. `/waio diagnostics`
reports API availability without exporting player data. `/waio demo` is explicitly synthetic.

Channel tick markers are predictions based on WarlockTicks for Forever 1.60.1. Toggle them in Channels.
Only six supported spell families are covered; unknown spells have no markers. Haste uses the initial
channel duration; pushback preserves the original tick times. No observed-hit claim or channel target
is inferred. Coefficients remain unknown. Detailed combat log access is restricted. Nameplate data may also
be restricted; unavailable state is withdrawn. Runtime behavior, persistence across reload/relogin,
layout, proc detection and coexistence with installed addons still require the manual in-game recipe.
