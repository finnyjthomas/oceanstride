# Ocean Stride — native iOS game

A portrait SwiftUI + SpriteKit ocean runner for iPhone and iPad (iOS 17+). Gameplay scenery and characters are drawn in code. The opening screen uses bundled original illustrated artwork, an illustrated title baked into the poster and a native Play button, sound toggle, best score, and a How to play sheet. Gameplay works offline without a player account. Optional rewarded level-skip ads use Google's Mobile Ads and consent SDKs and require a network connection; production ads are disabled until configured.

## Run

1. Open `OceanStride.xcodeproj` in Xcode 15 or newer.
2. Choose the **OceanStride** scheme and an iPhone simulator, then press **Run**.
3. For a physical iPhone, use the configured signing team and final identifier `com.finstergames.OceanStride`, or select your own team for a fork.

Full Xcode and its iOS SDK are required. The simulator build passes with Xcode 26.6, and the level rules check passes across 100 levels. The app was installed and launched on the iPhone 17 Pro / iOS 26.4 simulator, and its welcome screen was visually checked (see `Preview/welcome.png`). Automated UI access timed out, so interactive controls and full gameplay still need hands-on testing. The app icon is configured for Debug and Release builds. App Store signing and the hosted privacy policy are configured. Store metadata and physical-device acceptance testing remain.

## Play

- The explorer automatically runs forward. Swipe horizontally or use the arrow buttons to move between three lanes.
- Playfield touches are tracked independently, so a second finger can jump while another finger is held down. Noninteractive HUD labels pass taps through to the playfield. Jump and lane buttons dispatch directly on press, including quick taps; slight downward finger movement no longer discards a jump tap.
- Long-press **SHIELD BOOST** for half a second and keep holding to run 200% faster (3× normal speed) with protection from gaps, broken stones, barriers, and attacks. The first activation spends 100 jewels for five seconds of boost time. Release to stop the effect and save the remaining seconds; hold again to resume without another charge, even with no jewels left. A countdown and glowing shield show active time; the button shows saved time while released. Remaining time survives pauses, retries, level completion, returning to the menu, and app relaunch; New Game clears it. Once time runs out, release and hold again to buy another five seconds for 100 jewels. Spending uses current-attempt pickups first and persists any deduction from saved jewels. VoiceOver users double-tap to start or pause. Normal hazards resume immediately on release or expiry.
- Tap the playfield, swipe up, or press **JUMP** to jump. The on-screen jump and arrow buttons respond on touch-down. Swipes trigger during finger movement with a 12-point threshold. A 140 ms jump buffer accepts presses just before landing, and 150 ms of edge forgiveness helps late jumps. A small foot-width allowance on platform and broken-stone edges also helps with close landings. Supported displays request up to 120 fps. Jump before the pale edge of a platform to cross the water.
- Press jump again while airborne for a second boost from your current height. Two jumps are available before you must land; landing resets them.
- Jump over barriers and broken sections, or change lanes to avoid them.
- Collect spinning, bobbing mint jewels for one point each. Golden jewel clusters over barriers and holes are worth two or three jewels each and require jumping. Jewels have their own total; score is the total number of platforms reached across levels.
- Red marks show lanes targeted by enemy boats. Move away or jump over their cannonballs.
- Barriers and cannonballs cost one heart and grant a brief damage shield. Falling into water ends the run immediately.
- The final platform is a protected landing area with a checkered finish line and FINISH gate. Reach the line and land to complete the level.
- Original quiet background music and synthesized cues accompany footsteps, jumps, dodges, jewels, gunfire, hits, death, and completion. Use the speaker button or menu sound toggle to mute; audio respects the iPhone silent switch and pauses with the game.
- Medical packs first appear at level 11, then once every other level (13, 15, …). None appear in levels 1–10. Pick one up for +1 life, including above three; a green glow and healing chime mark the pickup.
- Each interior platform has usually one hazard per occupied lane, occasionally two. Platforms are longer to leave more maneuvering room. The mint-marked clear lane randomly changes between platforms, by at most one lane per jump. It stays free of barriers but can be targeted by enemy fire. Attacks leave an adjacent dodge lane open, away from gaps and hazards.
- There are 100 individually drawn barriers, one exclusive design per level, across ten themes: coral stones, harbor hurdles, blades, fire jets, wrecking balls, dragons, spikes, crushers, lightning, and ice. The title-screen field guide previews all 100 barriers and all 100 weapon/flight pairings without changing progress. Attack shapes, trajectories, warning durations, and jump-versus-dodge heights vary by level. Yellow warns before active red danger; mint surfaces are landable. See `Release/hazard-catalog.md` for all 100 signatures.
- From level 6, low ships cross selected gaps with a warning. Time your jump to clear both the water and the deck. The flat wooden decks with mint borders are safe moving platforms: land on them, ride briefly, and jump off. Landing restores both jumps.
- Each cleared level restores one heart if you have fewer than three; bonus lives are retained. Levels have 5, 7, 9, 11… platforms.
- Every level starts with a clear platform at least 50% longer than a standard platform, giving at least four seconds of running before the first gap, including on retries.
- Running speed is reduced a further 10% across all levels: levels 1–9 use 90% of the original speed curve, and levels 10 onward use 81%. Speed increases slightly each level after the adjustment at level 10; gaps shorten as needed to stay within 75% of a single jump's travel distance.
- Attack frequency decreases by 10% each level, compounded, with a maximum interval of 10 seconds so advanced levels still have regular attacks: 3.8 seconds at level 1, 4.22 at level 2, 9.81 at level 10, and 10 seconds from level 11 onward. Levels 91–100 override this with an attack every 3 seconds. The first attack waits at least five seconds or the level's interval, whichever is longer. Helicopters join from level 4. Attacks fire one shot at a time through level 70; simultaneous two-shot volleys begin at level 71.
- After a failure, retry the same level with at least three hearts (retaining bonus lives carried into that level). Points and jewels from completed levels are preserved; the failed attempt’s points and jewels reset to avoid duplicate rewards. The pause menu also restarts only the current level.
- Pause with the top-right button, then tap **Main menu** to return to the opening page. Main menu is also available after failing or clearing a level. Continue resumes at the start of the saved level with rewards from completed levels; after a victory it starts the next level. Switching away from the app pauses automatically. Your best platform score and current unlocked level are saved locally. Closing the app resumes at the start of the saved level; a cleared level unlocks the next one immediately. The opening screen offers New Game and, when a save exists, Continue from Level X. New Game asks before replacing the checkpoint, resets to level 1, and preserves the best score.

## Structure and checks

- `OceanStrideApp.swift`: SwiftUI interface and observable run state.
- `OpeningView.swift`: illustrated opening menu and instructions.
- `Assets.xcassets/OpeningArtwork.imageset`: bundled opening illustration, generated with the built-in image generation tool. The full prompt is saved in `Preview/opening-artwork-prompt.txt`; the verified iPhone screenshot is `Preview/opening-screen.png`.
- `Assets.xcassets/AppIcon.appiconset`: opaque 1024×1024 app icon, configured for iPhone, iPad, and the App Store. Created with the built-in image generation tool using the opening artwork as a style reference; the final prompt is in `Preview/app-icon-prompt.txt`.
- `OceanScene.swift`: perspective rendering, gestures, movement, collisions, boats, and pickups.
- `ProgressStore.swift`: atomic local level checkpoints, restored on launch.
- `RewardedAds.swift`: Google rewarded-ad lifecycle, consent update/forms, privacy choices, and exactly-once completion routing. `AdInfo.plist` contains ad configuration and SKAdNetwork identifiers. `PrivacyInfo.xcprivacy` declares the app's own UserDefaults usage; Google's SDKs also bundle privacy manifests.
- `GameAudio.swift`: generated music and effect tones, audio lifecycle, and persistent mute preference.
- `LevelPlan.swift`: deterministic platform layouts and difficulty progression.

Run the platform rules check on a Mac with Swift installed:

```sh
swiftc -module-cache-path /tmp/ocean-stride-module-cache OceanStride/LevelPlan.swift OceanStrideTests/LevelPlanChecks.swift -o /tmp/ocean-stride-checks
/tmp/ocean-stride-checks
```

Before release, playtest jump timing and touch controls on several screen sizes, test pause/resume during a jump, and verify level transitions, life loss, and best-score persistence on a device.


The titled poster is `OceanStride/Assets.xcassets/OpeningArtwork.imageset/opening-poster-titled.png`. Its edit prompt is in `Preview/titled-poster-prompt.txt`; the original untitled illustration is preserved as `Preview/original-opening-artwork.png`.

Check save/relaunch behavior with:

```sh
swiftc OceanStride/ProgressStore.swift OceanStrideTests/ProgressChecks.swift -o /tmp/ocean-progress-checks
/tmp/ocean-progress-checks
```

## Rewarded level-skip ads

Pause during a level (or use the Game Over screen) and choose **Watch ad → Skip level**. Completing the ad unlocks the next level without finishing the current one. Only the SDK's earned-reward callback authorizes the skip, and it is applied after the ad is dismissed. The next level starts paused until **Resume journey** is pressed. Already-earned platform score, jewels, and remaining boost time are retained; unvisited platforms award no extra points. The next level starts with at least three lives.

There are **two successful skips per local calendar day, per device**. The UI shows the remaining allowance. Usage and the next-level checkpoint are written atomically, so relaunching, retrying, and New Game do not reset the allowance. The next calendar day resets it; moving the device clock backward does not grant extra uses. This is a local limit, not a server-verified account limit.

Resume/Retry and Main menu remain available while loading. Leaving cancels the request; late, failed, cancelled, or duplicate callbacks cannot skip a different attempt or consume a daily use. If saving fails after earning the reward, **Apply earned level skip** retries saving without showing another ad. Offline/no-fill errors show a normal retry message. Ads never appear automatically in normal gameplay. There are no revive or jewel-for-ad rewards.

### Test ads now

Debug builds always request Google's rewarded test unit `ca-app-pub-3940256099942544/1712485313`. The configured sample app ID is `ca-app-pub-3940256099942544~1458002511`. Test ads do not generate revenue. Pause a normal level (or fail it) and select Watch ad. Test-level pickers and launch shortcuts have been removed from all builds.

The Google test ad was loaded in the iPhone 17 Pro simulator and displayed “Reward granted.” The failure-screen layout was visually checked. Full dismissal-to-skip interaction, consent choices in relevant regions, background/foreground transitions, and cancellation/offline behavior still need hands-on device testing. Automated checks cover the twice-daily limit, next-day reset, clock rollback, relaunch/New Game persistence, legacy saves, and rejection of cancelled, duplicate, and stale reward callbacks.

```sh
swiftc -module-cache-path /tmp/ocean-stride-module-cache OceanStride/LevelPlan.swift OceanStride/ProgressStore.swift OceanStrideTests/RewardedSkipChecks.swift -o /tmp/ocean-skip-checks
/tmp/ocean-skip-checks
```

### Enable revenue later

1. Sign in to [AdMob](https://admob.google.com/) with your Google account; create an account if you do not already have one. Add Ocean Stride as an iOS app, then create a **Rewarded** ad unit for the level-skip placement. Complete account/payment and app-readiness requirements shown by AdMob.
2. In Xcode target Build Settings, replace `OCEAN_ADMOB_APP_ID` with the app ID (contains `~`), and set `OCEAN_REWARDED_AD_UNIT_ID` to the rewarded unit ID (contains `/`). These IDs are configuration identifiers, not passwords.
3. Configure the applicable messages in AdMob's **Privacy & messaging** section. The app refreshes consent information each launch, presents required forms before loading an ad, checks `canRequestAds`, and offers required privacy choices through **Privacy & ads**. It requests non-personalized ads, disables publisher first-party ID, and does not request ATT authorization. This is configured as a general-audience app, not a child-directed app.
4. Complete `Release/privacy-policy-draft.txt` with the publisher/contact details and publish it at a public HTTPS URL. Set `OCEAN_PRIVACY_POLICY_URL` to that URL in **both Debug and Release** target build settings; **Privacy & ads** then displays **Ocean Stride privacy policy**. No placeholder URL is shipped. In App Store Connect, open Ocean Stride → App Privacy → Privacy Policy → Edit, enter the same URL in **Privacy Policy URL**, and save. This repository cannot update the store listing by itself. Verify the URL opens without signing in before submission. Update App Store privacy disclosures for the Google SDKs using [Google's disclosure guide](https://developers.google.com/admob/ios/privacy/data-disclosure); the in-app summary and Google's policy link do not replace the app's hosted policy.
5. Complete device testing with test ads first. Then set `OCEAN_LIVE_ADS_ENABLED = YES` in the **Release** configuration. Release currently defaults to `NO` and also rejects Google's sample IDs; it hides the ad button and makes no ad/consent requests until configured. Debug always uses test ad units even when production IDs are set.

Dependencies are pinned through Swift Package Manager: Google Mobile Ads 13.11.0 and UMP 3.1.0 in Package.resolved. Initial builds need network access to fetch them. SDK setup and reward handling follow [Google's quick start](https://developers.google.com/admob/ios/quick-start), [rewarded-ad guide](https://developers.google.com/admob/ios/rewarded), and [consent guide](https://developers.google.com/admob/ios/privacy). The 50 SKAdNetwork IDs were taken from the official quick-start example on 2026-10-27.

## Published privacy policy

The public policy is https://finstergames-ocean-stride-privacy.silky-dove-6550.chatgpt.site and is configured in both build configurations. Its source is `finstergames-privacy/dist/index.html`. Use this exact URL in App Store Connect → Ocean Stride → App Privacy → Privacy Policy URL. The App Store Connect field still needs to be saved in your account.
## Device archive and distribution

The final bundle identifier is `com.finstergames.OceanStride`. A signed Release arm64 device archive passed local signature verification on October 27, 2026. The App Store export retry succeeded with Apple Distribution signing for team AZYKC56A66; the exported IPA and App Store profile passed local verification. The IPA is `Release/Artifacts/AppStoreExport/OceanStride.ipa`. Nothing has been uploaded, and Apple server-side submission validation remains outstanding. See `Release/distribution-status.txt` for the exact results and retry steps. `Release/ExportOptions-AppStore.plist` configures a local App Store export without uploading. The archive and logs are preserved under ignored `Release/Artifacts/`.

Barrier tops: mint stone and hurdle decks can be landed on while descending and restore both jumps. Other hazard families are never landing surfaces. New Game randomizes the layout; saved seeds make retries and Continue reproduce it.

Run the randomized route suite with `swiftc -O OceanStride/LevelPlan.swift OceanStrideTests/HazardRouteChecks.swift -o /tmp/ocean-hazard-checks && /tmp/ocean-hazard-checks`. It verifies 6,400 complete level layouts and samples gap trajectories at 120 Hz. Physical-device playtesting remains required.

Attack scheduling check: `swiftc -module-cache-path /tmp/ocean-stride-module-cache -O OceanStride/LevelPlan.swift OceanStrideTests/AttackWindowChecks.swift -o /tmp/ocean-attack-checks && /tmp/ocean-attack-checks` verifies attack opportunities across all 100 levels, including attacks on the marked route.

Catalogue/geometry checks and shared-art contact sheets: `swiftc -module-cache-path /tmp/ocean-stride-module-cache -O OceanStride/LevelPlan.swift OceanStrideTests/EncounterCatalogChecks.swift -o /tmp/ocean-catalog-checks && /tmp/ocean-catalog-checks Preview`. The optional Preview argument exports the same vector paths used in gameplay to two PNG contact sheets.
