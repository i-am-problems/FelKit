-- Strings for the 0.5 interface (settings window, first-launch assistant,
-- native DoT engine). Missing French keys fall back to English.
local _,S=...
local en={
 chatMessages='Show addon messages in chat',chatMessagesHelp='Off: hides all addon messages in chat.',
 nav_home='Home',nav_enemies='Enemies & DoTs',nav_kit='Action kit',nav_shards='Soul Shards',nav_nightfall='Nightfall',
 nav_grimoire='Grimoire',nav_channels='Channels',nav_general='General',
 navDesc_home='Your modules, quick actions and status.',
 navDesc_enemies='Enemies in combat with you or your group, with your DoTs.',
 navDesc_kit='Buttons for stones, demons, curses, armors and summons around the shard counter.',
 navDesc_shards='Shard counter, maximum to keep and auto-clean.',
 navDesc_nightfall='Shadow Trance proc: violet bars on screen and a louder sound.',
 navDesc_grimoire='Spell catalogue, details and richer tooltips.',
 navDesc_channels='Tick marks on the WoW channel bar.',
 navDesc_general='Display, positions, help and diagnostics.',
 tab_enemies_display='Display',tab_enemies_timers='DoTs',tab_enemies_health='Health',tab_enemies_frame='Frame',tab_enemies_advanced='Advanced',
 tab_kit_layout='Layout',tab_kit_buttons='Buttons',tab_kit_summons='Summons',
 tab_grimoire_catalogue='Catalogue',tab_grimoire_display='Options',
 moduleOn='On',moduleOff='Off',configure='Configure',
 tile_enemies='DoT bars per enemy, health and target highlight.',
 tile_kit='Stones, demons, curses and summons one click away.',
 tile_shards='Live counter and automatic excess cleaning.',
 tile_nightfall='Visual and sound alert when Shadow Trance procs.',
 tile_grimoire='Spell catalogue, sheets and detailed tooltips.',
 tile_channels='Tick marks on Drain Life, Drain Soul, Rain of Fire…',
 homeTitle='Felkit',homeIntro='Everything for the Forever warlock in one place. Turn modules on or off here, then fine-tune each one from the sidebar.',
 homeStatus='Addon active  ·  %d of %d modules on',homeDisabled='Addon disabled — enable it in General.',
 homeModules='Modules',homeModulesHelp='Each switch takes effect immediately. Configure opens the module page.',
 homeHealth='Status',homeHealthHelp='Read-only checks. No player name, GUID or inventory is exported.',
 healthDots='Native DoT display:',healthNightfall='Nightfall native display:',healthShards='Shards:',
 stateReady='ready',stateError='error',stateIdle='waiting for an enemy',stateFallback='public fallback',
 demo='Demo (10 s)',unlockFrames='Unlock frames',lockFrames='Lock frames',setupAgain='First-launch assistant',
 dotDebug='DoT diagnostic',dotTest='Native test on target',dotRetry='Retry native display',
 cardWho='Which enemies',cardWhoHelp='Only enemies engaged with you, your pet, your group or raid are listed. Fights involving only strangers are ignored.',
 cardStyle='Style',cardStyleHelp='Cards, Compact or Clean lines; borders and backgrounds set separately.',
 cardDotLayout='DoT layout',cardDotLayoutHelp='Each enemy card reserves room for the chosen number of effects. The game client sorts them by expiration and hides expired ones.',
 dotLayout1='Bars',dotLayout2='Icons',
 dotLayout1Help='One line per effect: icon, name, time left and a draining bar.',
 dotLayout2Help='A compact row of icons, each with its time left and a thin bar.',
 dotSlots='Effects shown per enemy',
 cardTracked='Tracked effects',cardTrackedHelp='Only your (and your pet\'s) effects are shown; missed or resisted casts are ignored.',
 dotFilter1='All my harmful effects',dotFilter2='DoTs only',
 dotFilter1Help='Recommended. Every debuff you applied: DoTs, curses, fear, drains…',
 dotFilter2Help='Only DoT spells (Corruption, Agony, Immolate, Siphon Life…).',
 dotChannelsHelp='Shows Drain Life, Drain Soul, Drain Mana and Wrack as timers while they last.',
 cardFallback='Public fallback & demo',cardFallbackHelp='Used by the demo and when the native display is unavailable: proportional bars, predicted ticks and expiry warnings.',
 cardSize='Size',cardEngine='Native display engine',cardEngineHelp='Test the DoT display on your current target.',
 engineBound='%d enemy(ies) bound',
 kitButtonsTitle='Buttons shown',
 cardShardCount='Soul Shards in your bags',cardCleaning='Cleaning',
 cardPreview='Preview',cardTicks='Tick marks',cardChannelSpells='Spells with tick marks',cardChannelSpellsHelp='Uncheck a spell to hide its marks.',
 cardFrames='Frames',cardFramesHelp='Scale and opacity of the enemy frame and shard counter.',
 cardHelp='Help',cardHelpBody='/fk opens this window. /fk dots, kit, shards, nightfall or spells open a page directly. /fk setup reopens the assistant.',
 grimDisplay='Grimoire options',
 aboutLine='Felkit %s  ·  game %s (%s)  ·  MIT licence.',
 sideHint='/fk  ·  /fk setup',
 minimapHelp='Left click: settings. Right click: enemies & DoTs. Drag to move.',
 nativeUnavailable='DoT display unavailable — /fk dots debug',
 dotTestTitle='Felkit · test (current target)',
 dotTestHelp='Your debuffs on the current target appear above the screen centre. Run the command again to close.',
 dotTestFailed='Native test failed:',
 setupTitle='Felkit · first launch',
 setupStep_welcome='Welcome',setupStep_features='Modules',setupStep_tune='Quick settings',setupStep_done='Summary',
 setupWelcomeTitle='Welcome to Felkit',
 setupWelcomeBody='Warlock tools for Forever. Pick what you want in a minute; you can change it later.',
 setupPointOne='Choose your modules',setupPointOneHelp='Keep only what you need: DoTs, action kit, shards, Nightfall…',
 setupPointTwo='Set the essentials',setupPointTwoHelp='DoT layout, shard maximum, alert sound and frame size.',
 setupPointThree='Adjust anytime',setupPointThreeHelp='Type /fk or click the minimap button to open all settings.',
 setupFeaturesIntro='Turn on the features you want; you can change this later.',
 setupFeature_enemies='DoT bars on every engaged enemy, rendered by the game client, with health and target highlight.',
 setupFeature_kit='Secure buttons around the shard counter: stones, demons, curses, armors, summons.',
 setupFeature_shards='Shard counter with a maximum to keep and optional automatic cleaning.',
 setupFeature_nightfall='Violet blades and a reinforced sound when Shadow Trance procs.',
 setupFeature_channels='Predicted tick marks on the WoW channel bar (drains, Rain of Fire, Hellfire).',
 setupFeature_grimoire='Spell catalogue, spell sheets and enriched tooltips with calculations.',
 setupTuneDots='How your DoTs look on each enemy card.',
 setupTuneShards='Shards above this maximum can be removed.',
 setupAutoHelp='Your key presses, casts and world clicks remove the excess, in combat too.',
 setupTuneNightfall='How the Shadow Trance proc is announced.',
 setupTuneInterface='Interface',
 setupDoneTitle='All set!',setupDoneBody='Your setup. Finish to apply it; you can change it later in the settings.',
 setupTip='Tip: /fk opens the settings · /fk demo shows a 10-second preview · /fk setup reopens this assistant.',
 setupBack='Back',setupSkip='Skip — keep defaults',setupNext='Next',setupStart='Get started',setupFinish='Finish',
 setupFinishOpen='Finish and open settings',
 setupDone='Settings saved. Type /fk to change them anytime.',
 setupSkipped='Assistant closed: settings kept. /fk setup reopens it.',
 enemiesCombatOnly='Only enemies in combat',
 enemiesEngagedOnly='Show only enemies fighting me or my group',
 enemiesEngagedOnlyHelp='Off: also shows idle enemies in range. Use the button below if nameplates only appear in combat.',
 platesShowAll='Always show enemy nameplates',platesShowAllDone='Enemy nameplates are now always shown.',
 platesState='WoW enemy nameplates: %s · always shown: %s',
 dotDurationMode='Bar length',dotDurationMode1='Same width',dotDurationMode2='Proportional to duration',
 cardWhoHelp='Enemies come from nameplates (turn on enemy nameplates in game).',
 cardPreviewBars='Test bars',cardPreviewBarsHelp='Shows three test enemies with looping DoTs (hidden in combat or when this window closes).',
 previewToggle='Show test bars',previewTitle='Preview — test bars',
 previewEnemy1='Training dummy',previewEnemy2='Shadow weaver',previewEnemy3='Defias bandit',
 dotTicksNative='Show ticks on the bars',
 dotTicksNativeHelp='A mark for each tick of the spell. DoTs are then grouped by tick cadence (sorted by expiration within each group). Bars layout only.',
 dotSlots='Maximum effects per enemy',
 cardDotLayoutHelp='Each enemy card grows and shrinks with its DoTs. The game client sorts them by expiration and removes expired ones.',
 enemyHeader='Show the frame header',
 enemyHeaderHelp='Title strip above the cards. When hidden, it shows only while the frame is unlocked.',
 cardSizeHelp='Card height follows the number of DoTs.',
 cardFallbackHelp='Backup display used when the main one is unavailable.',
 nightfallIntro='Shadow Trance proc: two violet bars that drain with the proc, plus a louder sound.',
 nightfallVisualHelp='Two vertical violet bars drain as the proc runs out: gradient fill, bright core, halo and a spark riding the top. A flash on arrival; pulsing makes the halo breathe. Clicks pass through. 5-second preview.',
 pulse='Breathing halo',
 cardTicksStyle='Ticks',tickColor='Tick colour',tickColor1='White',tickColor2='Gold',tickColor3='Black',tickColor4='Violet',
 tickAlpha='Tick opacity',tickWidth='Tick thickness',
 cardWarning='Expiry warning',
 cardWarningHelp='In the last seconds, the end of the bar turns from violet to red; pulsing makes it throb.',
 dotTicksNativeHelp='A mark per tick, with a flash each time the bar passes one (Bars layout only).',
 cardDotLayoutHelp='Proportional: bar length follows the spell\'s full duration.',
 mtTitle="Multi-target DoTs (view only)",mtNone="No engaged or dotted targets",mtCountOne="%d engaged or dotted target",mtCount="%d engaged or dotted targets",mtLastSeen="DoT %s (last seen)",mtCardWindow="Multi-target window",mtCardWindowHelp="Up to 16 enemies with your DoTs. Outside combat: drag the title to move, the corner to resize.",mtHideOOC="Hide outside combat",mtAlpha="Window opacity",mtResetPos="Reset position",mtResetSize="Reset size",mtCardDisplay="Display",mtDamageHelp="The thin line on the health bar estimates your remaining DoT damage: amber Corruption, violet Bane, teal Siphon Life, red Immolate.",mtMillis="Tenths of a second under 10 s",mtExecute="20 % health mark",mtCardEffects="Tracked effects",mtCardEffectsHelp="One column per family, only for spells you know. Changes apply out of combat.",mtBanes="Banes",mtCurses="Curses",mtDrains="Drains",mtCredit="Window adapted from Warlock HUD (Apache License 2.0).",
}
local fr={
 chatMessages='Afficher les messages de l’addon dans le chat',chatMessagesHelp='Désactivé : masque tous les messages de l’addon dans le chat.',
 nav_home='Accueil',nav_enemies='Ennemis et DoT',nav_kit="Kit d’actions",nav_shards="Fragments d’âme",nav_nightfall='Crépuscule',
 nav_grimoire='Grimoire',nav_channels='Canalisations',nav_general='Général',
 navDesc_home='Vos modules, actions rapides et état.',
 navDesc_enemies='Les ennemis en combat avec vous ou votre groupe, avec vos DoT.',
 navDesc_kit='Boutons pour pierres, démons, malédictions, armures et invocations autour du compteur.',
 navDesc_shards='Compteur de fragments, maximum à garder et nettoyage auto.',
 navDesc_nightfall='Proc Transe de l’ombre : barres violettes à l’écran et son renforcé.',
 navDesc_grimoire='Catalogue de sorts, fiches et infobulles enrichies.',
 navDesc_channels='Repères de ticks sur la barre de canalisation de WoW.',
 navDesc_general='Affichage, positions, aide et diagnostics.',
 tab_enemies_display='Affichage',tab_enemies_timers='DoT',tab_enemies_health='Vie',tab_enemies_frame='Cadre',tab_enemies_advanced='Avancé',
 tab_kit_layout='Disposition',tab_kit_buttons='Boutons',tab_kit_summons='Invocations',
 tab_grimoire_catalogue='Catalogue',tab_grimoire_display='Options',
 moduleOn='Activé',moduleOff='Désactivé',configure='Régler',
 tile_enemies='Barres de DoT par ennemi, vie et cible mise en évidence.',
 tile_kit='Pierres, démons, malédictions et invocations en un clic.',
 tile_shards='Compteur en direct et nettoyage automatique du surplus.',
 tile_nightfall='Alerte visuelle et sonore au proc de Transe de l’ombre.',
 tile_grimoire='Catalogue de sorts, fiches et infobulles détaillées.',
 tile_channels='Repères de ticks sur Drain de vie, Drain d’âme, Pluie de feu…',
 homeTitle='Felkit',homeIntro='Tout le nécessaire du démoniste Forever au même endroit. Activez ou désactivez les modules ici, puis affinez chacun depuis la barre latérale.',
 homeStatus='Addon actif  ·  %d modules activés sur %d',homeDisabled='Addon désactivé — réactivez-le dans Général.',
 homeModules='Modules',homeModulesHelp='Chaque interrupteur s’applique immédiatement. « Régler » ouvre la page du module.',
 homeHealth='État de fonctionnement',homeHealthHelp='Vérifications en lecture seule. Aucun nom de joueur, GUID ou inventaire exporté.',
 healthDots='Affichage natif des DoT :',healthNightfall='Affichage natif de Crépuscule :',healthShards='Fragments :',
 stateReady='prêt',stateError='erreur',stateIdle='en attente d’un ennemi',stateFallback='repli public',
 demo='Démonstration (10 s)',unlockFrames='Déverrouiller les cadres',lockFrames='Verrouiller les cadres',setupAgain='Assistant de démarrage',
 dotDebug='Diagnostic DoT',dotTest='Test natif sur la cible',dotRetry='Relancer l’affichage natif',
 cardWho='Quels ennemis',cardWhoHelp='Seuls les ennemis engagés avec vous, votre familier, votre groupe ou votre raid sont listés. Un combat entre inconnus est ignoré.',
 cardStyle='Style',cardStyleHelp='Cartes, Compact ou Lignes épurées ; bordures et fonds réglés séparément.',
 cardDotLayout='Disposition des DoT',cardDotLayoutHelp='Chaque carte d’ennemi réserve la place du nombre d’effets choisi. Le client du jeu les trie par expiration et retire ceux qui expirent.',
 dotLayout1='Barres',dotLayout2='Icônes',
 dotLayout1Help='Une ligne par effet : icône, nom, temps restant et barre qui se vide.',
 dotLayout2Help='Une rangée compacte d’icônes, chacune avec son temps restant et une fine barre.',
 dotSlots='Effets affichés par ennemi',
 cardTracked='Effets suivis',cardTrackedHelp='Seuls vos effets (et ceux de votre familier) sont affichés ; sorts ratés ou résistés ignorés.',
 dotFilter1='Tous mes effets nuisibles',dotFilter2='DoT uniquement',
 dotFilter1Help='Recommandé. Toutes vos affections : DoT, malédictions, peur, drains…',
 dotFilter2Help='Uniquement les DoT (Corruption, Agonie, Immolation, Siphon de vie…).',
 dotChannelsHelp='Affiche Drain de vie, Drain d’âme, Drain de mana et Calvaire comme timers tant qu’ils durent.',
 cardFallback='Repli public et démonstration',cardFallbackHelp='Utilisés par la démonstration et lorsque l’affichage natif est indisponible : barres proportionnelles, ticks prévus et avertissements d’expiration.',
 cardSize='Dimensions',cardEngine='Moteur d’affichage natif',cardEngineHelp='Testez l’affichage des DoT sur votre cible actuelle.',
 engineBound='%d ennemi(s) relié(s)',
 kitButtonsTitle='Boutons affichés',
 cardShardCount='Fragments d’âme dans vos sacs',cardCleaning='Nettoyage',
 cardPreview='Aperçu',cardTicks='Repères de ticks',cardChannelSpells='Sorts avec repères',cardChannelSpellsHelp='Décochez un sort pour masquer ses repères.',
 cardFrames='Cadres',cardFramesHelp='Échelle et opacité du cadre des ennemis et du compteur de fragments.',
 cardHelp='Aide',cardHelpBody='/fk ouvre cette fenêtre. /fk dots, kit, shards, nightfall ou spells ouvrent directement une page. /fk setup relance l’assistant.',
 grimDisplay='Options du grimoire',
 aboutLine='Felkit %s  ·  jeu %s (%s)  ·  licence MIT.',
 sideHint='/fk  ·  /fk setup',
 minimapHelp='Clic gauche : réglages. Clic droit : ennemis et DoT. Glisser pour déplacer.',
 nativeUnavailable='Affichage des DoT indisponible — /fk dots debug',
 dotTestTitle='Felkit · test (cible actuelle)',
 dotTestHelp='Vos affections sur la cible actuelle apparaissent au-dessus du centre de l’écran. Relancez la commande pour fermer.',
 dotTestFailed='Échec du test natif :',
 setupTitle='Felkit · premier lancement',
 setupStep_welcome='Bienvenue',setupStep_features='Modules',setupStep_tune='Réglages rapides',setupStep_done='Récapitulatif',
 setupWelcomeTitle='Bienvenue dans Felkit',
 setupWelcomeBody='Des outils de démoniste pour Forever. Choisissez ce que vous voulez en une minute ; vous pourrez changer plus tard.',
 setupPointOne='Choisissez vos modules',setupPointOneHelp='Gardez seulement l’utile : DoT, kit d’actions, fragments, Crépuscule…',
 setupPointTwo='Réglez l’essentiel',setupPointTwoHelp='Disposition des DoT, maximum de fragments, son de l’alerte et taille des cadres.',
 setupPointThree='Ajustez à tout moment',setupPointThreeHelp='Tapez /fk ou cliquez sur le bouton de la minicarte pour tous les réglages.',
 setupFeaturesIntro='Activez les fonctionnalités souhaitées ; vous pourrez changer plus tard.',
 setupFeature_enemies='Barres de DoT sur chaque ennemi engagé, dessinées par le client du jeu, avec vie et cible mise en évidence.',
 setupFeature_kit='Boutons sécurisés autour du compteur : pierres, démons, malédictions, armures, invocations.',
 setupFeature_shards='Compteur de fragments avec maximum à conserver et nettoyage automatique facultatif.',
 setupFeature_nightfall='Lames violettes et son renforcé au proc de Transe de l’ombre.',
 setupFeature_channels='Ticks prévisionnels sur la barre de canalisation (drains, Pluie de feu, Flammes infernales).',
 setupFeature_grimoire='Catalogue de sorts, fiches détaillées et infobulles enrichies avec les calculs.',
 setupTuneDots='L’apparence de vos DoT sur chaque carte d’ennemi.',
 setupTuneShards='Les fragments au-delà de ce maximum peuvent être supprimés.',
 setupAutoHelp='Vos touches, sorts et clics dans le monde retirent le surplus, en combat aussi.',
 setupTuneNightfall='Comment le proc de Transe de l’ombre est annoncé.',
 setupTuneInterface='Interface',
 setupDoneTitle='C’est prêt !',setupDoneBody='Votre configuration. Terminez pour l’appliquer ; vous pourrez la modifier dans les réglages.',
 setupTip='Astuce : /fk ouvre les réglages · /fk demo montre un aperçu de 10 secondes · /fk setup relance cet assistant.',
 setupBack='Retour',setupSkip='Passer — garder les réglages',setupNext='Suivant',setupStart='Commencer',setupFinish='Terminer',
 setupFinishOpen='Terminer et ouvrir les réglages',
 setupDone='Configuration enregistrée. Tapez /fk pour l’ajuster à tout moment.',
 setupSkipped='Assistant fermé : réglages conservés. /fk setup pour le relancer.',
 enemiesCombatOnly='Uniquement les ennemis en combat',
 dotConfirmedHelp='Affichage de secours uniquement : désactivé, autorise des timers estimés pouvant inclure des sorts ratés.',
 enemiesEngagedOnly='Afficher seulement les ennemis en combat avec moi ou mon groupe',
 enemiesEngagedOnlyHelp='Désactivé : affiche aussi les ennemis inactifs à portée. Utilisez le bouton ci-dessous si les barres de nom n’apparaissent qu’en combat.',
 platesShowAll='Toujours afficher les barres de nom ennemies',platesShowAllDone='Les barres de nom ennemies sont désormais toujours affichées.',
 platesState='Barres de nom ennemies de WoW : %s · toujours affichées : %s',
 dotDurationMode='Longueur des barres',dotDurationMode1='Largeur identique',dotDurationMode2='Proportionnelle à la durée',
 cardWhoHelp='Les ennemis viennent des barres de nom (activez les barres de nom ennemies en jeu).',
 cardPreviewBars='Barres de test',cardPreviewBarsHelp='Affiche trois ennemis de test avec des DoT en boucle (masqués en combat ou à la fermeture).',
 previewToggle='Afficher les barres de test',previewTitle='Aperçu — barres de test',
 previewEnemy1='Mannequin d’entraînement',previewEnemy2='Tisseur d’ombre',previewEnemy3='Bandit défias',
 dotTicksNative='Afficher les ticks sur les barres',
 dotTicksNativeHelp='Un repère pour chaque tick du sort. Les DoT sont alors regroupés par cadence de ticks (tri par expiration dans chaque groupe). Disposition Barres uniquement.',
 dotSlots='Effets affichés au maximum par ennemi',
 cardDotLayoutHelp='Chaque carte d’ennemi s’agrandit et se réduit selon ses DoT. Le client du jeu les trie par expiration et retire ceux qui expirent.',
 enemyHeader='Afficher l’en-tête du cadre',
 enemyHeaderHelp='Bandeau de titre au-dessus des cartes. Masqué, il ne s’affiche que si le cadre est déverrouillé.',
 cardSizeHelp='La hauteur des cartes suit le nombre de DoT.',
 cardFallbackHelp='Affichage de secours utilisé quand l’affichage principal est indisponible.',
 nightfallIntro='Proc Transe de l’ombre : deux barres violettes qui se vident avec le proc, et un son renforcé.',
 nightfallVisualHelp='Deux barres violettes verticales se vident à mesure que le proc s’écoule : dégradé, cœur lumineux, halo et étincelle en tête. Éclat à l’apparition ; la pulsation fait respirer le halo. Clics traversants. Aperçu de 5 secondes.',
 pulse='Halo pulsé (respiration)',
 cardTicksStyle='Ticks',tickColor='Couleur des ticks',tickColor1='Blanc',tickColor2='Doré',tickColor3='Noir',tickColor4='Violet',
 tickAlpha='Opacité des ticks',tickWidth='Épaisseur des ticks',
 cardWarning='Avertissement d’expiration',
 cardWarningHelp='Dans les dernières secondes, la fin de la barre passe du violet au rouge ; la pulsation la fait battre.',
 dotTicksNativeHelp='Un repère par tick, avec un éclair à chaque passage de la barre (disposition Barres uniquement).',
 cardDotLayoutHelp='Proportionnelle : la longueur de la barre suit la durée totale du sort.',
 mtTitle="DoT multi-cibles (lecture seule)",mtNone="Aucune cible engagée ou sous DoT",mtCountOne="%d cible engagée ou sous DoT",mtCount="%d cibles engagées ou sous DoT",mtLastSeen="DoT %s (vue en dernier)",mtCardWindow="Fenêtre multi-cibles",mtCardWindowHelp="Jusqu’à 16 ennemis avec vos DoT. Hors combat : glissez le titre pour déplacer, le coin pour redimensionner.",mtHideOOC="Masquer hors combat",mtAlpha="Opacité de la fenêtre",mtResetPos="Réinitialiser la position",mtResetSize="Réinitialiser la taille",mtCardDisplay="Affichage",mtDamageHelp="Le trait fin sur la barre de vie estime les dégâts restants de vos DoT : ambre Corruption, violet Fléau, turquoise Siphon de vie, rouge Immolation.",mtMillis="Dixièmes de seconde sous 10 s",mtExecute="Repère à 20 % de vie",mtCardEffects="Effets suivis",mtCardEffectsHelp="Une colonne par famille, seulement pour les sorts connus. Les changements s’appliquent hors combat.",mtBanes="Fléaux",mtCurses="Malédictions",mtDrains="Drains",mtCredit="Fenêtre adaptée de Warlock HUD (licence Apache 2.0).",
}
en.sideGroup_combat='Combat'; fr.sideGroup_combat='Combat'
en.sideGroup_tools='Tools'; fr.sideGroup_tools='Utilitaires'
en.sideGroup_system='System'; fr.sideGroup_system='Système'
en.cardOrder='Order and markers'; fr.cardOrder='Ordre et repères'
en.cardOrderHelp='How enemy cards are sorted and which markers follow the name.'
fr.cardOrderHelp='Tri des cartes ennemies et repères affichés après le nom.'
en.previewHeaderOff='Test bars: off'; fr.previewHeaderOff='Barres de test : non'
en.previewHeaderOn='Test bars: on'; fr.previewHeaderOn='Barres de test : oui'
en.cardAbout='About'; fr.cardAbout='À propos'
en.setupStep_language='Language'; fr.setupStep_language='Langue'
en.setupLanguageTitle='Choose your language'; fr.setupLanguageTitle='Choisis ta langue'
en.setupLanguageBody='The assistant switches now; the rest follows after a reload, offered at the end.'
fr.setupLanguageBody='L’assistant change tout de suite ; le reste suivra après un rechargement, proposé à la fin.'
en.languageAuto='Game language'; fr.languageAuto='Langue du jeu'
en.languageAutoHelp='Follows the game client: %s.'; fr.languageAutoHelp='Suit le client du jeu : %s.'
en.cardLanguage='Language'; fr.cardLanguage='Langue'
en.cardLanguageHelp='Language of every add-on text. Spell and enemy names stay in the game language.'
fr.cardLanguageHelp='Langue de tous les textes de l’addon. Les noms de sorts et d’ennemis restent dans la langue du jeu.'
en.languageReload='Reload now'; fr.languageReload='Recharger maintenant'
en.languageReloadHint='Reload the interface to apply the new language everywhere.'
fr.languageReloadHint='Rechargez l’interface pour appliquer la nouvelle langue partout.'
en.lang_en='English'; fr.lang_en='Anglais'
en.lang_fr='French'; fr.lang_fr='Français'
en.lang_es='Spanish'; fr.lang_es='Espagnol'
en.lang_pt='Portuguese'; fr.lang_pt='Portugais'
en.lang_de='German'; fr.lang_de='Allemand'
en.lang_it='Italian'; fr.lang_it='Italien'
en.lang_zh='Chinese (simplified)'; fr.lang_zh='Chinois (simplifié)'
en.lang_ru='Russian'; fr.lang_ru='Russe'
en.mtEnemyPresentation="Enemy and health style"
en.mtDotPresentation="DoT presentation"
en.mtIcons="Warlock HUD icons"
en.mtPresentationPending="Display change waiting for combat to end. Tracking continues."
en.mtPresentationHelp="Styles are independent. Existing targets and effects are retained."
en.mtBarHelp="One reserved line per effect. Equal: fixed tracks, native remaining fraction. Proportional: periodic profiles on a common 30-second scale; ? means no comparable profile. Names and timers keep their own columns. Ticks are forecasts. Off-screen estimates have no observed timer."
en.mtForecastTicks="Predicted tick markers"
en.mtGhostTimers="Last seen · duration unknown."
en.mtScaleUnknown="?"
en.mtBarsUnavailable="DoT bars unavailable; previous display kept."
fr.mtEnemyPresentation="Style de l’ennemi et de sa vie"
fr.mtDotPresentation="Présentation des DoT"
fr.mtIcons="Icônes Warlock HUD"
fr.mtPresentationPending="Changement d’affichage en attente de la fin du combat. Le suivi continue."
fr.mtPresentationHelp="Les styles sont indépendants. Les cibles et leurs effets sont conservés."
fr.mtBarHelp="Une ligne réservée par effet. Identique : pistes fixes, fraction restante native. Proportionnelle : profils périodiques sur une échelle commune de 30 s ; ? sans profil comparable. Noms et décomptes ont leurs colonnes. Ticks prévisionnels. Hors champ : estimations sans timer observé."
fr.mtForecastTicks="Repères de ticks prévisionnels"
fr.mtGhostTimers="Vu en dernier · durée inconnue."
fr.mtScaleUnknown="?"
fr.mtBarsUnavailable="Barres des DoT indisponibles ; affichage précédent conservé."
en.mtSizingHelp="The window grows to fit the health width and icon columns. Resize the window with its grip; scale changes its screen size. Bar height changes the fill; names reserve two lines independently."
en.mtDependenciesHelp="All-in-One health controls are hidden in HUD style. Tenths apply to icons; ticks and warnings apply to bars. Disabled options retain their preferences. Utility effects without a periodic profile have no predicted ticks or warning zone. Backgrounds affect All-in-One panels and DoT bar tracks; the HUD header keeps its native style."
en.mtHealthHelp="Health text, size, name placement and the 20% mark need health enabled. Without health, the enemy name stays visible. Backgrounds and borders also apply to Clean lines."
fr.mtSizingHelp="La fenêtre s’élargit pour contenir la vie et les colonnes d’icônes. Redimensionnez-la avec sa poignée ; l’échelle change sa taille à l’écran. La hauteur règle le remplissage ; les noms réservent deux lignes indépendantes."
fr.mtDependenciesHelp="Les réglages de vie All-in-One sont masqués en style HUD. Les dixièmes concernent les icônes ; ticks et avertissements concernent les barres. Les options désactivées gardent leurs préférences. Sans profil périodique, aucun tick ni zone prévisionnelle. Les fonds concernent les panneaux All-in-One et les pistes DoT ; l’en-tête HUD garde son style natif."
fr.mtHealthHelp="Le texte, les dimensions, le nom séparé et le repère à 20 % nécessitent la vie activée. Sans vie, le nom reste visible. Fonds et bordures s’appliquent aussi aux lignes épurées."
en.mtEffectHelp="Available once a spell in this family is known (Brand requires its talent). The preference is retained while unavailable."
fr.mtEffectHelp="Disponible quand un sort de cette famille est connu (la Marque nécessite son talent). La préférence reste conservée si indisponible."
en.mtPreviewHelp="Preview these settings on three test enemies (stops in combat or when closing settings)."
fr.mtPreviewHelp="Prévisualisez ces réglages sur trois ennemis de test (s’arrête en combat ou à la fermeture des réglages)."
en.mtPreviewStatus="TEST · 3 simulated enemies"
fr.mtPreviewStatus="TEST · 3 ennemis simulés"
en.mtPreviewEnemy="Test enemy %d"
fr.mtPreviewEnemy="Ennemi de test %d"
en.mtCommonScale="DoTs · common scale 0–%d s"
fr.mtCommonScale="DoT · échelle commune 0–%d s"
en.mtEqualTracks="DoTs · equal tracks, each effect on its own duration"
fr.mtEqualTracks="DoT · pistes identiques, durée propre à chaque effet"
en.mtAlpha="Background opacity"
fr.mtAlpha="Opacité des fonds"
en.mtSizingHelp="Resize the window with its grip. Health width is exact; the window grows to fit portraits and effects. Cards reserve generous blocks, Compact uses dense rows, Clean lines uses a single separator."
fr.mtSizingHelp="Redimensionnez la fenêtre par sa poignée. La largeur de vie est exacte ; la fenêtre s’élargit pour le portrait et les effets. Cartes : blocs espacés. Compact : lignes denses. Lignes épurées : un seul séparateur."
en.mtDependenciesHelp="Backgrounds controls the entire window, panels and empty bar tracks. Opacity affects only those backgrounds: 100% is opaque; portraits, spell icons, names and health/DoT fills stay clear. Tenths apply to icons; ticks and warnings apply to bars."
fr.mtDependenciesHelp="Les fonds concernent toute la fenêtre, les panneaux et les pistes vides des barres. L’opacité ne touche que ces fonds : 100 % est opaque ; portraits, icônes, noms et remplissages vie/DoT restent lisibles. Dixièmes : icônes. Ticks et alertes : barres."
en.mtBarHelp="Names and times sit above each bar. Equal: full tracks compare the remaining fraction of each effect. Proportional: catalogue durations share the displayed time scale; unknown profiles show ?. Family colours, predicted ticks and expiry zones stay separate from the labels."
fr.mtBarHelp="Noms et temps sont au-dessus de chaque barre. Identique : pistes complètes pour comparer la fraction restante de chaque effet. Proportionnelle : durées du catalogue sur l’échelle affichée ; ? sans profil connu. Couleurs par famille, ticks prévisionnels et zones d’expiration séparés des libellés."
-- 0.6.18: proc sound/style choices, clearer counter and channel ticks.
en.compact="Show the shard counter"
en.compactHelp="Shard icon with your shard count. Always shown while the action kit is on (it opens the kit)."
en.nav_channels="Channel ticks"
en.cardChannelSpellsHelp="One switch per spell, all ranks included."
en.homeIntro="Turn modules on here; click a module to set it up."
en.procSoundHelp="Nightfall is the original proc sound, amplified; its volume is set below. The other ten are game sounds at master volume. Clicking a sound plays it."
en.procStyleTitle="Style"
en.procStyleHelp="Two bars around your character that drain with the proc. Pick a style to preview it."
en.procStyle_flame="Void flame"
en.procStyle_runes="Runes"
en.procStyle_bolt="Lightning"
en.procStyle_crystal="Soul crystal"
en.procStyle_blades="Blades"
en.procSound0="Nightfall"
en.procSound1="Raid warning"
en.procSound2="Ready check"
en.procSound3="Alarm"
en.procSound4="Soft alarm"
en.procSound5="Level up"
en.procSound6="Whisper"
en.procSound7="Map ping"
en.procSound8="Battleground"
en.procSound9="Battle.net"
en.procSound10="Auction"
fr.compact="Afficher le compteur de fragments"
fr.compactHelp="Icône de fragment avec votre nombre de fragments. Toujours affichée si la barre de boutons est active (elle l’ouvre)."
fr.nav_channels="Ticks de canalisation"
fr.cardChannelSpellsHelp="Une case par sort, tous rangs compris."
fr.homeIntro="Activez les modules ici ; cliquez sur un module pour le régler."
fr.procSoundHelp="Crépuscule est le son d’origine du proc, amplifié ; son volume se règle ci-dessous. Les dix autres sont des sons du jeu, au volume principal. Cliquer un son le fait écouter."
fr.procStyleTitle="Style"
fr.procStyleHelp="Deux barres autour du personnage qui se vident avec le proc. Choisissez un style pour l’aperçu."
fr.procStyle_flame="Flammes du Vide"
fr.procStyle_runes="Runes"
fr.procStyle_bolt="Éclair"
fr.procStyle_crystal="Cristal d’âme"
fr.procStyle_blades="Lames"
fr.procSound0="Crépuscule"
fr.procSound1="Alerte raid"
fr.procSound2="Appel prêt"
fr.procSound3="Réveil"
fr.procSound4="Réveil doux"
fr.procSound5="Niveau"
fr.procSound6="Chuchotement"
fr.procSound7="Carte"
fr.procSound8="Champ de bataille"
fr.procSound9="Battle.net"
fr.procSound10="Ventes"
-- 0.6.19: soul bag deletion, tick colour/animation, channel guard, sound and style tiles.
en.pruneSoulBag="Also delete in soul bags"
en.pruneSoulBagHelp="On: soul bags are cleaned too, after regular bags."
en.procSoundHelp="Nightfall is the original proc sound, amplified; its volume is set below. The others are game sounds (interface and warlock spells) at master volume. Clicking a tile plays it."
en.procSnd_original="Nightfall"
en.procSndOriginalSub="Original proc, amplified"
en.procSndSpell="Warlock spell"
en.procSndGame="Interface"
en.procSnd_raid="Raid warning"
en.procSnd_ready="Ready check"
en.procSnd_alarm="Alarm"
en.procSnd_softAlarm="Soft alarm"
en.procSnd_level="Level up"
en.procSnd_bg="Battleground"
en.procSnd_bnet="Battle.net"
en.procSnd_auction="Auction house"
en.procSnd_murloc="Murloc"
en.procSnd_spell="Spell"
en.procStyle_vortex="Soul vortex"
en.procStyle_felfire="Fel fire"
en.procStyle_smoke="Shadow smoke"
en.procStyle_embers="Soul embers"
en.channelTickColor="Tick mark colour"
en.tickColor_1="Gold"
en.tickColor_2="White"
en.tickColor_3="Violet"
en.tickColor_4="Green"
en.tickColor_5="Red"
en.tickColor_6="Cyan"
en.tickAnimate="Animate passing ticks"
en.tickAnimateHelp="When a tick passes, its mark flares and fades."
en.guardTitle="Channel protection"
en.guardHelp="Creates per-character macros “AIO …” that ignore a press while a channel is running, so it is never restarted by accident. Put them on your bars in place of the spells. Turning it off deletes these macros."
en.guardToggle="Protect channelled spells"
en.guardDrag="Click a spell, then click an action bar slot to place its macro."
en.guardFull="Macro limit reached: free a character macro slot for channel protection."
fr.pruneSoulBag="Supprimer aussi dans les sacs d’âme"
fr.pruneSoulBagHelp="Activé : les sacs d’âme sont aussi nettoyés, après les sacs normaux."
fr.procSoundHelp="Crépuscule est le son d’origine du proc, amplifié ; son volume se règle ci-dessous. Les autres sont des sons du jeu (interface et sorts de démoniste), au volume principal. Cliquer une vignette la fait écouter."
fr.procSnd_original="Crépuscule"
fr.procSndOriginalSub="Proc d’origine, amplifié"
fr.procSndSpell="Sort de démoniste"
fr.procSndGame="Interface"
fr.procSnd_raid="Alerte de raid"
fr.procSnd_ready="Appel prêt"
fr.procSnd_alarm="Réveil"
fr.procSnd_softAlarm="Réveil doux"
fr.procSnd_level="Niveau gagné"
fr.procSnd_bg="Champ de bataille"
fr.procSnd_bnet="Battle.net"
fr.procSnd_auction="Hôtel des ventes"
fr.procSnd_murloc="Murloc"
fr.procSnd_spell="Sort"
fr.procStyle_vortex="Vortex d’âmes"
fr.procStyle_felfire="Gangrefeu"
fr.procStyle_smoke="Fumée d’ombre"
fr.procStyle_embers="Braises d’âme"
fr.channelTickColor="Couleur des repères"
fr.tickColor_1="Or"
fr.tickColor_2="Blanc"
fr.tickColor_3="Violet"
fr.tickColor_4="Vert"
fr.tickColor_5="Rouge"
fr.tickColor_6="Cyan"
fr.tickAnimate="Animer le passage des ticks"
fr.tickAnimateHelp="Quand un tick passe, son repère s’illumine puis s’efface."
fr.guardTitle="Protection des canalisations"
fr.guardHelp="Crée des macros de personnage « AIO … » qui ignorent un appui pendant une canalisation : elle n’est jamais relancée par erreur. Placez-les sur vos barres à la place des sorts. Désactiver supprime ces macros."
fr.guardToggle="Protéger les sorts canalisés"
fr.guardDrag="Cliquez un sort, puis une case de barre d’action pour y poser sa macro."
fr.guardFull="Limite de macros atteinte : libérez une macro de personnage pour la protection des canalisations."
-- 0.6.20: original sounds, black tick marks, grimoire switch covers the cards.
en.procSnd_crystal="Crystal ping"
en.procSnd_sweep="Rising sweep"
en.procSnd_drop="Void drop"
en.procSnd_bell="Deep bell"
en.procSnd_duo="Double beep"
en.procSnd_arpeggio="Arpeggio"
en.procSnd_gong="Gong"
en.procSnd_shimmer="Shimmer"
en.procSnd_heartbeat="Heartbeat"
en.procSnd_whoosh="Whoosh"
en.procSnd_kalimba="Kalimba"
en.procSnd_horn="Dark horn"
en.procSnd_zap="Zap"
en.procSndCustom="Original sound"
en.tickColor_7="Black"
en.grimDisabled="Grimoire off: catalogue, spell details and tooltips are off."
en.procSoundHelp="Pick the sound played on a proc; click a tile to hear it."
fr.procSnd_crystal="Cristal"
fr.procSnd_sweep="Montée"
fr.procSnd_drop="Chute du Vide"
fr.procSnd_bell="Cloche grave"
fr.procSnd_duo="Double bip"
fr.procSnd_arpeggio="Arpège"
fr.procSnd_gong="Gong"
fr.procSnd_shimmer="Scintillement"
fr.procSnd_heartbeat="Battement de cœur"
fr.procSnd_whoosh="Souffle"
fr.procSnd_kalimba="Kalimba"
fr.procSnd_horn="Cor sombre"
fr.procSnd_zap="Décharge"
fr.procSndCustom="Son original"
fr.tickColor_7="Noir"
fr.grimDisabled="Grimoire désactivé : catalogue, fiches et infobulles désactivés."
fr.procSoundHelp="Choisissez le son joué lors d’un proc ; cliquez sur une vignette pour l’écouter."
-- 0.7.0: DoT table redesign and Does It Die.
en.mtCardDots="DoT display"
en.mtDotsHelp="Your DoTs on each enemy, soonest to expire first."
en.mtStyleEqual="Equal width"
en.mtStyleHudHelp="Icons with their countdown, to the right of the health bar."
en.mtStyleEqualHelp="One full-width bar per DoT, under the health bar."
en.mtStyleKit="Kit bars"
en.mtKitColors="A colour per DoT"
en.mtKitColorsHelp="Off: every kit bar is fel purple. Takes effect on enemies you dot after a /reload."
en.mtKitRings="Gold rings round the icons"
en.mtKitEdges="Gold edges round the bars"
en.tab_kit_reminders="Reminders"
en.kitOrbTitle="Orb"
en.kitOrbHelp="The shard orb, the six slots on its arc, the small talent buttons under it and the row under the divider."
en.kitOrbSize="Orb size"
en.kitSmallScale="Small buttons (Sacrifice, Soul Link, Fel Domination)"
en.kitOrbArc="Arc spread"
en.kitOrbGap="Gap between orb and slots"
en.kitRowGap="Gap between bottom-row slots"
en.kitDivider="Fel divider above the bottom row"
en.kitOrbArt="Centre of the orb"
en.kitArt_arcane="Arcane crystal"
en.kitOrbArtFlip="Mirror the crystal (tip leans right)"
en.kitArt_fel="Fel crystal"
en.kitRingColor="Button borders"
en.kitOrbRingColor="Orb border"
en.kitAlertColor="Alert glow colour"
en.color_purple="Purple"
en.color_gold="Gold"
en.color_silver="Silver"
en.color_fel="Fel"
en.color_cyan="Cyan"
en.color_orange="Orange"
en.color_green="Green"
en.color_red="Red"
en.color_pink="Pink"
en.color_white="White"
en.kitArt_shadow="Shadow crystal"
en.kitArt_item="Soul Shard icon"
en.kitArt_class="Class icon"
en.kitArt_none="Plain orb"
en.kitCountPos="Shard count"
en.kitCount_middle="Middle"
en.kitCount_corner="Corner"
en.kitCount_hidden="Hidden"
en.kitOrbGlow="Glow behind the orb"
en.kitRemindTitle="Reminder glows"
en.kitRemindHelp="A slot glows orange while something is missing."
en.kitRemind_soul="Soulstone: none out on anyone and it is off cooldown"
en.kitRemind_health="Healthstone: none in your bags"
en.kitRemind_armor="Armor: Demon Armor / Skin is off"
en.kitRemind_weapon="Weapon stone: your weapon has no Firestone or Spellstone"
en.kitRemind_link="Soul Link: your demon is out and Soul Link is off"
en.styleHelp="/fk style [hud | equal | kit]: switch the DoT look. Without a name, goes to the next one."
en.styleNow="DoT look: %s."
en.styleName_hud="Warlock HUD icons"
en.styleName_equal="Equal-width bars"
en.styleName_kit="Kit bars"
en.dotEngineTitle="DoT engine"
en.dotEngineHelp="Which engine draws your DoTs on enemies. Both are kept so you can compare them. Switching needs a reload."
en.dotEngineWindow="DoT window"
en.dotEngineWindowHelp="The multi-target window (from Warlock HUD): up to 16 enemies, icons, equal bars or kit bars."
en.dotEngineCards="Enemy cards"
en.dotEngineCardsHelp="The classic enemy cards: bars or icons, equal or proportional widths, tick marks, Cards / Compact / Clean styles."
en.dotEngineReload="Reload to switch the DoT engine (/reload)."
en.mtStyleKitHelp="Round icons in gold rings over gold-edged bars, one colour per DoT, always in the same order: curse, bane, Corruption, Immolate, Siphon Life, drains."
en.mtDotsSorted="Sorted by the game: soonest expiry first."
en.mtCardHealth="Health bar"
en.mtHealthHelp2="A yellow line on the left marks the enemy you target."
en.mtShowName="Enemy name"
en.mtShowPortrait="Enemy icon in front"
en.mtCardDID="Does It Die"
en.mtDIDHelp="Striped zone: damage your DoTs will still deal. A skull means your DoTs will kill it."
en.mtDidBars="On the DoT table health bars"
en.mtDidPlates="On nameplates"
en.mtDidPlatesHelp="Same zone and skull on enemy nameplates (enemy nameplates must be on)."
en.mtDidExternal="Does It Die is installed and already draws on nameplates; this option is paused."
en.mtTransparent="Transparent frame"
en.mtHeader="Header (title and count)"
en.mtHeaderHelp="Without the header, the window can't be moved or resized."
en.mtEffectsHelp2="Shown only for spells you know. Changes apply out of combat."
en.mtCreditDID="Health bar zone from Does It Die by Joe Greive (MIT License)."
fr.mtCardDots="Affichage des DoT"
fr.mtDotsHelp="Vos DoT sur chaque ennemi, du plus proche de la fin au plus lointain."
fr.mtStyleEqual="Largeur identique"
fr.mtStyleHudHelp="Icônes avec leur décompte, à droite de la barre de vie."
fr.mtStyleEqualHelp="Une barre pleine largeur par DoT, sous la barre de vie."
fr.mtDotsSorted="Tri fait par le jeu : la première expiration en premier."
fr.mtCardHealth="Barre de vie"
fr.mtHealthHelp2="Un trait jaune à gauche marque le mob ciblé."
fr.mtShowName="Nom du mob"
fr.mtShowPortrait="Icône du mob devant"
fr.mtCardDID="Does It Die"
fr.mtDIDHelp="Zone hachurée : dégâts que vos DoT vont encore infliger. Une tête de mort signifie que vos DoT vont le tuer."
fr.mtDidBars="Sur les barres de vie du tableau"
fr.mtDidPlates="Sur les barres de nom (nameplates)"
fr.mtDidPlatesHelp="Même zone et tête de mort sur les barres de nom ennemies (elles doivent être activées)."
fr.mtDidExternal="Does It Die est installé et dessine déjà sur les barres de nom ; cette option est en pause."
fr.mtTransparent="Cadre transparent"
fr.mtHeader="En-tête (titre et décompte)"
fr.mtHeaderHelp="Sans en-tête, la fenêtre ne peut être ni déplacée ni redimensionnée."
fr.mtEffectsHelp2="Affichés seulement pour les sorts connus. Les changements s’appliquent hors combat."
fr.mtCreditDID="Zone de vie issue de Does It Die par Joe Greive (licence MIT)."
-- 0.7.1: tabs, compact rows, click targeting, Does It Die look, credits, Nightfall layout.
en.tab_enemies_did="Does It Die"
en.mtSpellsHelp="Spells you know. Newly learned spells appear after /reload."
en.mtSpellsNone="No tracked spell known yet."
en.mtBarHeight="Bar height"
en.mtSpacing="Space between enemies"
en.mtDidLook="Zone look"
en.mtDidLookHelp="Shared by the table rows and the nameplates."
en.mtDidDotColors="DoT colours"
en.didDotColors_school="By school"
en.didDotColors_each="One per DoT"
en.didDotColors_single="Single colour"
en.mtDidFill="Fill"
en.didFill_stripes="Stripes"
en.didFill_flat="Flat"
en.didFill_smooth="Health bar texture"
en.didFill_none="None"
en.mtDidColor="Fill colour"
en.mtDidOpacity="Fill opacity"
en.mtDidOutline="Outline"
en.didOutline_dashed="Dashed"
en.didOutline_solid="Solid"
en.didOutline_none="None"
en.mtDidOutlineColor="Outline colour"
en.mtDidOutlineSize="Outline thickness"
en.mtDidIcon="Kill icon"
en.didIcon_skull="Skull"
en.didIcon_cross="Red cross"
en.didIcon_check="Green check"
en.didIcon_boss="Boss skull"
en.mtDidPlateIconSize="Nameplate icon size"
en.mtDidPlateIconPos="Nameplate icon position"
en.didPos_left="Left"
en.didPos_right="Right"
en.didPos_above="Above"
en.mtClick="Target by clicking the health bar"
en.mtClickHelp="Click a row to target its enemy. With equal-width bars, clicks work only outside combat."
en.cardCredits="Inspirations"
en.creditsBody="Includes adapted code from Warlock HUD (multi-target DoT window, Apache License 2.0) and Does It Die by Joe Greive (DoT damage on health bars, MIT License)."
en.nightfallGap="Distance from the centre"
en.nightfallScale="Animation scale"
en.mtTableShown="DoT table shown"
en.mtTableShownHelp="Off: hides the DoT table; Does It Die stays on nameplates."
en.mtStyleEqualHelp="One full-width bar per DoT under the health bar."
en.mtSpellsWord="spells"
fr.tab_enemies_did="Does It Die"
fr.mtSpellsHelp="Les sorts que vous connaissez. Un nouveau sort apparaît après /reload."
fr.mtSpellsNone="Aucun sort suivi n’est encore connu."
fr.mtBarHeight="Hauteur des barres"
fr.mtSpacing="Espace entre les mobs"
fr.mtDidLook="Apparence de la zone"
fr.mtDidLookHelp="Commune aux lignes du tableau et aux barres de nom."
fr.mtDidDotColors="Couleurs des DoT"
fr.didDotColors_school="Par école"
fr.didDotColors_each="Une par DoT"
fr.didDotColors_single="Une seule couleur"
fr.mtDidFill="Remplissage"
fr.didFill_stripes="Hachures"
fr.didFill_flat="Uni"
fr.didFill_smooth="Texture de barre de vie"
fr.didFill_none="Aucun"
fr.mtDidColor="Couleur du remplissage"
fr.mtDidOpacity="Opacité du remplissage"
fr.mtDidOutline="Contour"
fr.didOutline_dashed="Pointillé"
fr.didOutline_solid="Plein"
fr.didOutline_none="Aucun"
fr.mtDidOutlineColor="Couleur du contour"
fr.mtDidOutlineSize="Épaisseur du contour"
fr.mtDidIcon="Icône de mort"
fr.didIcon_skull="Tête de mort"
fr.didIcon_cross="Croix rouge"
fr.didIcon_check="Coche verte"
fr.didIcon_boss="Crâne de boss"
fr.mtDidPlateIconSize="Taille de l’icône (nameplates)"
fr.mtDidPlateIconPos="Position de l’icône (nameplates)"
fr.didPos_left="À gauche"
fr.didPos_right="À droite"
fr.didPos_above="Au-dessus"
fr.mtClick="Cibler en cliquant sur la barre de vie"
fr.mtClickHelp="Cliquez sur une ligne pour cibler son ennemi. En largeur identique, le clic ne marche que hors combat."
fr.cardCredits="Inspirations"
fr.creditsBody="Inclut du code adapté de Warlock HUD (fenêtre des DoT multi-cibles, licence Apache 2.0) et de Does It Die de Joe Greive (dégâts des DoT sur les barres de vie, licence MIT)."
fr.nightfallGap="Écartement du centre"
fr.nightfallScale="Échelle de l’animation"
fr.mtTableShown="Tableau des DoT affiché"
fr.mtTableShownHelp="Désactivé : masque le tableau des DoT ; Does It Die reste sur les barres de nom."
fr.mtStyleEqualHelp="Une barre pleine largeur par DoT sous la barre de vie."
fr.mtSpellsWord="sorts"
-- 0.7.2: health colour and target styles.
en.mtHealthColor="Health bar colour"
en.healthColor_green="Green"
en.healthColor_red="Red"
en.healthColor_reaction="By reaction"
en.healthColorReactionHelp="Red: hostile. Yellow: neutral. Green: friendly."
en.mtCardSelect="Target"
en.mtSelectHelp="How your current target stands out."
en.selectStyle_line="Line on the left"
en.selectStyle_outline="Whole row framed"
en.selectStyle_fill="Lit background"
en.selectStyle_health="Health bar border"
en.mtSelectColor="Colour"
en.mtSelectSize="Thickness"
en.mtHealthHelp2="Height, name, icon, 20 % mark and colour of the health bars."
fr.mtHealthColor="Couleur de la barre de vie"
fr.healthColor_green="Verte"
fr.healthColor_red="Rouge"
fr.healthColor_reaction="Selon l’hostilité"
fr.healthColorReactionHelp="Rouge : hostile. Jaune : neutre. Vert : amical."
fr.mtCardSelect="Cible"
fr.mtSelectHelp="Comment votre cible actuelle se distingue."
fr.selectStyle_line="Trait à gauche"
fr.selectStyle_outline="Ligne entièrement encadrée"
fr.selectStyle_fill="Fond éclairci"
fr.selectStyle_health="Contour de la barre de vie"
fr.mtSelectColor="Couleur"
fr.mtSelectSize="Épaisseur"
fr.mtHealthHelp2="Hauteur, nom, icône, repère à 20 % et couleur des barres de vie."
en.mtInitFailed="The DoT table could not start:"
en.mtAuraBlocked="The game blocked a DoT update; report it with /fk diagnostics."
fr.mtInitFailed="Le tableau des DoT n’a pas pu démarrer :"
fr.mtAuraBlocked="Le jeu a bloqué une mise à jour des DoT ; signalez-le avec /fk diagnostics."
en.mtCardPlace="Position"
en.mtPlaceHelp="Unlock to drag the window, then lock it."
en.mtLocked="Lock window"
en.mtMoveHint="Drag to move"
fr.mtCardPlace="Position"
fr.mtPlaceHelp="Déverrouillez pour déplacer la fenêtre, puis verrouillez-la."
fr.mtLocked="Verrouiller la fenêtre"
fr.mtMoveHint="Glisser pour déplacer"
for k,v in pairs(en) do S.Locales.en[k]=v end
for k,v in pairs(fr) do S.Locales.fr[k]=v end
S.applyLocale()
