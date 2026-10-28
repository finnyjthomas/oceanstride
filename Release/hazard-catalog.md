# Ocean Stride — 100-level hazard catalog

100 named variants in 10 mechanical families, one signature variant introduced per level. Variants change dimensions, active time, period, and visible details; they are not 100 unrelated physics systems. Levels above 100 repeat the catalog.

## Layout and reachability

- Each interior platform has one or two hazards in each of two occupied lanes. The marked mint lane has zero hazards and no broken patch. First and finish platforms have no hazards.
- The marked lane randomly shifts by at most one lane between platforms. Switch lanes while jumping the gap. Cannons and helicopters avoid the marked lane and both lanes during the transition; incoming shots in newly protected lanes are cleared. This gives a constructive no-damage route, with timed jumps across ordinary ocean gaps; it does not require boosts, jewels, extra lives, boat timing or lucky hazard phases.
- Platforms include more than 2.5 seconds of recovery time and gaps use less than 75% of one ordinary jump's travel. The first platform retains at least four seconds before the gap.
- Hazard rows stay away from platform edges; two rows in the same lane are more than one jump duration apart. Barriers never sit over a broken patch.
- New Game creates a random seed. Retry, Continue, next level and rewarded skip preserve it. Old saves load without a seed and receive one at the next save.
- Mint stone/hurdle tops restore jumps. Other mechanisms cannot be landed on. Yellow signals an upcoming active phase; red marks active danger. Mechanisms never reach outside their lane.
- 6,400 seeded levels (64 seeds × 100 levels) are checked, including sampled 120 Hz normal-jump trajectories across every route gap. This proves a route exists under the modeled controls, not that every player input succeeds. Physical-device responsiveness and balancing still need playtesting.

## Level signatures

| Level | Theme | Variant | Behavior | Height | Cycle | Active share |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Coral Ruins | Coral Step | Landable stone top | 0.850 | 3.80s | Always landable |
| 2 | Coral Ruins | Barnacle Block | Landable stone top | 0.915 | 3.68s | Always landable |
| 3 | Coral Ruins | Mossy Plinth | Landable stone top | 0.980 | 3.56s | Always landable |
| 4 | Coral Ruins | Shell Pedestal | Landable stone top | 1.045 | 3.44s | Always landable |
| 5 | Coral Ruins | Reef Slab | Landable stone top | 1.110 | 3.32s | Always landable |
| 6 | Coral Ruins | Tide Altar | Landable stone top | 1.175 | 3.20s | Always landable |
| 7 | Coral Ruins | Pearl Terrace | Landable stone top | 1.240 | 3.08s | Always landable |
| 8 | Coral Ruins | Sunken Pillar | Landable stone top | 1.305 | 2.96s | Always landable |
| 9 | Coral Ruins | Carved Monolith | Landable stone top | 1.370 | 2.84s | Always landable |
| 10 | Coral Ruins | Crownstone | Landable stone top | 1.435 | 2.72s | Always landable |
| 11 | Harbor Hurdles | Dock Rail | Landable hurdle deck | 0.850 | 3.80s | Always landable |
| 12 | Harbor Hurdles | Rope Hurdle | Landable hurdle deck | 0.915 | 3.68s | Always landable |
| 13 | Harbor Hurdles | Driftwood Fence | Landable hurdle deck | 0.980 | 3.56s | Always landable |
| 14 | Harbor Hurdles | Cargo Beam | Landable hurdle deck | 1.045 | 3.44s | Always landable |
| 15 | Harbor Hurdles | Copper Rail | Landable hurdle deck | 1.110 | 3.32s | Always landable |
| 16 | Harbor Hurdles | Buoy Hurdle | Landable hurdle deck | 1.175 | 3.20s | Always landable |
| 17 | Harbor Hurdles | Anchor Fence | Landable hurdle deck | 1.240 | 3.08s | Always landable |
| 18 | Harbor Hurdles | Harbor Vault | Landable hurdle deck | 1.305 | 2.96s | Always landable |
| 19 | Harbor Hurdles | Captain's Rail | Landable hurdle deck | 1.370 | 2.84s | Always landable |
| 20 | Harbor Hurdles | Admiral's Hurdle | Landable hurdle deck | 1.435 | 2.72s | Always landable |
| 21 | Blade Foundry | Reef Saw | Spinning blade lifts clear between cuts | 1.000 | 3.80s | 28% |
| 22 | Blade Foundry | Copper Cutter | Spinning blade lifts clear between cuts | 1.070 | 3.68s | 34% |
| 23 | Blade Foundry | Twin Tooth | Spinning blade lifts clear between cuts | 1.140 | 3.56s | 40% |
| 24 | Blade Foundry | Clockwork Blade | Spinning blade lifts clear between cuts | 1.210 | 3.44s | 46% |
| 25 | Blade Foundry | Crescent Cutter | Spinning blade lifts clear between cuts | 1.280 | 3.32s | 52% |
| 26 | Blade Foundry | Sharktooth Wheel | Spinning blade lifts clear between cuts | 1.350 | 3.20s | 28% |
| 27 | Blade Foundry | Crosscut Saw | Spinning blade lifts clear between cuts | 1.420 | 3.08s | 34% |
| 28 | Blade Foundry | Iron Petal | Spinning blade lifts clear between cuts | 1.490 | 2.96s | 40% |
| 29 | Blade Foundry | Spiral Razor | Spinning blade lifts clear between cuts | 1.560 | 2.84s | 46% |
| 30 | Blade Foundry | Foundry Crown | Spinning blade lifts clear between cuts | 1.630 | 2.72s | 52% |
| 31 | Ember Strait | Ember Vent | Fire jet cycles off / warning / active | 1.000 | 3.80s | 28% |
| 32 | Ember Strait | Cinder Spout | Fire jet cycles off / warning / active | 1.070 | 3.68s | 34% |
| 33 | Ember Strait | Torch Jet | Fire jet cycles off / warning / active | 1.140 | 3.56s | 40% |
| 34 | Ember Strait | Furnace Mouth | Fire jet cycles off / warning / active | 1.210 | 3.44s | 46% |
| 35 | Ember Strait | Sulfur Geyser | Fire jet cycles off / warning / active | 1.280 | 3.32s | 52% |
| 36 | Ember Strait | Twin Flame | Fire jet cycles off / warning / active | 1.350 | 3.20s | 28% |
| 37 | Ember Strait | Lava Bellows | Fire jet cycles off / warning / active | 1.420 | 3.08s | 34% |
| 38 | Ember Strait | Phoenix Vent | Fire jet cycles off / warning / active | 1.490 | 2.96s | 40% |
| 39 | Ember Strait | Inferno Spitter | Fire jet cycles off / warning / active | 1.560 | 2.84s | 46% |
| 40 | Ember Strait | Solar Flare | Fire jet cycles off / warning / active | 1.630 | 2.72s | 52% |
| 41 | Wreckers Bay | Anchor Swing | Chain weight lowers into lane then lifts | 1.000 | 3.80s | 28% |
| 42 | Wreckers Bay | Rust Ball | Chain weight lowers into lane then lifts | 1.070 | 3.68s | 34% |
| 43 | Wreckers Bay | Chain Pendulum | Chain weight lowers into lane then lifts | 1.140 | 3.56s | 40% |
| 44 | Wreckers Bay | Iron Buoy | Chain weight lowers into lane then lifts | 1.210 | 3.44s | 46% |
| 45 | Wreckers Bay | Spiked Weight | Chain weight lowers into lane then lifts | 1.280 | 3.32s | 52% |
| 46 | Wreckers Bay | Shipbreaker | Chain weight lowers into lane then lifts | 1.350 | 3.20s | 28% |
| 47 | Wreckers Bay | Bronze Hammer | Chain weight lowers into lane then lifts | 1.420 | 3.08s | 34% |
| 48 | Wreckers Bay | Twin Ring Weight | Chain weight lowers into lane then lifts | 1.490 | 2.96s | 40% |
| 49 | Wreckers Bay | Titan Pendulum | Chain weight lowers into lane then lifts | 1.560 | 2.84s | 46% |
| 50 | Wreckers Bay | Leviathan Bell | Chain weight lowers into lane then lifts | 1.630 | 2.72s | 52% |
| 51 | Dragon Isles | Reef Hatchling | Dragon breath pulses within its own lane | 1.000 | 3.80s | 28% |
| 52 | Dragon Isles | Cinder Drake | Dragon breath pulses within its own lane | 1.070 | 3.68s | 34% |
| 53 | Dragon Isles | Copper Wyvern | Dragon breath pulses within its own lane | 1.140 | 3.56s | 40% |
| 54 | Dragon Isles | Emerald Wyrm | Dragon breath pulses within its own lane | 1.210 | 3.44s | 46% |
| 55 | Dragon Isles | Horned Serpent | Dragon breath pulses within its own lane | 1.280 | 3.32s | 52% |
| 56 | Dragon Isles | Ruby Dragon | Dragon breath pulses within its own lane | 1.350 | 3.20s | 28% |
| 57 | Dragon Isles | Ashwing | Dragon breath pulses within its own lane | 1.420 | 3.08s | 34% |
| 58 | Dragon Isles | Stormscale | Dragon breath pulses within its own lane | 1.490 | 2.96s | 40% |
| 59 | Dragon Isles | Obsidian Drake | Dragon breath pulses within its own lane | 1.560 | 2.84s | 46% |
| 60 | Dragon Isles | Dragon Monarch | Dragon breath pulses within its own lane | 1.630 | 2.72s | 52% |
| 61 | Thorn Reef | Urchin Bed | Spikes retract between bursts | 1.000 | 3.80s | 28% |
| 62 | Thorn Reef | Bone Spikes | Spikes retract between bursts | 1.070 | 3.68s | 34% |
| 63 | Thorn Reef | Reef Thorns | Spikes retract between bursts | 1.140 | 3.56s | 40% |
| 64 | Thorn Reef | Coral Fangs | Spikes retract between bursts | 1.210 | 3.44s | 46% |
| 65 | Thorn Reef | Iron Quills | Spikes retract between bursts | 1.280 | 3.32s | 52% |
| 66 | Thorn Reef | Obsidian Teeth | Spikes retract between bursts | 1.350 | 3.20s | 28% |
| 67 | Thorn Reef | Emerald Needles | Spikes retract between bursts | 1.420 | 3.08s | 34% |
| 68 | Thorn Reef | Spear Garden | Spikes retract between bursts | 1.490 | 2.96s | 40% |
| 69 | Thorn Reef | Kraken Barbs | Spikes retract between bursts | 1.560 | 2.84s | 46% |
| 70 | Thorn Reef | Thorn Crown | Spikes retract between bursts | 1.630 | 2.72s | 52% |
| 71 | Crushing Cliffs | Stone Press | Piston raises between crushing strokes | 1.000 | 3.80s | 28% |
| 72 | Crushing Cliffs | Cargo Drop | Piston raises between crushing strokes | 1.070 | 3.68s | 34% |
| 73 | Crushing Cliffs | Iron Stomper | Piston raises between crushing strokes | 1.140 | 3.56s | 40% |
| 74 | Crushing Cliffs | Twin Piston | Piston raises between crushing strokes | 1.210 | 3.44s | 46% |
| 75 | Crushing Cliffs | Temple Hammer | Piston raises between crushing strokes | 1.280 | 3.32s | 52% |
| 76 | Crushing Cliffs | Basalt Ram | Piston raises between crushing strokes | 1.350 | 3.20s | 28% |
| 77 | Crushing Cliffs | Anchor Press | Piston raises between crushing strokes | 1.420 | 3.08s | 34% |
| 78 | Crushing Cliffs | Titan Stomp | Piston raises between crushing strokes | 1.490 | 2.96s | 40% |
| 79 | Crushing Cliffs | Fortress Piston | Piston raises between crushing strokes | 1.560 | 2.84s | 46% |
| 80 | Crushing Cliffs | Mountain Maw | Piston raises between crushing strokes | 1.630 | 2.72s | 52% |
| 81 | Storm Passage | Static Coil | Electric arc switches off between pulses | 1.000 | 3.80s | 28% |
| 82 | Storm Passage | Spark Gate | Electric arc switches off between pulses | 1.070 | 3.68s | 34% |
| 83 | Storm Passage | Thunder Rod | Electric arc switches off between pulses | 1.140 | 3.56s | 40% |
| 84 | Storm Passage | Plasma Arc | Electric arc switches off between pulses | 1.210 | 3.44s | 46% |
| 85 | Storm Passage | Storm Fork | Electric arc switches off between pulses | 1.280 | 3.32s | 52% |
| 86 | Storm Passage | Tesla Ring | Electric arc switches off between pulses | 1.350 | 3.20s | 28% |
| 87 | Storm Passage | Lightning Cage | Electric arc switches off between pulses | 1.420 | 3.08s | 34% |
| 88 | Storm Passage | Tempest Coil | Electric arc switches off between pulses | 1.490 | 2.96s | 40% |
| 89 | Storm Passage | Thunder Crown | Electric arc switches off between pulses | 1.560 | 2.84s | 46% |
| 90 | Storm Passage | Skybreaker | Electric arc switches off between pulses | 1.630 | 2.72s | 52% |
| 91 | Frozen Horizon | Ice Shard | Ice shards retract between eruptions | 1.000 | 3.80s | 28% |
| 92 | Frozen Horizon | Frost Fan | Ice shards retract between eruptions | 1.070 | 3.68s | 34% |
| 93 | Frozen Horizon | Glacier Fang | Ice shards retract between eruptions | 1.140 | 3.56s | 40% |
| 94 | Frozen Horizon | Snow Crystal | Ice shards retract between eruptions | 1.210 | 3.44s | 46% |
| 95 | Frozen Horizon | Polar Spire | Ice shards retract between eruptions | 1.280 | 3.32s | 52% |
| 96 | Frozen Horizon | Frozen Comet | Ice shards retract between eruptions | 1.350 | 3.20s | 28% |
| 97 | Frozen Horizon | Diamond Frost | Ice shards retract between eruptions | 1.420 | 3.08s | 34% |
| 98 | Frozen Horizon | Arctic Prism | Ice shards retract between eruptions | 1.490 | 2.96s | 40% |
| 99 | Frozen Horizon | Blizzard Crown | Ice shards retract between eruptions | 1.560 | 2.84s | 46% |
| 100 | Frozen Horizon | Winter Heart | Ice shards retract between eruptions | 1.630 | 2.72s | 52% |
