# Ocean Stride — level encounters (build 7)

Each of levels 1–100 owns one individually drawn barrier silhouette and one weapon/flight pairing. Every barrier spawned on a level uses that level's design, including the first interior platform. Generic substitute barriers have been removed. Levels above 100 repeat this catalogue.

The 100 attacks combine ten weapon bodies with ten flight behaviors and structural flight fittings. Weapon height determines jump-versus-dodge behavior; flight curves change the approach and arrival timing. They are 100 distinct combinations, not 100 independent physics engines. Shots originate at the boat or helicopter muzzle and end at the marked lane. Only impact deals damage; the visible flight trail is not a cross-lane collision beam.

## Preview and mechanics

- Open **100-level field guide** from the title screen, then tap any level. This only previews encounters and never unlocks levels, changes progress, or grants jewels.
- All 100 barrier drawings are authored separately in `EncounterArtwork.barrier`. The gameplay renderer, guide, and QA contact sheets use those same paths. Geometry tests reject duplicated barrier/projectile artwork.
- Levels 1–20 have flat mint landing decks on distinct structures; their height varies. Levels 21–100 introduce mechanisms with ten activation sequences and vertical movement profiles. Collision bands and gameplay drawing share their live height bounds. Yellow warns before each active phase.
- The attack catalogue combines direct, lobbed, skimming, corkscrew, zigzag, returning, stuttering, orbiting, diving, and surging approaches with cannonballs, harpoons, razors, fireballs, anchors, dragon bolts, spines, meteors, lightning, and ice lances. All approaches end at the telegraphed lane, with at least 1.45 seconds of flight warning.
- One randomly shifting adjacent lane stays barrier-free. Occupied lanes have one barrier 75% of the time and two 25% of the time. Platforms retain the extra maneuvering room. First/finish platforms stay clear.
- Impacts require nearby dodge space and stay away from ocean gaps. Volleys have one shot through level 70; levels 71+ may have two, with the same arrival time and an untargeted escape lane. Boost timing changes trigger another impact-space check.
- Retry/Continue preserves the saved layout seed. Existing saves continue normally, with the new encounter designs.

## Validation

6,400 seeded level layouts, gap trajectories, exclusive level spawning, attack escape windows, 100 distinct barrier geometries, 100 distinct projectile geometries/names, ten nonidentical activation sequences and flight curves, finite/bounded art, and exact projectile endpoints are checked. A separate 100-level schedule simulation verifies attacks still occur and can target the marked lane. Physical-device playtesting remains necessary; modeled route checks do not prove every input sequence will succeed.

## Per-level catalogue

| Level | Theme | Barrier | Barrier behavior | Enemy attack |
| --- | --- | --- | --- | --- |
| 1 | Coral Ruins | Coral Step | Landable deck | Direct Cannon |
| 2 | Coral Ruins | Barnacle Block | Landable deck | Lobbed Cannon |
| 3 | Coral Ruins | Mossy Plinth | Landable deck | Skimming Cannon |
| 4 | Coral Ruins | Shell Pedestal | Landable deck | Corkscrew Cannon |
| 5 | Coral Ruins | Reef Slab | Landable deck | Zigzag Cannon |
| 6 | Coral Ruins | Tide Altar | Landable deck | Returning Cannon |
| 7 | Coral Ruins | Pearl Terrace | Landable deck | Stuttering Cannon |
| 8 | Coral Ruins | Sunken Pillar | Landable deck | Orbiting Cannon |
| 9 | Coral Ruins | Carved Monolith | Landable deck | Diving Cannon |
| 10 | Coral Ruins | Crownstone | Landable deck | Surging Cannon |
| 11 | Harbor Hurdles | Dock Rail | Landable deck | Direct Harpoon |
| 12 | Harbor Hurdles | Rope Hurdle | Landable deck | Lobbed Harpoon |
| 13 | Harbor Hurdles | Driftwood Fence | Landable deck | Skimming Harpoon |
| 14 | Harbor Hurdles | Cargo Beam | Landable deck | Corkscrew Harpoon |
| 15 | Harbor Hurdles | Copper Rail | Landable deck | Zigzag Harpoon |
| 16 | Harbor Hurdles | Buoy Hurdle | Landable deck | Returning Harpoon |
| 17 | Harbor Hurdles | Anchor Fence | Landable deck | Stuttering Harpoon |
| 18 | Harbor Hurdles | Harbor Vault | Landable deck | Orbiting Harpoon |
| 19 | Harbor Hurdles | Captain's Rail | Landable deck | Diving Harpoon |
| 20 | Harbor Hurdles | Admiral's Hurdle | Landable deck | Surging Harpoon |
| 21 | Blade Foundry | Reef Saw | Sustained | Direct Razor |
| 22 | Blade Foundry | Copper Cutter | Rising | Lobbed Razor |
| 23 | Blade Foundry | Twin Tooth | Falling | Skimming Razor |
| 24 | Blade Foundry | Clockwork Blade | Double beat | Corkscrew Razor |
| 25 | Blade Foundry | Crescent Cutter | Triple beat | Zigzag Razor |
| 26 | Blade Foundry | Sharktooth Wheel | Pulsing | Returning Razor |
| 27 | Blade Foundry | Crosscut Saw | Sweeping | Stuttering Razor |
| 28 | Blade Foundry | Iron Petal | Spinning | Orbiting Razor |
| 29 | Blade Foundry | Spiral Razor | Breathing | Diving Razor |
| 30 | Blade Foundry | Foundry Crown | Delayed strike | Surging Razor |
| 31 | Ember Strait | Ember Vent | Sustained | Direct Fireball |
| 32 | Ember Strait | Cinder Spout | Rising | Lobbed Fireball |
| 33 | Ember Strait | Torch Jet | Falling | Skimming Fireball |
| 34 | Ember Strait | Furnace Mouth | Double beat | Corkscrew Fireball |
| 35 | Ember Strait | Sulfur Geyser | Triple beat | Zigzag Fireball |
| 36 | Ember Strait | Twin Flame | Pulsing | Returning Fireball |
| 37 | Ember Strait | Lava Bellows | Sweeping | Stuttering Fireball |
| 38 | Ember Strait | Phoenix Vent | Spinning | Orbiting Fireball |
| 39 | Ember Strait | Inferno Spitter | Breathing | Diving Fireball |
| 40 | Ember Strait | Solar Flare | Delayed strike | Surging Fireball |
| 41 | Wreckers Bay | Anchor Swing | Sustained | Direct Anchor |
| 42 | Wreckers Bay | Rust Ball | Rising | Lobbed Anchor |
| 43 | Wreckers Bay | Chain Pendulum | Falling | Skimming Anchor |
| 44 | Wreckers Bay | Iron Buoy | Double beat | Corkscrew Anchor |
| 45 | Wreckers Bay | Spiked Weight | Triple beat | Zigzag Anchor |
| 46 | Wreckers Bay | Shipbreaker | Pulsing | Returning Anchor |
| 47 | Wreckers Bay | Bronze Hammer | Sweeping | Stuttering Anchor |
| 48 | Wreckers Bay | Twin Ring Weight | Spinning | Orbiting Anchor |
| 49 | Wreckers Bay | Titan Pendulum | Breathing | Diving Anchor |
| 50 | Wreckers Bay | Leviathan Bell | Delayed strike | Surging Anchor |
| 51 | Dragon Isles | Reef Hatchling | Sustained | Direct Dragon bolt |
| 52 | Dragon Isles | Cinder Drake | Rising | Lobbed Dragon bolt |
| 53 | Dragon Isles | Copper Wyvern | Falling | Skimming Dragon bolt |
| 54 | Dragon Isles | Emerald Wyrm | Double beat | Corkscrew Dragon bolt |
| 55 | Dragon Isles | Horned Serpent | Triple beat | Zigzag Dragon bolt |
| 56 | Dragon Isles | Ruby Dragon | Pulsing | Returning Dragon bolt |
| 57 | Dragon Isles | Ashwing | Sweeping | Stuttering Dragon bolt |
| 58 | Dragon Isles | Stormscale | Spinning | Orbiting Dragon bolt |
| 59 | Dragon Isles | Obsidian Drake | Breathing | Diving Dragon bolt |
| 60 | Dragon Isles | Dragon Monarch | Delayed strike | Surging Dragon bolt |
| 61 | Thorn Reef | Urchin Bed | Sustained | Direct Spine |
| 62 | Thorn Reef | Bone Spikes | Rising | Lobbed Spine |
| 63 | Thorn Reef | Reef Thorns | Falling | Skimming Spine |
| 64 | Thorn Reef | Coral Fangs | Double beat | Corkscrew Spine |
| 65 | Thorn Reef | Iron Quills | Triple beat | Zigzag Spine |
| 66 | Thorn Reef | Obsidian Teeth | Pulsing | Returning Spine |
| 67 | Thorn Reef | Emerald Needles | Sweeping | Stuttering Spine |
| 68 | Thorn Reef | Spear Garden | Spinning | Orbiting Spine |
| 69 | Thorn Reef | Kraken Barbs | Breathing | Diving Spine |
| 70 | Thorn Reef | Thorn Crown | Delayed strike | Surging Spine |
| 71 | Crushing Cliffs | Stone Press | Sustained | Direct Meteor |
| 72 | Crushing Cliffs | Cargo Drop | Rising | Lobbed Meteor |
| 73 | Crushing Cliffs | Iron Stomper | Falling | Skimming Meteor |
| 74 | Crushing Cliffs | Twin Piston | Double beat | Corkscrew Meteor |
| 75 | Crushing Cliffs | Temple Hammer | Triple beat | Zigzag Meteor |
| 76 | Crushing Cliffs | Basalt Ram | Pulsing | Returning Meteor |
| 77 | Crushing Cliffs | Anchor Press | Sweeping | Stuttering Meteor |
| 78 | Crushing Cliffs | Titan Stomp | Spinning | Orbiting Meteor |
| 79 | Crushing Cliffs | Fortress Piston | Breathing | Diving Meteor |
| 80 | Crushing Cliffs | Mountain Maw | Delayed strike | Surging Meteor |
| 81 | Storm Passage | Static Coil | Sustained | Direct Lightning |
| 82 | Storm Passage | Spark Gate | Rising | Lobbed Lightning |
| 83 | Storm Passage | Thunder Rod | Falling | Skimming Lightning |
| 84 | Storm Passage | Plasma Arc | Double beat | Corkscrew Lightning |
| 85 | Storm Passage | Storm Fork | Triple beat | Zigzag Lightning |
| 86 | Storm Passage | Tesla Ring | Pulsing | Returning Lightning |
| 87 | Storm Passage | Lightning Cage | Sweeping | Stuttering Lightning |
| 88 | Storm Passage | Tempest Coil | Spinning | Orbiting Lightning |
| 89 | Storm Passage | Thunder Crown | Breathing | Diving Lightning |
| 90 | Storm Passage | Skybreaker | Delayed strike | Surging Lightning |
| 91 | Frozen Horizon | Ice Shard | Sustained | Direct Ice lance |
| 92 | Frozen Horizon | Frost Fan | Rising | Lobbed Ice lance |
| 93 | Frozen Horizon | Glacier Fang | Falling | Skimming Ice lance |
| 94 | Frozen Horizon | Snow Crystal | Double beat | Corkscrew Ice lance |
| 95 | Frozen Horizon | Polar Spire | Triple beat | Zigzag Ice lance |
| 96 | Frozen Horizon | Frozen Comet | Pulsing | Returning Ice lance |
| 97 | Frozen Horizon | Diamond Frost | Sweeping | Stuttering Ice lance |
| 98 | Frozen Horizon | Arctic Prism | Spinning | Orbiting Ice lance |
| 99 | Frozen Horizon | Blizzard Crown | Breathing | Diving Ice lance |
| 100 | Frozen Horizon | Winter Heart | Delayed strike | Surging Ice lance |
