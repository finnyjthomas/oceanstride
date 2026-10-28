# Ocean Stride Lab

Independent testing copy of Ocean Stride build 7. The main app and its TestFlight build are unchanged.

- Display name: **Ocean Stride Lab**
- Bundle identifier: `com.finstergames.OceanStride.Lab`
- Xcode project: `OceanStride.xcodeproj`, scheme `OceanStride`
- Version: 1.0 (1)
- Separate app sandbox, progress, sound preferences, and best score. Can coexist with Ocean Stride.

## Testing behavior

Boats and helicopters fire only bombs and bullets. Every projectile snapshots the character's current lane and height at launch. It does not pick random lanes or follow the character after launch. Bomb flight lasts 1.6 seconds; bullet flight lasts 1.2 seconds. The red marker shows the locked target. Move or jump after firing to evade; a shot aimed while airborne can also miss when the character lands.

Shots wait until the predicted impact has an adjacent dodge lane clear of barriers and broken stone. The check runs again at impact to handle boost timing changes. Only one shot is active at a time. Finishing platforms remain protected. The established level-based firing intervals are preserved.

Each level mixes hurdles, cutting blades, fire spitters, wrecking balls, and dragons. A shuffled family deck guarantees all five even on level 1. Barrier shapes are centered in their assigned lanes. Hurdles have safe landing decks; active flames, blades, balls, and dragons must be jumped or dodged. More variants unlock as levels rise. One lane per platform stays free of barriers, changing by at most one lane between platforms; it can still be targeted by enemy fire. Sparse density and generous platform lengths are preserved.

The opening screen is marked TEST BUILD and includes a Testing guide explaining these rules. Live ads remain disabled.

## Checks

From the repository root:

```sh
swiftc -module-cache-path /tmp/ocean-stride-module-cache -O Testing/OceanStrideLab/OceanStride/LevelPlan.swift Testing/OceanStrideLab/Tests/LabChecks.swift -o /tmp/ocean-lab-checks
/tmp/ocean-lab-checks
```

Checks fixed lane/height targeting, jump/dodge evasion, all five barrier families across 3,200 seeded layouts, sparse density, open routes, reproducible layouts, escape windows, and aimed attacks on all 100 levels. Physical-device playtesting is still needed for responsiveness and balance.

A separate TestFlight app requires its own App Store Connect record for this bundle identifier. This copy has not been uploaded over the main game's record.

## Current validation status

October 28, 2026: simulator build passed and the separate Lab app was installed and launched on the iPhone 17 Pro simulator. Opening-screen labeling was visually checked. LabChecks passed all 3,200 layouts and verified 370 aimed volleys in the 100-level schedule simulation. No physical-device install or TestFlight upload has been performed.
