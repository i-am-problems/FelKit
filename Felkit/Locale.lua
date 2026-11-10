local _,S=...
local en={
 shardClickHelp='Left click: delete excess, even with auto off (one stack per click).\nRight click: settings.\nDrag the number to move.',
 waitingBag='Waiting for the last deletion to show in your bags.',
 title='Felkit',general='General',shards='Soul Shards',grimoire='Grimoire',channels='Channels',enemies='Enemies & DoTs',nightfall='Nightfall',
 enabled='Enable addon',minimap='Minimap button',compact='Compact shard counter',locked='Lock frames',reset='Reset positions',demo='Demo (10 seconds)',
 scale='Frame scale',opacity='Frame opacity',width='Enemy frame width',rowHeight='Row height',spacing='Enemy spacing',fontSize='Text size',maxEnemies='Visible enemies (maximum)',healthMode='Health: 1 current / max, 2 current, 3 percent',
 keep='Maximum Soul Shards',prune='Delete excess',count='Shards: %s / %d | excess: %s',
 shardSettings='Set shard maximum',keepHelp='0 to 80, counting all equipped bags (not the bank). Shards in a soul bag are kept.',
 manual='Manual button: each press deletes one extra shard slot, in combat too.',
 autoShards='Auto-clean on gameplay inputs',autoHelp='Each key press, cast or world click removes one extra shard, even in combat (23 / 20 becomes 20).',
 autoDeleted='Auto-clean: deleting %d shard(s).',autoStopped='Auto-clean: the game refused deletion on this input (%s); it is now skipped. Turn auto off and on to retry.',autoOn='Auto-clean enabled on gameplay inputs.',autoOff='Auto-clean disabled.',
 unknown='Unknown / unavailable',restricted='Data unavailable or restricted',cadence='Tick cadence unknown',observed='Observed',predicted='Predicted',
 visual='Visual alert',sound='Sound alert',pulse='Pulse (off = steady)',intensity='Edge intensity',soundChoice='Sound: 1 chime, 2 low bell',test='Test alert (demo)',
 intro='Candidate 0.4.35 • Forever 1.60.1.70425 / 16001\nNot yet validated in game. Drag the title strips to move frames. Settings are saved by the client.',
 enemyHelp='Only observable, attackable nameplates whose own unit is in combat. Enable enemy nameplates in game yourself. Restricted data is withdrawn. No range estimate.',
 channelHelp='Shows upcoming ticks on the WoW channel bar for Drain Life, Drain Soul, Drain Mana, Wrack, Rain of Fire and Hellfire.',
 tickMarks='Show predicted channel ticks',tickPrediction='Predicted ticks • WarlockTicks',
 procHelp='Alert on the Shadow Trance proc (aura 17941), not on the talent alone.',
 catalogueHelp='Historical ID seed + your current spellbook. Not an exhaustive current-build catalogue. Search localized name or spell ID. Pet abilities excluded.',
 search='Search',previous='Previous',next='Next',details='Details',close='Close',school='School',kind='Type',rank='Rank',source='Source / evidence',
 direct='Direct',periodic='Periodic',mixed='Direct + periodic',drain='Damage / healing',channel='Channel',area='Area channel',resource='Resource transfer',utility='Utility',triggered='Triggered effect',proc='Proc',unclassified='Unclassified',
 shadow='Shadow',fire='Fire',seed='Historical client 1.60.1.70245; current values unverified',spellbook='Current client spellbook; mechanics unverified',
 coefficient='SP coefficient (direct / per tick / total)',base='Base damage / healing',timing='Duration / tick count / interval',na='Not applicable',
 formula='Example ONLY, not a game prediction: base 100 + SP 200 × coefficient 0.5 = 200 before mitigation. No coefficient is inferred from a tooltip or a few hits.',
 modifiers='Ranks, penalties, talents, Shadow/Fire power, critical hits, haste, snapshot/dynamic updates and unequal ticks are unverified. Tooltip text may already include bonuses; it is not added to SP again.',
 description='Live client description (may include bonuses)',demoLabel='DEMO — fabricated data',more='+ %d more enemies',effectsUnknown='Effects unavailable',noEffects='No supported own periodic effect',
 diagnostics='Diagnostics',diagnosticHelp='Read-only capability report; no player names, GUIDs or inventory exported.',
 invalid='Invalid number.',combat='Unavailable in combat.',cursor='Cursor occupied: nothing changed.',unavailable='Inventory unavailable: nothing changed.',
 nothing='No excess.',stack='The excess needs a split and the client offers none here. Split a stack manually.',changed='Unexpected cursor content: nothing deleted. Check the cursor.',blocked='Client blocked the action. Check cursor and any native confirmation.',requested='Deletion requested; verify the refreshed inventory count.',
 disabled='Module disabled.',collision='/fk is already taken; use /felkit.',unsupported='This game version is not supported. Tools disabled.',
 loading='Loading…',previewOnly='Preview unavailable in combat.',tickLegend='No marks: tick timing unknown.',
}
local fr={
 shardClickHelp='Clic gauche : supprimer le surplus, même sans auto (une pile par clic).\nClic droit : réglages.\nGlisser le nombre pour déplacer.',
 waitingBag='En attente de la suppression précédente dans vos sacs.',
 title='Felkit',general='Général',shards="Fragments d’âme",grimoire='Grimoire',channels='Canalisations',enemies='Ennemis et DoT',nightfall='Crépuscule',
 enabled="Activer l’addon",minimap='Bouton minimap',compact='Compteur compact',locked='Verrouiller les cadres',reset='Réinitialiser les positions',demo='Démonstration (10 secondes)',
 scale='Échelle des cadres',opacity='Opacité des cadres',width='Largeur du cadre ennemis',rowHeight='Hauteur des lignes',spacing='Espacement des ennemis',fontSize='Taille du texte',maxEnemies='Ennemis visibles (maximum)',healthMode='Vie : 1 actuels / max, 2 actuels, 3 pourcentage',
 keep='Nombre maximum de fragments',prune="Supprimer l’excédent",count='Fragments : %s / %d | excédent : %s',
 shardSettings='Régler le maximum de fragments',keepHelp='De 0 à 80, tous sacs équipés comptés (hors banque). Les fragments d’un sac d’âme sont conservés.',
 manual="Bouton manuel : chaque appui supprime une case de fragment en trop, en combat aussi.",
 autoShards='Nettoyage auto pendant le jeu',autoHelp='Chaque touche, sort ou clic dans le monde retire un fragment en trop, même en combat (23 / 20 devient 20).',
 autoDeleted='Nettoyage auto : suppression de %d fragment(s).',autoStopped='Nettoyage auto : le jeu a refusé la suppression sur cette entrée (%s) ; elle est désormais ignorée. Désactivez puis réactivez le mode auto pour réessayer.',autoOn='Nettoyage auto activé sur les entrées de jeu.',autoOff='Nettoyage auto désactivé.',
 unknown='Inconnu / indisponible',restricted='Données indisponibles ou restreintes',cadence='Cadence des ticks inconnue',observed='Observé',predicted='Prédit',
 visual='Alerte visuelle',sound='Alerte sonore',pulse='Pulsation (sinon effet fixe)',intensity='Intensité des bords',soundChoice='Son : 1 carillon, 2 cloche grave',test="Tester l’alerte (démo)",
 intro='Candidat 0.4.35 • Forever 1.60.1.70425 / 16001\nNon validé en jeu. Déplacer les cadres par leur bandeau. Réglages enregistrés par le client.',
 enemyHelp='Plaques observables et attaquables dont chaque unité est en combat. Activer soi-même les plaques ennemies en jeu. Données restreintes retirées. Aucune distance estimée.',
 channelHelp='Affiche les prochains ticks sur la barre de canalisation de WoW pour Drain de vie, Drain d’âme, Drain de mana, Calvaire, Pluie de feu et Flammes infernales.',
 tickMarks='Afficher les ticks prévisionnels',tickPrediction='Ticks prévisionnels • WarlockTicks',
 procHelp="Alerte sur le proc Transe de l’ombre (aura 17941), pas sur le talent seul.",
 catalogueHelp='Identifiants historiques + grimoire actuel. Catalogue non exhaustif du build actuel. Rechercher un nom localisé ou un ID. Familiers exclus.',
 search='Rechercher',previous='Précédent',next='Suivant',details='Détails',close='Fermer',school='École',kind='Type',rank='Rang',source='Source / preuve',
 direct='Direct',periodic='Périodique',mixed='Direct + périodique',drain='Dégâts / soins',channel='Canalisation',area='Canalisation de zone',resource='Transfert de ressource',utility='Utilitaire',triggered='Effet déclenché',proc='Proc',unclassified='Non classé',
 shadow='Ombre',fire='Feu',seed='Client historique 1.60.1.70245 ; valeurs actuelles non vérifiées',spellbook='Grimoire du client actuel ; mécanique non vérifiée',
 coefficient='Coefficient SP (direct / par tick / total)',base='Dégâts / soins de base',timing='Durée / nombre de ticks / intervalle',na='Sans objet',
 formula='Exemple UNIQUEMENT, pas une prédiction du jeu : base 100 + SP 200 × coefficient 0,5 = 200 avant mitigation. Aucun coefficient déduit d’une infobulle ou de quelques impacts.',
 modifiers='Rangs, pénalités, talents, puissance Ombre/Feu, critiques, hâte, snapshot/mise à jour dynamique et ticks inégaux non vérifiés. L’infobulle peut déjà intégrer des bonus : aucun nouvel ajout de SP.',
 description='Description du client (bonus éventuellement inclus)',demoLabel='DÉMO — données fabriquées',more='+ %d ennemis supplémentaires',effectsUnknown='Effets indisponibles',noEffects='Aucun effet périodique personnel pris en charge',
 diagnostics='Diagnostic',diagnosticHelp='Capacités en lecture seule ; aucun nom de joueur, GUID ou inventaire exporté.',
 invalid='Nombre invalide.',combat='Indisponible en combat.',cursor='Curseur occupé : aucune modification.',unavailable='Inventaire indisponible : aucune modification.',
 nothing='Aucun excédent.',stack='L’excédent demande une division que le client ne permet pas ici. Diviser une pile manuellement.',changed='Contenu inattendu sur le curseur : rien supprimé. Vérifier le curseur.',blocked='Action bloquée par le client. Vérifier le curseur et une éventuelle confirmation native.',requested='Suppression demandée ; vérifier le compteur après actualisation.',
 disabled='Module désactivé.',collision='/fk est déjà pris ; utilisez /felkit.',unsupported='Version du jeu non prise en charge. Outils désactivés.',
 loading='Chargement…',previewOnly='Démonstration indisponible en combat.',tickLegend='Sans repères : rythme des ticks inconnu.',
}
en.dotHelp="Only enemies with an available nameplate are displayed, even if a target/focus or estimated DoT persists out of range. Combat-only filtering is optional. ~ marks predictions. Native health text may be unavailable if the client refuses it."
en.dotPredict="Estimate timers after successful casts"
en.dotHealth="Native graphical health"
en.dotForecast="Estimated remaining damage"
en.dotMarkers="Focus [F] and pet target [P] markers"
en.dotWarnings="Expiry warnings"
en.dotPulse="Pulse expiry warnings"
en.dotTicks="Estimated DoT tick markers"
en.dotTargetFirst="Current target first"
en.dotWarning="Warning threshold (seconds)"
en.dotProfileHelp="Durations and ticks are automatic. The fields below are optional overrides, used only with automatic timing off."
en.dotSaved="Manual profile saved. Turn off automatic timing to use it."
en.dotLegend="~ estimated cast | F focus | P pet | ? unknown"
fr.dotHelp="Seuls les ennemis avec une nameplate disponible sont affichés, même si une cible/focus ou un DoT estimé persiste hors portée. Filtre combat facultatif. ~ indique une prévision. Le texte de vie peut rester inconnu si le client refuse son affichage."
fr.dotPredict="Estimer les durées après lancement"
fr.dotHealth="Vie graphique native"
fr.dotForecast="Dégâts restants estimés"
fr.dotMarkers="Repères focus [F] et cible du familier [P]"
fr.dotWarnings="Avertir à l’expiration"
fr.dotPulse="Faire pulser l’avertissement"
fr.dotTicks="Repères de ticks DoT estimés"
fr.dotTargetFirst="Cible actuelle en premier"
fr.dotWarning="Seuil d’avertissement (secondes)"
fr.dotProfileHelp="Durées et ticks sont automatiques. Les champs ci-dessous sont facultatifs, utilisés seulement si le mode automatique est désactivé."
fr.dotSaved="Profil manuel enregistré. Désactivez le mode automatique pour l’utiliser."
fr.dotLegend="~ lancement estimé | F focus | P familier | ? inconnu"
en.dotID='Spell ID (from Grimoire)'; fr.dotID='ID du sort (dans Grimoire)'
en.dotDuration='Estimated duration (seconds)'; fr.dotDuration='Durée estimée (secondes)'
en.dotInterval='Tick interval (0 = unknown)'; fr.dotInterval='Intervalle ticks (0 = inconnu)'
en.dotDamage='Total periodic damage (0 = unknown)'; fr.dotDamage='Dégâts périodiques totaux (0 = inconnu)'
en.dotSave='Save spell estimate'; fr.dotSave='Enregistrer cette estimation'
en.dotLoad='Load spell estimate'; fr.dotLoad='Lire cette estimation'
en.dotClear='Use spell data again'; fr.dotClear='Revenir aux données du sort'
local kitEN={
 kitStateActive='Effect active',kitStateInactive='Not active · Click to create / activate',kitStateUnknown='State unknown',kitHealthCount='Healthstones in your bags',kitSoulCount='Soulstones in your bags',
 kitQueueIconTitle='Summoning · 123',kitQueueIconHelp='Replaces Ritual of Summoning in the kit. Left-click: requests. Right-click: settings.',
 kitOptionsTitle='Your action buttons',kitOptionsSubtitle='Choose a layout, adjust its size, and keep your spells close.',
 kitTab_layout='Layout',kitTab_buttons='Buttons',kitTab_summons='Summoning',
 kitSummon_button='123 button',kitSummon_window='Request window',
 kitDirection='Direction',kitBaseSize='Base icon size',kitFreeTitle='Place each button',
 kitFreeSteps='1. Enable moving   2. Drag the gold handles\n3. Finish moving to use your spells again.',
 kitVisibleTitle='Visible groups',kitShowAll='Show all',kitHideAll='Hide all',kitOptionsQueueOpen='Open summon requests',kitActive='Enabled',
 kitVisibilityHelp='Show or hide each button group; hidden groups keep their settings.',
 kitStatusLive='Changes apply immediately · Saved automatically',kitStatusCombat='In combat · Changes will apply afterwards',
 kitStatusOff='Action buttons are disabled',kitStatusEdit='Moving buttons · Finish moving when ready',
 kitCircleHelp='Negative distance pulls buttons closer (they may overlap).',
 kitScaleHelp='Size of the buttons and menus; the shard keeps its size.',
 kit='Action kit',kitHelp='Click the shard to fold / unfold actions. Right-click it for settings. Shift-click deletes excess shards. Drag the icon to move. Spell names follow your client language. Bind keys in WoW > Key Bindings > Felkit.',
 kitLayout='Presentation',kit_orb='Orb',kit_drain='Drain Soul',kit_circle='Circle',kit_horizontal='Horizontal',kit_vertical='Vertical',kit_grid='Compact grid',
 kit_free='Free placement',kitEdit='Move buttons',kitEditDone='Finish moving',kitReset='Reset free placement',
 kitDragHelp='Drag to move. No spell is cast from this handle.',
 kitFreeHelp='Choose Free placement, then Move buttons. Drag each gold handle and finish moving to use your spells again. Positions are saved; moving the shard moves the whole set. Editing pauses during combat.',
 kit_left='Left',kit_right='Right',kit_up='Up',kit_down='Down',
 kitCircleDistance='Circle: extra distance',kitHorizontalDirection='Horizontal: direction',
 kitVerticalDirection='Vertical: direction',kitGridDirection='Grid: side of the shard',kitScale='Button scale',
 kitGeometryHelp='Negative distance brings the circle closer than the standard spacing; buttons may overlap. The shard stays clear. Directions apply to their respective layout. Button scale includes menus and leaves the shard unchanged. Changes apply immediately outside combat.',
 kitSize='Button size',kitHideUnknown='Hide spells not learned',kitWeaponChoice='Weapon stone',kitWeaponHelp='Stone type for the weapon button; your best stone or rank is always used.',kitFirestone='Firestone',kitSpellstone='Spellstone',kitDeferred='Kit changes will apply after combat.',
 kit_health='Healthstone',kit_soul='Soulstone',kit_demon='Demon',kit_sacrifice='Demonic Sacrifice',kit_link='Soul Link',kit_domination='Fel Domination',
 kit_curse1='Curse slot 1',kit_curse2='Curse slot 2',kit_ward='Shadow Ward',kit_armor='Demon Armor / Skin',kit_weapon='Firestone / Spellstone',kit_summon='Ritual of Summoning',kit_utility='Buffs',
 kitClick='Left-click: cast / use. Right-click: choose without casting.',kitCreate='Shift-click: create the best learned rank. Right-click: choose the stone type.',
 kitStateObserved='Last known state; may be out of date.',
 kitUtilityInactive='Effect inactive',kitUtilityTarget='Cast on your friendly target, or on you if none.',
 kitSelectHelp='Click to select without casting, then use the main button.',
 kitSoulBest='Uses your best soulstone, creating it first if needed. Shift-click: create.',kitHealthBest='Full health: creates your best missing healthstone. Hurt: uses your best one. Shift-click: create.',
 kitUse='Stone available: click to use / apply.',kitUnknown='Spell not learned',kitDemonShift='Shift-click: Fel Domination then summon (if learned).',
 kitQueue='Summon requests · 123',kitQueueCount='%d request(s) · expires after 10 min',
 kitQueueCombat='List updates after combat. The 123 button opens / closes it.',
 kitQueueHelp='Lists players who type 123 in group chat or whisper. Left-click: summon (outside combat). Right-click: remove.',
 kitNotGrouped='unavailable / outside group',
 kitQueueSubtitle='Felkit · Manual summoning',kitQueueEmpty='No requests yet',
 kitQueueWidth='Summon window: width',kitQueueHeight='Summon window: height',kitQueueScale='Summon window: scale',
 kitQueueSizingHelp='Size and text scale of the 123 window (applied after combat).',
 kitQueueOpen='Summons',kitQueueClose='Close',kitQueueSettings='Left-click: open / close. Right-click: window settings.',
 kitQueueButtonDesign='123 button: design',kitQueueButtonScale='123 button: size',kit_full='Full',kit_compact='Compact',kit_icon='Icon',
 kitQueueButtonMove='Move the 123 button',kitQueueButtonReset='Reset button position',
 kitQueueButtonHelp='Pick a design for the 123 button, enable placement and drag the gold handle (outside combat).',
 kitQueueButtonDrag='Drag to move the 123 button. Right-click to finish.',
 kitQueueEmptyHelp='Ask your group to type 123 in chat.\nWhispers count too.',
 kitQueueInvoke='Summon',kitQueueUnavailable='Unavailable',kitQueuePaused='Combat',
 kitQueueRemove='Remove request (does not summon)',kitQueueOutside='Outside group',
 kitQueueGrouped='In group',kitQueueDisabled='Kit disabled',kitQueueAge='%d:%02d ago',
 kitQueueFrozen='Combat · List frozen until combat ends.',
 kitQueueReadyHint='Click a player to summon · × or right-click to remove',
 kitQueueFooter='Mouse wheel: change page · Drag the title to move',
 shardClickHelp='Left-click: show / hide buttons.\nRight-click: button settings.\nShift-click: delete extra shards.\nDrag to move. /fk shards: shard settings.',
}
local kitFR={
 kitStateActive='Effet actif',kitStateInactive='Inactif · Cliquer pour créer / activer',kitStateUnknown='État inconnu',kitHealthCount='Pierres de soins dans vos sacs',kitSoulCount='Pierres d’âme dans vos sacs',
 kitQueueIconTitle='Invocation · 123',kitQueueIconHelp='Remplace le Rituel d’invocation dans le kit. Clic gauche : demandes. Clic droit : réglages.',
 kitOptionsTitle='Vos boutons de sorts',kitOptionsSubtitle='Choisissez une disposition et gardez vos sorts à portée de main.',
 kitTab_layout='Disposition',kitTab_buttons='Boutons',kitTab_summons='Invocation',
 kitSummon_button='Bouton 123',kitSummon_window='Fenêtre des demandes',
 kitDirection='Direction',kitBaseSize='Taille de base des icônes',kitFreeTitle='Placer chaque bouton',
 kitFreeSteps='1. Activer le déplacement   2. Glisser les poignées dorées\n3. Terminer le placement pour utiliser vos sorts.',
 kitVisibleTitle='Groupes visibles',kitShowAll='Tout afficher',kitHideAll='Tout masquer',kitOptionsQueueOpen='Ouvrir les demandes d’invocation',kitActive='Actif',
 kitVisibilityHelp='Affichez ou masquez chaque groupe de boutons ; les groupes masqués gardent leurs réglages.',
 kitStatusLive='Application immédiate · Enregistrement automatique',kitStatusCombat='En combat · Changements appliqués à la sortie',
 kitStatusOff='Les boutons de sorts sont désactivés',kitStatusEdit='Placement en cours · Terminez quand vous êtes prêt',
 kitCircleHelp='Une distance négative rapproche les boutons (ils peuvent se chevaucher).',
 kitScaleHelp='Taille des boutons et menus ; le fragment garde sa taille.',
 kit='Boutons de sorts',kitHelp='Cliquer sur le fragment pour replier / déplier les boutons. Clic droit : réglages. Maj-clic : supprimer le surplus. Glisser l’icône pour déplacer. Raccourcis dans WoW > Raccourcis > Felkit.',
 kitLayout='Présentation',kit_circle='Cercle',kit_horizontal='Horizontale',kit_vertical='Verticale',kit_grid='Grille compacte',
 kit_free='Libre',kitEdit='Déplacer les boutons',kitEditDone='Terminer le placement',kitReset='Réinitialiser le placement',
 kitDragHelp='Glisser pour déplacer. Cette poignée ne lance aucun sort.',
 kitFreeHelp='Choisir Libre, puis Déplacer les boutons. Glisser chaque poignée dorée, puis terminer le placement pour utiliser les sorts. Positions sauvegardées ; déplacer le fragment déplace l’ensemble. Édition suspendue en combat.',
 kit_left='Gauche',kit_right='Droite',kit_up='Haut',kit_down='Bas',
 kitCircleDistance='Cercle : distance supplémentaire',kitHorizontalDirection='Horizontale : direction',
 kitVerticalDirection='Verticale : direction',kitGridDirection='Grille : côté du fragment',kitScale='Échelle des boutons',
 kitGeometryHelp='Distance négative : cercle plus proche que l’espacement standard ; les boutons peuvent se chevaucher. Le fragment reste dégagé. Chaque direction concerne sa présentation. L’échelle inclut les menus et conserve la taille du fragment. Application immédiate hors combat.',
 kitSize='Taille des boutons',kitHideUnknown='Masquer les sorts non appris',kitWeaponChoice='Pierre d’arme',kitWeaponHelp='Type de pierre du bouton d’arme ; votre meilleure pierre ou meilleur rang est toujours utilisé.',kitFirestone='Pierre de feu',kitSpellstone='Pierre de sort',kitDeferred='Les changements seront appliqués après le combat.',
 kit_health='Pierre de soins',kit_soul='Pierre d’âme',kit_demon='Démons',kit_sacrifice='Sacrifice démoniaque',kit_link='Lien spirituel',kit_domination='Domination corrompue',
 kit_curse1='Malédiction 1',kit_curse2='Malédiction 2',kit_ward='Gardien de l’ombre',kit_armor='Armure / Peau de démon',kit_weapon='Pierre de feu / Pierre de sort',kit_summon='Rituel d’invocation',kit_utility='Sorts utilitaires',
 kitClick='Clic gauche : lancer / utiliser. Clic droit : choisir sans lancer.',kitCreate='Maj-clic : créer le meilleur rang appris. Clic droit : choisir le type de pierre.',
 kitStateObserved='Dernier état connu ; peut ne plus être à jour.',
 kitUtilityInactive='Effet inactif',kitUtilityTarget='Lancé sur votre cible amie, ou sur vous à défaut.',
 kitSelectHelp='Cliquez pour sélectionner sans lancer, puis utilisez le bouton principal.',
 kitSoulBest='Utilise votre meilleure pierre d’âme, en la créant d’abord si besoin. Maj-clic : créer.',kitHealthBest='Vie pleine : crée votre meilleure pierre de soins manquante. Blessé : utilise la meilleure. Maj-clic : créer.',
 kitUse='Pierre disponible : cliquer pour utiliser / appliquer.',kitUnknown='Sort non appris',kitDemonShift='Maj-clic : Domination corrompue puis invocation (si apprise).',
 kitQueue='Demandes d’invocation · 123',kitQueueCount='%d demande(s) · expiration après 10 min',
 kitQueueCombat='Liste actualisée après combat. Le bouton 123 l’ouvre / la ferme.',
 kitQueueHelp='Liste les joueurs qui écrivent 123 dans le chat de groupe ou en privé. Clic gauche : invoquer (hors combat). Clic droit : retirer.',
 kitNotGrouped='indisponible / hors groupe',
 kitQueueSubtitle='Felkit · Invocation manuelle',kitQueueEmpty='Aucune demande pour le moment',
 kitQueueWidth='Fenêtre 123 : largeur',kitQueueHeight='Fenêtre 123 : hauteur',kitQueueScale='Fenêtre 123 : échelle',
 kitQueueSizingHelp='Taille et échelle du texte de la fenêtre 123 (appliquées après combat).',
 kitQueueOpen='Invocation',kitQueueClose='Fermer',kitQueueSettings='Clic gauche : ouvrir / fermer. Clic droit : réglages de la fenêtre.',
 kitQueueButtonDesign='Bouton 123 : design',kitQueueButtonScale='Bouton 123 : taille',kit_full='Complet',kit_compact='Compact',kit_icon='Icône',
 kitQueueButtonMove='Déplacer le bouton 123',kitQueueButtonReset='Réinitialiser sa position',
 kitQueueButtonHelp='Choisissez un design pour le bouton 123, activez le placement et glissez la poignée dorée (hors combat).',
 kitQueueButtonDrag='Glisser pour déplacer le bouton 123. Clic droit pour terminer.',
 kitQueueEmptyHelp='Invitez votre groupe à écrire 123 dans le chat.\nLes messages privés comptent aussi.',
 kitQueueInvoke='Invoquer',kitQueueUnavailable='Indisponible',kitQueuePaused='Combat',
 kitQueueRemove='Retirer la demande (sans invoquer)',kitQueueOutside='Hors groupe',
 kitQueueGrouped='Dans le groupe',kitQueueDisabled='Kit désactivé',kitQueueAge='il y a %d:%02d',
 kitQueueFrozen='Combat · Liste figée jusqu’à la fin du combat.',
 kitQueueReadyHint='Cliquer pour invoquer · × ou clic droit pour retirer',
 kitQueueFooter='Molette : changer de page · Glisser le titre pour déplacer',
 shardClickHelp='Clic gauche : afficher / masquer les boutons.\nClic droit : réglages des boutons.\nMaj-clic : supprimer les fragments en trop.\nGlisser pour déplacer. /fk shards : réglages des fragments.',
}
for k,v in pairs(kitEN) do en[k]=v; fr[k]=kitFR[k] or v end
en.dotAuto='Automatic durations and ticks'; fr.dotAuto='Durées et ticks automatiques'
en.enemiesCombatOnly='Only enemies in combat'; fr.enemiesCombatOnly='Uniquement les ennemis en combat'
en.healthWidth='Health bar width'; fr.healthWidth='Largeur de la barre de vie'
en.healthHeight='Health bar height'; fr.healthHeight='Hauteur de la barre de vie'
en.healthMode='Health display'; fr.healthMode='Affichage de la vie'
en.healthMode1='Current / maximum'; fr.healthMode1='Actuels / maximum'
en.healthMode2='Value'; fr.healthMode2='Valeur nominale'
en.healthMode3='Percentage'; fr.healthMode3='Pourcentage'
en.nightfallIntro='A clear signal when Nightfall appears. Choose your sound, then place the visual above or below your character.'
fr.nightfallIntro='Un signal clair dès que Crépuscule apparaît. Choisissez votre son, puis placez le visuel au-dessus ou sous votre personnage.'
en.nightfallEnabled='Enable Nightfall alerts'; fr.nightfallEnabled='Activer les alertes Crépuscule'
en.nightfallReady='SHADOW TRANCE ACTIVE'; fr.nightfallReady='TRANSE DE L’OMBRE ACTIVE'
en.nightfallDemo='PREVIEW • 5 SECONDS'; fr.nightfallDemo='APERÇU • 5 SECONDES'
en.nightfallTest='Test enabled alerts'; fr.nightfallTest='Tester les alertes activées'
en.nightfallStop='Stop preview'; fr.nightfallStop='Arrêter l’aperçu'
en.nightfallTone='Sound signature'; fr.nightfallTone='Signature sonore'
en.nightfallChime='Crystal'; fr.nightfallChime='Cristal'
en.nightfallBell='Low bell'; fr.nightfallBell='Cloche grave'
en.nightfallShadow='Shadow bloom'; fr.nightfallShadow='Éclat d’ombre'
en.nightfallVolume='Alert volume'; fr.nightfallVolume='Volume de l’alerte'
en.nightfallSoft='Soft'; fr.nightfallSoft='Doux'
en.nightfallMedium='Balanced'; fr.nightfallMedium='Équilibré'
en.nightfallFull='Full'; fr.nightfallFull='Fort'
en.nightfallChannel='Playback channel'; fr.nightfallChannel='Canal de lecture'
en.nightfallSFX='Sound effects (SFX)'; fr.nightfallSFX='Effets sonores (SFX)'
en.nightfallMaster='Master'; fr.nightfallMaster='Principal'
en.nightfallListen='Listen to sound'; fr.nightfallListen='Écouter le son'
en.nightfallSoundHelp='One sound per proc, with no repeating loop. SFX follows effects volume; Master follows overall volume. No game volume is changed. Listen tests the sound even when automatic sound alerts are off.'
fr.nightfallSoundHelp='Un son par déclenchement, sans boucle. SFX suit le volume des effets ; Principal suit le volume général. Aucun volume du jeu n’est modifié. Écouter teste le son même si l’alerte sonore automatique est désactivée.'
en.nightfallSoundFailed='Sound failed. Check that game audio and the selected channel are on.'
fr.nightfallSoundFailed='Échec du son. Vérifiez l’audio du jeu et le canal choisi.'
en.alertEdges='Soft violet screen edges'; fr.alertEdges='Halo violet doux sur les bords'
en.nightfallSize='Visual size'; fr.nightfallSize='Taille du visuel'
en.nightfallPosition='Vertical position (+ above / − below)'; fr.nightfallPosition='Position verticale (+ haut / − bas)'
en.nightfallVisualTest='Preview visual (5 s)'; fr.nightfallVisualTest='Voir le visuel (5 s)'
en.nightfallVisualHelp='The icon and text stay readable at any edge intensity. Pulsing affects only the edges. The countdown appears only when the aura duration is available. Preview works even with automatic visuals off. Clicks pass through the alert.'
fr.nightfallVisualHelp='L’icône et le texte restent lisibles quelle que soit l’intensité du halo. Seuls les bords pulsent. Le compte à rebours apparaît uniquement si la durée de l’aura est disponible. L’aperçu fonctionne même avec le visuel automatique désactivé. Les clics traversent l’alerte.'

en.healthMode4='Value + percentage'; fr.healthMode4='Valeur + pourcentage'
en.channelTimer='Channel'; fr.channelTimer='Canalisation'
local spellEN={
 spellOverview='Overview',spellCalculation='Calculation',spellDescription='Spell description',
 spTalentGain='Talent bonus',spAverageTick='Average per tick',
 spCombatReference='Estimate · pre-combat values',
 tapHeading='Health to mana',tapMana='MANA GENERATED',tapHealth='Health converted',
 tapSpirit='Spirit contribution',tapTalent='Improved Life Tap',tapFormula='Calculation',
 grimHeading='Grimoire & tooltips',grimIntro='Find a spell or choose where its damage details appear.',
 grimTab_catalogue='Spells',grimTab_display='Display',grimOn='On',grimOff='Off',
 grimOption_grimoire='Spell catalogue',grimHelp_grimoire='Browse and search spells here. Does not affect tooltips.',
 grimOption_spellDetails='Damage in spell details',grimHelp_spellDetails='Add base damage, spell power, talents and ticks to the spell detail window.',
 grimOption_spellTooltips='Damage on hover',grimHelp_spellTooltips='Add a short damage summary to spell tooltips.',
 grimPreview='Tooltip preview · example',grimPreviewHelp='Illustration: Corruption, 200 SP and +20% talents. These are not your character’s values.',
 grimShiftHelp='Hold Shift while hovering for formulas and talent details.',
 grimSearch='Search by spell name or ID',grimClear='Clear',grimResults='%d spells found',grimPage='Page %d / %d',
 grimEmpty='No matching spells. Try another name or spell ID.',
 grimDisabled='The catalogue is hidden. Spell details and tooltips keep their own settings.',grimEnable='Show the catalogue',
 grimCatalogueNote='Warlock spells (pet spells excluded). Click a row for details.',
 spCardHeading='Damage estimate',spCardTotal='TOTAL DAMAGE',spCardTick='Per tick',
 spCardInitial='Initial',spCardBaseSP='Base + SP',spCardTalents='Talents',
 spCardEffective='Effective SP',spCardRhythm='Cadence',spCardDuration='total',
 spCardReference='Variable reference',spCardVariable='Variable ticks · full total unknown',
 spCardLimits='Excludes crits, target/next-cast bonuses and mitigation',
 spCardHint='Shift + hover: full breakdown',spCardTotalAoe='TOTAL PER TARGET',spCardSum='Total: base + effective SP',spCardSumAoe='Per target: base + effective SP',
 spellDetails='Show base damage, spell power and ticks',
 spellTooltips='Spell details in tooltips (next hover)',
 spTooltipNote='Estimate with learned damage talents and readable personal talent buffs. Target/next-cast conditions listed separately, excluded from totals. Non-critical, before mitigation; full base duration.',
 spHeading='Nominal damage breakdown',spSource='Client data (wago.tools), build',
 spPower='Current spell power for this school:',spLevel='Player level:',
 spBase='Base',spBonus='SP bonus',spDirect='Initial / direct damage',spTick='Per tick, per target',
 spVariable='DB2 reference value — variable ticks',spPeriodicTotal='Full periodic effect',spCombined='Initial + periodic total',
 spTiming='%d ticks × every %s s = %s s (base duration)',
 spLimits='(Base + SP contribution) × damage talents. Effective SP contribution includes this multiplier. Target modifiers, critical hits, resistance and absorption excluded.',
 spUnequal='Tick damage may vary; this value is not per tick.',
 spFootnote='Client data estimate, not observed damage. Learned damage talents and readable personal talent buffs included; listed target/next-cast conditions excluded. Non-critical, before mitigation. Full base duration assumed; haste, interruptions, server hotfixes, healing and self damage excluded. Rounded for display only.',
 talApplied='Applied talents',talNone='No applicable damage bonus',talActive='active aura',
 talEffective='SP contribution after talents',
 talUnknown='Talents unreadable or unsaved: final damage unknown.',
 talBuffUnknown='Talent buff unreadable: final damage unknown.',
 talCritical='Critical damage bonus.',
 talCasting='Cast time only; spell power bonus unchanged.',
 talDecimation='+%g%% below 35%% target health (not in total).',
 talSiphon='+%g%% per other Affliction effect, up to 3 (not in total).',
 talShadowBolt='+%g%% shadow damage with your debuff on the target (not in total).',
 talAmplify='+%g%% on the next eligible bane (not in total).',
 talKnowledge='Demonic Knowledge: already included in your spell power.',
 spMismatch='No calculation: game version doesn\'t match the add-on data.',
 spUnsupported='Damage formula unknown for this spell.',
}
local spellFR={
 spellOverview='Essentiel',spellCalculation='Calcul détaillé',spellDescription='Description du sort',
 spTalentGain='Bonus des talents',spAverageTick='Moyenne par tick',
 spCombatReference='Estimation · valeurs avant combat',
 tapHeading='Vie en mana',tapMana='MANA GÉNÉRÉ',tapHealth='Vie convertie',
 tapSpirit='Contribution de l’Esprit',tapTalent='Connexion améliorée',tapFormula='Calcul',
 grimHeading='Grimoire et infobulles',grimIntro='Consultez un sort ou choisissez où afficher ses dégâts.',
 grimTab_catalogue='Sorts',grimTab_display='Affichage',grimOn='Activé',grimOff='Désactivé',
 grimOption_grimoire='Catalogue de sorts',grimHelp_grimoire='Consulter et rechercher les sorts ici. Sans effet sur les infobulles.',
 grimOption_spellDetails='Dégâts dans les fiches',grimHelp_spellDetails='Ajouter la base, le spell power, les talents et les ticks à la fiche du sort.',
 grimOption_spellTooltips='Dégâts au survol',grimHelp_spellTooltips='Ajouter un court résumé des dégâts aux infobulles des sorts.',
 grimPreview='Aperçu d’infobulle · exemple',grimPreviewHelp='Illustration : Corruption, 200 SP et +20% de talents. Ce ne sont pas les valeurs de votre personnage.',
 grimShiftHelp='Maintenez Maj au survol pour les formules et le détail des talents.',
 grimSearch='Rechercher par nom de sort ou identifiant',grimClear='Effacer',grimResults='%d sorts trouvés',grimPage='Page %d / %d',
 grimEmpty='Aucun sort trouvé. Essayez un autre nom ou identifiant.',
 grimDisabled='Le catalogue est masqué. Les fiches et les infobulles conservent leurs propres réglages.',grimEnable='Afficher le catalogue',
 grimCatalogueNote='Sorts de démoniste (familiers exclus). Cliquez sur un sort pour sa fiche.',
 spCardHeading='Dégâts estimés',spCardTotal='DÉGÂTS TOTAUX',spCardTick='Par tick',
 spCardInitial='Initial',spCardBaseSP='Base + SP',spCardTalents='Talents',
 spCardEffective='SP effectif',spCardRhythm='Cadence',spCardDuration='au total',
 spCardReference='Référence variable',spCardVariable='Ticks variables · total complet inconnu',
 spCardLimits='Hors critique, bonus de cible/prochain sort et mitigation',
 spCardHint='Maj + survol : détail complet',spCardTotalAoe='TOTAL PAR CIBLE',spCardSum='Total : base + SP effectif',spCardSumAoe='Par cible : base + SP effectif',
 spellDetails='Afficher base, puissance des sorts et ticks',
 spellTooltips='Détail dans les infobulles (au prochain survol)',
 spTooltipNote='Estimation avec talents appris et auras personnelles de talents lisibles. Conditions de cible/prochain sort signalées séparément, exclues du total. Hors critique et mitigation ; durée de base complète.',
 spHeading='Décomposition des dégâts nominaux',spSource='Données client (wago.tools), build',
 spPower='Puissance actuelle pour cette école :',spLevel='Niveau du joueur :',
 spBase='Base',spBonus='Bonus SP',spDirect='Dégâts initiaux / directs',spTick='Par tick, par cible',
 spVariable='Valeur de référence DB2 — ticks variables',spPeriodicTotal='Effet périodique complet',spCombined='Total initial + périodique',
 spTiming='%d ticks × toutes les %s s = %s s (durée de base)',
 spLimits='(Base + contribution du SP) × talents de dégâts. La contribution SP effective inclut ce multiplicateur. Hors modificateurs de cible, critiques, résistances et absorption.',
 spUnequal='Les dégâts par tick peuvent varier ; cette valeur n’est pas par tick.',
 spFootnote='Estimation des données client, pas des dégâts observés. Talents de dégâts appris et auras personnelles lisibles inclus ; conditions de cible/prochain sort signalées mais exclues. Hors critique et mitigation. Durée de base complète ; hâte, interruptions, hotfixes serveur, soins et dégâts sur soi exclus. Arrondi uniquement à l’affichage.',
 talApplied='Talents appliqués',talNone='Aucun bonus de dégâts applicable',talActive='aura active',
 talEffective='Contribution SP après talents',
 talUnknown='Talents illisibles ou non validés : dégâts finaux inconnus.',
 talBuffUnknown='Aura de talent illisible : dégâts finaux inconnus.',
 talCritical='Dégâts critiques uniquement ; exclus de cette estimation hors critique.',
 talCasting='Temps d’incantation uniquement ; bonus de spell power inchangé.',
 talDecimation='+%g%% sous 35%% de vie de la cible (hors total).',
 talSiphon='+%g%% par autre effet d’Affliction, jusqu’à 3 (hors total).',
 talShadowBolt='+%g%% de dégâts d’ombre avec votre affaiblissement sur la cible (hors total).',
 talAmplify='+%g%% sur le prochain fléau éligible (hors total).',
 talKnowledge='Connaissance démoniaque : déjà incluse dans votre spell power.',
 spMismatch='Pas de calcul : la version du jeu ne correspond pas aux données de l’addon.',
 spUnsupported='Formule de dégâts inconnue pour ce sort.',
}
for k,v in pairs(spellEN) do en[k]=v; fr[k]=spellFR[k] or v end
en.healthMode5='Value + % + maximum'; fr.healthMode5='Valeur + % + maximum'
en.enemyNameHeader='Separate enemy name header'; fr.enemyNameHeader='Bandeau de nom séparé'
en.nightfallIntro='The actual Shadow Trance proc sound, louder, and two violet bars framing the centre of the screen.'
fr.nightfallIntro='Le son du proc Transe de l’ombre, renforcé, et deux barres violettes de part et d’autre du centre de l’écran.'
en.nightfallSoundHelp='Original Shadow Trance proc recording. Volume saved in 10% steps: 0% = silent, 100% = boosted level. Changes apply to the next playback; use Listen to compare. Master and other game volumes stay unchanged. Listen works even with automatic sound alerts off.'
fr.nightfallSoundHelp='Enregistrement original du proc Transe de l’ombre. Volume sauvegardé par pas de 10 % : 0 % = muet, 100 % = niveau renforcé. Le changement s’applique à la prochaine lecture ; utilisez Écouter pour comparer. Les volumes du jeu restent inchangés. Écouter fonctionne même si le son automatique est désactivé.'
en.nightfallVisualHelp='Two vertical violet bars, centred around your character. No card, icon, text or screen-edge vignette. They disappear with the proc. Clicks pass through. Preview lasts five seconds.'
fr.nightfallVisualHelp='Deux barres verticales violettes centrées autour du personnage. Aucun panneau, icône, texte ni bord d’écran coloré. Elles disparaissent avec le proc. Les clics passent au travers. L’aperçu dure cinq secondes.'
en.intensity='Bar opacity'; fr.intensity='Opacité des barres'
en.nightfallGap='Distance from centre'; fr.nightfallGap='Distance au centre'
en.nightfallHeight='Bar height'; fr.nightfallHeight='Hauteur des barres'
en.nightfallWidth='Bar width'; fr.nightfallWidth='Largeur des barres'
en.pulse='Gentle bar pulse (off = steady)'; fr.pulse='Pulsation douce des barres (sinon fixes)'
en.dotChannels='Show drains and Wrack in enemy timers'; fr.dotChannels='Afficher les drains et Calvaire dans les timers'
en.dotSelectionFrame='Outline the selected enemy'; fr.dotSelectionFrame='Encadrer la cible sélectionnée'
en.dotDurationMode='DoT bar lengths'; fr.dotDurationMode='Longueur des barres de DoT'
en.dotDurationMode1='Equal length'; fr.dotDurationMode1='Largeur identique'
en.dotDurationMode2='Proportional to duration'; fr.dotDurationMode2='Proportionnelle à la durée'
en.dotOptionsIntro='Choose which enemies appear, then adjust health and timers. Changes are saved immediately.'
fr.dotOptionsIntro='Choisissez les ennemis visibles, puis réglez la vie et les timers. Réglages enregistrés immédiatement.'
en.dotEnable='Show enemies and DoTs'; fr.dotEnable='Afficher les ennemis et leurs DoT'
en.dotTab_display='Display'; fr.dotTab_display='Affichage'
en.dotTab_health='Health'; fr.dotTab_health='Vie'
en.dotTab_timers='DoTs'; fr.dotTab_timers='DoT'
en.dotTab_advanced='Advanced'; fr.dotTab_advanced='Avancé'
en.dotWho='Visible enemies'; fr.dotWho='Ennemis visibles'
en.dotGroupOnly='Combat with you, your party or raid only.'
fr.dotGroupOnly='Combat avec vous, votre groupe ou raid uniquement.'
en.dotRangeHelp='Enemies are discovered through nameplates. Effects are sorted by expiry, soonest first.'
fr.dotRangeHelp='Les ennemis sont détectés via leurs nameplates. Les effets qui expirent le plus tôt sont affichés en premier.'
en.dotTickHelp='Light notches: predicted ticks. Gold notch: next predicted tick. Hover shows cadence; unknown cadence has no marks.'
fr.dotTickHelp='Repères clairs : ticks prévus. Repère doré : prochain tick prévu. Cadence inconnue : aucun repère.'
en.dotTickInterval='Tick interval: %.2f s'; fr.dotTickInterval='Intervalle des ticks : %.2f s'
en.dotNextTick='Next predicted tick in %.1f s'; fr.dotNextTick='Prochain tick prévu dans %.1f s'
en.dotHealthTitle='Health bar and name'; fr.dotHealthTitle='Barre de vie et nom'
en.dotHealthFormat='Health text · examples'; fr.dotHealthFormat='Texte de vie · exemples'
en.dotNameHelp='Name inside the health bar, or above it with the separate header.'
fr.dotNameHelp='Nom dans la barre de vie, ou au-dessus avec le bandeau séparé.'
en.dotPreview='Example · 6 s and 12 s remaining'; fr.dotPreview='Aperçu · 6 s et 12 s restantes'
en.dotEqualHelp='Each bar starts at full width and empties against its own total duration. Example: 24 s total for both spells.'
fr.dotEqualHelp='Chaque barre part de la largeur maximale et se vide selon sa durée totale. Exemple : 24 s au total pour les deux sorts.'
en.dotProportionalHelp='Track width follows total duration: 12 s is half of 24 s. Only the fill empties. Expiry never stretches the other tracks.'
fr.dotProportionalHelp='Largeur totale selon la durée initiale : 12 s = moitié de 24 s. Seul le remplissage diminue. Une expiration n’étire plus les autres barres.'
en.dotDurationHelp=en.dotProportionalHelp; fr.dotDurationHelp=fr.dotProportionalHelp
en.dotEffectsTitle='Effects and ticks'; fr.dotEffectsTitle='Effets et ticks'
en.dotWarningHelp='Known tick cadence takes priority over this fallback warning threshold. Tick marks are predictions.'
fr.dotWarningHelp='La cadence connue prime sur ce seuil. Repères clairs : ticks prévus ; doré : prochain tick. Détail au survol du sort.'
en.dotTimingTitle='Automatic detection'; fr.dotTimingTitle='Détection automatique'
en.dotTimingHelp='Automatic for supported spells. ~ marks an estimate.'
fr.dotTimingHelp='Automatique pour les sorts pris en charge. ~ indique une estimation.'
en.dotExpertTitle='Manual profiles · optional'; fr.dotExpertTitle='Profils manuels · facultatifs'
en.dotExpertHelp='Optional; used only with automatic timing off.'
fr.dotExpertHelp='Facultatif ; utilisé seulement si le mode automatique est désactivé.'
en.nightfallVisualHelp='Two tapered violet energy blades, with bright inner cores and a soft local glow. Smooth arrival; steady afterwards when pulse is off. Pulse adds gentle travelling accents. Clicks pass through. Preview lasts five seconds.'
fr.nightfallVisualHelp='Deux lames d’énergie violettes effilées, avec cœur lumineux et halo local doux. Apparition progressive, puis effet fixe si la pulsation est désactivée. La pulsation ajoute des accents lumineux mobiles. Les clics passent au travers. Aperçu de cinq secondes.'
en.nightfallSoundHelp='Exact Shadow Trance proc recording, amplified further. 100% uses the stronger level; 0% is silent. Saved in 10% steps. Use Listen to compare. Game volumes stay unchanged.'
fr.nightfallSoundHelp='Son exact du proc Transe de l’ombre, davantage amplifié. 100 % correspond au nouveau niveau renforcé ; 0 % est muet. Choix sauvegardé par pas de 10 %. Utilisez Écouter pour comparer. Les volumes du jeu restent inchangés.'
S.Locales={enUS=en,frFR=fr,en=en,fr=fr}
en.dotTab_style='Style'; fr.dotTab_style='Style'
en.enemyStyle='Presentation'; fr.enemyStyle='Présentation'
en.enemyStyle1='Cards'; fr.enemyStyle1='Cartes'
en.enemyStyle2='Compact'; fr.enemyStyle2='Compact'
en.enemyStyle3='Clean lines'; fr.enemyStyle3='Lignes épurées'
en.enemyDecor='Borders and background'; fr.enemyDecor='Bordures et fond'
en.enemyBorder='Show borders (including selected target)'; fr.enemyBorder='Afficher les bordures (cible comprise)'
en.enemyBackground='Show background panels and tracks'; fr.enemyBackground='Afficher le fond des panneaux et des barres'
en.enemyPlacement='Position and size'; fr.enemyPlacement='Position et dimensions'
en.enemyLocked='Lock enemy frame'; fr.enemyLocked='Verrouiller le cadre des ennemis'
en.enemyMove='Move'; fr.enemyMove='Déplacer'
en.enemyEditLabel='Edit'; fr.enemyEditLabel='Modifier'
en.enemyFinishLabel='Lock'; fr.enemyFinishLabel='Verrouiller'
en.enemyResize='Resize'; fr.enemyResize='Redimensionner'
en.enemyDone='Finish and lock'; fr.enemyDone='Terminer et verrouiller'
en.enemyEditHelp='Unlock to move or resize the frame; Lock hides the controls. Outside combat only.'
fr.enemyEditHelp='Déverrouillez pour déplacer ou redimensionner le cadre ; Verrouiller masque les boutons. Hors combat uniquement.'
en.enemyMoveHint='Drag to move\nUse Lock on the frame to finish'; fr.enemyMoveHint='Glissez pour déplacer\nVerrouiller dans le cadre pour terminer'
en.enemyResizeHint='Drag right/down to resize\nUse Lock on the frame to finish'; fr.enemyResizeHint='Glissez vers la droite/le bas pour agrandir\nVerrouiller dans le cadre pour terminer'
en.enemyAutoHeight='Fit height to content'; fr.enemyAutoHeight='Adapter la hauteur au contenu'
en.enemyHeight='Frame height (maximum if automatic)'; fr.enemyHeight='Hauteur du cadre (maximum si automatique)'
en.dotConfirmedOnly='Confirmed effects only'; fr.dotConfirmedOnly='Effets confirmés uniquement'
en.dotConfirmedHelp='Backup display only: off allows estimated timers that may include missed casts.'
fr.dotConfirmedHelp='Le mode natif affiche les auras personnelles réelles, même protégées. Ce réglage concerne le repli sur données publiques ; le désactiver peut créer des estimations sur des impacts ratés.'
en.dotNativeHelp='Native mode: Blizzard controls bars and expiration order. Uniform widths, no calculated ticks, configured frame height. Proportions, ticks and automatic height apply to public fallback/preview. Retention needs public deadlines. Style changes wait until combat ends.'
fr.dotNativeHelp='Mode natif : Blizzard gère les barres et le tri par expiration. Largeurs uniformes, sans ticks calculés, hauteur du cadre réglée. Proportions, ticks et hauteur auto : repli public/aperçu. Maintien hors portée : durées publiques. Le style change après le combat.'
en.dotTickHelp='Lines: upcoming ticks. Gold: next tick.'
fr.dotTickHelp='Traits : prochains ticks. Doré : prochain tick.'
-- Interface language: a saved preference ('auto' follows the game client).
-- Translations live in Locale_<code>.lua; LocaleUI.lua applies the choice once
-- every table is loaded. S.L is refilled in place, so references stay valid.
S.LANGUAGES={
 {code='en',native='English',chip='EN',clients={enUS=true,enGB=true}},
}
local byCode={}; for _,l in ipairs(S.LANGUAGES) do byCode[l.code]=l end
S.languageInfo=byCode
-- Font files shipped with every client for these alphabets.
local SCRIPT_FONTS={zh='Fonts\\ARKai_T.ttf',ru='Fonts\\FRIZQT___CYR.TTF'}
function S.clientLanguage() return 'en' end
function S.languageCode() return 'en' end
-- The client font covers its own alphabet; another alphabet needs its font.
function S.fontFor(code)
 local standard=STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF'
 local wanted=byCode[code] and byCode[code].script
 local client=byCode[S.clientLanguage()].script
 if wanted and wanted~=client then return SCRIPT_FONTS[wanted] end
 return standard
end
function S.font() return S.fontFor(S.language or S.clientLanguage()) end
S.L=S.L or {}
function S.applyLocale(pref)
 local code=S.languageCode(pref)
 local english=S.Locales.en
 local chosen=S.Locales[code] or english
 S.language=code
 for k in pairs(S.L) do S.L[k]=nil end
 for k,v in pairs(english) do S.L[k]=chosen[k] or v end
 for k,v in pairs(chosen) do S.L[k]=v end
 setmetatable(S.L,{__index=function(_,k) return english[k] end})
 BINDING_HEADER_FELKIT='Felkit'
 for _,key in ipairs({'health','soul','demon','sacrifice','link','domination','curse1','curse2','ward','armor','weapon','drain','summon','utility'}) do
  _G['BINDING_NAME_CLICK FelkitKit'..key..':LeftButton']=S.L['kit_'..key]
 end
 _G['BINDING_NAME_CLICK FelkitShardIcon:LeftButton']=S.L.kit
 _G['BINDING_NAME_CLICK FelkitQueueToggle:LeftButton']=S.L.kitQueue
 return code
end
S.applyLocale()
