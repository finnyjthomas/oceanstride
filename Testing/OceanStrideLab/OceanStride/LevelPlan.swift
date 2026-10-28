import Foundation

/// A reward belongs to one request in one attempt; late/duplicate callbacks cannot skip again.
struct RewardedSkipRequest {
    private(set) var used = false
    private(set) var pending: UUID?
    mutating func request() -> UUID? {
        guard !used, pending == nil else { return nil }
        let token = UUID()
        pending = token
        return token
    }
    mutating func complete(_ token: UUID, earned: Bool) -> Bool {
        guard pending == token, !used else { return false }
        pending = nil
        guard earned else { return false }
        used = true
        return true
    }
}

struct JewelBoost {
    static let cost = 100
    private(set) var remaining: Double
    private(set) var isActive = false
    init(remaining: Double = 0) { self.remaining = remaining.isFinite ? max(0, min(5, remaining)) : 0 }
    var speedMultiplier: Double { isActive ? 3 : 1 }

    mutating func activate(jewels: inout Int) -> Bool {
        guard !isActive else { return false }
        if remaining <= 0 {
            guard jewels >= Self.cost else { return false }
            jewels -= Self.cost
            remaining = 5
        }
        isActive = true
        return true
    }

    mutating func advance(_ seconds: Double) {
        guard isActive else { return }
        remaining = max(0, remaining - max(0, seconds))
        if remaining == 0 { isActive = false }
    }
    mutating func pause() { isActive = false }
}

enum HazardFamily: Int, CaseIterable {
    case stone, hurdle, blade, flame, wrecking, dragon, spike, crusher, storm, frost
    var title: String { ["Coral Ruins", "Harbor Hurdles", "Blade Foundry", "Ember Strait", "Wreckers Bay", "Dragon Isles", "Thorn Reef", "Crushing Cliffs", "Storm Passage", "Frozen Horizon"][rawValue] }
}

/// One signature variant per level, with distinct dimensions, cycles and motion.
struct HazardVariant {
    let id: Int
    var family: HazardFamily { HazardFamily(rawValue: min(99, max(0, id)) / 10)! }
    var tier: Int { min(99, max(0, id)) % 10 }
    var name: String { Self.names[min(99, max(0, id))] }
    var landable: Bool { family == .stone || family == .hurdle }
    var height: Double { landable ? 0.85 + Double(tier) * 0.065 : 1.0 + Double(tier) * 0.07 }
    var period: Double { 3.8 - Double(tier) * 0.12 }
    var duty: Double { 0.28 + Double(tier % 5) * 0.06 }
    var motionName: String { ["Sustained", "Rising", "Falling", "Double beat", "Triple beat", "Pulsing", "Sweeping", "Spinning", "Breathing", "Delayed strike"][tier] }
    func isActive(phase: Double) -> Bool {
        switch tier {
        case 0: return phase < 0.34
        case 1: return phase < 0.43
        case 2: return phase < 0.29
        case 3: return phase < 0.16 || (phase >= 0.30 && phase < 0.46)
        case 4: return phase < 0.10 || (phase >= 0.23 && phase < 0.33) || (phase >= 0.46 && phase < 0.56)
        case 5: return phase < 0.22 || (phase >= 0.39 && phase < 0.52)
        case 6: return phase < 0.48
        case 7: return phase < 0.38
        case 8: return phase < 0.55
        default: return phase >= 0.18 && phase < 0.49
        }
    }
    var width: Double { 0.13 + Double(tier % 4) * 0.025 }
    static let names: [String] = [
        "Coral Step", "Barnacle Block", "Mossy Plinth", "Shell Pedestal", "Reef Slab", "Tide Altar", "Pearl Terrace", "Sunken Pillar", "Carved Monolith", "Crownstone",
        "Dock Rail", "Rope Hurdle", "Driftwood Fence", "Cargo Beam", "Copper Rail", "Buoy Hurdle", "Anchor Fence", "Harbor Vault", "Captain's Rail", "Admiral's Hurdle",
        "Reef Saw", "Copper Cutter", "Twin Tooth", "Clockwork Blade", "Crescent Cutter", "Sharktooth Wheel", "Crosscut Saw", "Iron Petal", "Spiral Razor", "Foundry Crown",
        "Ember Vent", "Cinder Spout", "Torch Jet", "Furnace Mouth", "Sulfur Geyser", "Twin Flame", "Lava Bellows", "Phoenix Vent", "Inferno Spitter", "Solar Flare",
        "Anchor Swing", "Rust Ball", "Chain Pendulum", "Iron Buoy", "Spiked Weight", "Shipbreaker", "Bronze Hammer", "Twin Ring Weight", "Titan Pendulum", "Leviathan Bell",
        "Reef Hatchling", "Cinder Drake", "Copper Wyvern", "Emerald Wyrm", "Horned Serpent", "Ruby Dragon", "Ashwing", "Stormscale", "Obsidian Drake", "Dragon Monarch",
        "Urchin Bed", "Bone Spikes", "Reef Thorns", "Coral Fangs", "Iron Quills", "Obsidian Teeth", "Emerald Needles", "Spear Garden", "Kraken Barbs", "Thorn Crown",
        "Stone Press", "Cargo Drop", "Iron Stomper", "Twin Piston", "Temple Hammer", "Basalt Ram", "Anchor Press", "Titan Stomp", "Fortress Piston", "Mountain Maw",
        "Static Coil", "Spark Gate", "Thunder Rod", "Plasma Arc", "Storm Fork", "Tesla Ring", "Lightning Cage", "Tempest Coil", "Thunder Crown", "Skybreaker",
        "Ice Shard", "Frost Fan", "Glacier Fang", "Snow Crystal", "Polar Spire", "Frozen Comet", "Diamond Frost", "Arctic Prism", "Blizzard Crown", "Winter Heart"
    ]
}

struct LayoutRandom {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
    mutating func int(_ count: Int) -> Int { Int(next() % UInt64(count)) }
    mutating func unit() -> Double { Double(next() >> 11) / 9007199254740992 }
}

struct Barrier {
    let id: Int
    let lane: Int
    let position: Double
    var hasFire = false
    var variantID: Int? = nil
    var phaseOffset = 0.0
    static let height = 1.3
    static let halfLength = 1.2
    static let sideHitHeight = height - 0.45
    var variant: HazardVariant? { variantID.map { HazardVariant(id: $0) } }
    var topHeight: Double { variant?.height ?? Self.height }
    var isLandable: Bool { !hasFire && (variant?.landable ?? true) }
    func contains(distance: Double, lane: Int) -> Bool {
        self.lane == lane && abs(distance - position) <= Self.halfLength
    }
    func canLand(previousHeight: Double, height: Double) -> Bool {
        isLandable && previousHeight >= topHeight - 0.45 && height <= topHeight + 0.08 && height < previousHeight
    }
    func cycle(at time: Double) -> Double {
        (max(0, time) + phaseOffset).truncatingRemainder(dividingBy: variant?.period ?? 3) / (variant?.period ?? 3)
    }
    func active(at time: Double) -> Bool {
        guard let variant, !variant.landable else { return hasFire }
        return variant.isActive(phase: cycle(at: time))
    }
    func warning(at time: Double) -> Bool {
        guard let variant, !variant.landable, !active(at: time) else { return false }
        return (1...18).contains { step in
            variant.isActive(phase: (cycle(at: time) + Double(step) * 0.01).truncatingRemainder(dividingBy: 1))
        }
    }
    func damageBand(at time: Double) -> ClosedRange<Double>? {
        guard let v = variant, !v.landable, active(at: time) else { return nil }
        let phase = cycle(at: time)
        let wave = (sin(phase * .pi * 2) + 1) / 2
        let lift: Double
        switch v.tier {
        case 1: lift = phase * 1.2
        case 2: lift = max(0, 0.55 - phase * 1.5)
        case 6: lift = wave * 0.45
        case 7: lift = abs(sin(phase * .pi * 4)) * 0.3
        default: lift = 0
        }
        switch v.family {
        case .blade: return (0.08 + lift)...(1.05 + lift)
        case .wrecking: return (0.1 + lift)...(1.65 + lift)
        case .crusher: return 0...(2.5 + lift)
        case .storm: return 0...(2.2 + lift)
        default: return 0...(v.height + 0.75 + lift)
        }
    }

    func causesDamage(height: Double, supported: Bool, time: Double = 0) -> Bool {
        if hasFire { return height < Self.height + 0.85 }
        if let v = variant, !v.landable {
            guard let band = damageBand(at: time) else { return false }
            return height < band.upperBound && height + 1.15 > band.lowerBound
        }
        return !supported && height < topHeight - 0.45
    }
}

struct JewelPickup {
    let id: Int
    let lane: Int
    let position: Double
    let elevation: Double
    let value: Int
}

struct CrossingShip {
    let id: Int
    let position: Double
    let direction: Double
    let deckHeight = 0.65
    let halfWidth = 0.95
    let halfLength = 1.4
    func supports(distance: Double, x: Double, speed: Double) -> Bool {
        abs(distance - position) <= halfLength + 0.15 &&
        abs(x - lateralPosition(distance: distance, speed: speed)) <= halfWidth + 0.15
    }
    func lateralPosition(distance: Double, speed: Double) -> Double {
        max(-3.5, min(3.5, (position - distance) / speed * 1.8)) * direction
    }
}

struct StonePlatform {
    let safeLane: Int
    let start: Double
    let length: Double
    let brokenLane: Int?
    let obstacleLane: Int?
    let jewelLane: Int
    let barriers: [Barrier]
    let jewels: [JewelPickup]
    let medicalLane: Int?
    var medicalPosition: Double { start + 3 }
    var end: Double { start + length }
}

struct LevelPlan {
    let number: Int
    let speed: Double
    private let paceScale: Double
    let platforms: [StonePlatform]
    let crossingShips: [CrossingShip]
    var safeLane: Int { platforms[0].safeLane }
    var attack: AttackProfile { AttackProfile(id: (number - 1) % 100) }
    var signature: HazardVariant { HazardVariant(id: (number - 1) % 100) }
    /// Aimed shots are delayed until the target has an adjacent obstacle-free exit.
    func escapeLanes(at distance: Double, from targetLane: Int) -> [Int] {
        guard let index = platforms.firstIndex(where: { distance >= $0.start && distance <= $0.end }),
              index > 0, index < platforms.count - 1 else { return [] }
        let stone = platforms[index]
        guard distance > stone.start + speed * 0.8,
              distance < stone.end - speed * 0.8 else { return [] }
        let room = speed * 0.45
        return (0...2).filter { lane in
            abs(lane - targetLane) == 1 &&
            !stone.barriers.contains { $0.lane == lane && abs($0.position - distance) < Barrier.halfLength + room } &&
            !(stone.brokenLane == lane && abs(stone.start + stone.length / 2 - distance) < 2.4 + room)
        }
    }
    var finish: Double { platforms.last!.end - 6 }
    // Reduce frequency by 10% per level, but keep attacks at most ten seconds apart.
    var firingInterval: Double {
        if (91...100).contains(number) { return 3 }
        return min(10, 3.8 / pow(0.9, Double(number - 1)))
    }
    var projectileSpeed: Double { min(34, 18 + Double(number - 1) * 1.5) }
    var hasHelicopters: Bool { number >= 4 }
    var volleySize: Int { number > 70 ? 2 : 1 }

    init(number: Int, seed: UInt64 = 0) {
        self.number = max(1, number)
        paceScale = self.number < 10 ? 1 : 0.9
        speed = (10 + 9 * (1 - exp(-Double(self.number - 1) / 28))) * paceScale * 0.9
        var rng = LayoutRandom(state: seed &+ UInt64(self.number) &* 7919)
        var safeLane = rng.int(3)
        // Cycle a shuffled family deck so even the first level contains all five.
        var families = [1, 2, 3, 4, 5] // hurdles, blades, fire, wrecking balls, dragons
        for index in stride(from: families.count - 1, through: 1, by: -1) {
            families.swapAt(index, rng.int(index + 1))
        }
        var barrierOrdinal = 0
        var stones: [StonePlatform] = []
        var cursor = 0.0
        for index in 0..<(5 + (self.number - 1) * 2) {
            // Only adjacent shifts: never require crossing two lanes over a gap.
            // Force an early turn so even short levels do not stay straight.
            if index > 0 && (index == 1 || rng.int(3) != 0) {
                safeLane = safeLane == 1 ? (rng.int(2) == 0 ? 0 : 2) : 1
            }
            let occupied = (0...2).filter { $0 != safeLane }
            // Preserve a full jump-recovery window at both edges and between rows.
            let standardLength = max(36, speed * 3.4)
            let length = index == 0 ? max(standardLength * 1.5, 2 + speed * 4) : standardLength
            let gap = min(6.5, 3.4 + Double(self.number - 1) * 0.3, speed * 1.05 * 0.75)
            let isFinish = index == 4 + (self.number - 1) * 2
            let interior = index > 0 && !isFinish
            let brokenLane = interior && self.number >= 3 && rng.int(3) == 0 ? occupied[rng.int(2)] : nil
            var barriers: [Barrier] = []
            var jewels = (0..<2).map { offset in
                JewelPickup(id: index * 100 + offset, lane: safeLane,
                    position: cursor + 3 + Double(offset) * 2, elevation: 0.8, value: 1)
            }
            if interior {
                for (slot, obstacleLane) in occupied.enumerated() {
                    let count = rng.int(4) == 0 ? 2 : 1
                    for row in 0..<count {
                        // Do not put a landing surface on a broken patch.
                        let fraction = count == 1 ? (brokenLane == obstacleLane ? 0.27 : 0.5) : (row == 0 ? 0.27 : 0.73)
                        let position = cursor + length * fraction + (rng.unit() - 0.5) * 0.6
                        let family = families[barrierOrdinal % families.count]
                        let tier = rng.int(min(10, 1 + (self.number - 1) / 10))
                        let wreckingOrder = [1, 2, 4, 6, 8, 0, 3, 5, 7, 9]
                        let kind = family * 10 + (family == 4 ? wreckingOrder[tier] : tier)
                        barrierOrdinal += 1
                        let barrier = Barrier(id: index * 10 + slot * 2 + row, lane: obstacleLane,
                            position: position, variantID: kind, phaseOffset: rng.unit() * 4)
                        barriers.append(barrier)
                        for offset in 0..<3 {
                            jewels.append(JewelPickup(id: index * 100 + 10 + slot * 10 + row * 3 + offset,
                                lane: obstacleLane, position: position + Double(offset - 1),
                                elevation: barrier.topHeight + 0.8, value: self.number >= 5 ? 3 : 2))
                        }
                    }
                }
            }
            let medicalIndex = 1 + (self.number * 3) % (3 + (self.number - 1) * 2)
            let medicalLane = self.number >= 11 && self.number % 2 == 1 && index == medicalIndex && !isFinish ? safeLane : nil
            stones.append(StonePlatform(safeLane: safeLane, start: cursor, length: length, brokenLane: brokenLane,
                obstacleLane: barriers.first?.lane, jewelLane: safeLane, barriers: barriers,
                jewels: jewels, medicalLane: medicalLane))
            cursor += length + gap
        }
        platforms = stones
        crossingShips = self.number >= 6 ? stones.dropLast(2).enumerated().compactMap { index, stone in
            guard index >= 2 && index % 4 == 2 else { return nil }
            return CrossingShip(id: index, position: (stone.end + stones[index + 1].start) * 0.5,
                direction: index % 8 == 2 ? 1 : -1)
        } : []
    }
}

/// Each level pairs a different weapon silhouette with a different flight behavior.
/// All projectiles telegraph a fixed impact lane; only the impact deals damage.
struct AttackProfile {
    let id: Int
    var weapon: Int { max(0, min(99, id)) / 10 }
    var trajectory: Int { max(0, min(99, id)) % 10 }
    static let weapons = ["Cannon", "Harpoon", "Razor", "Fireball", "Anchor", "Dragon bolt", "Spine", "Meteor", "Lightning", "Ice lance"]
    static let flights = ["Direct", "Lobbed", "Skimming", "Corkscrew", "Zigzag", "Returning", "Stuttering", "Orbiting", "Diving", "Surging"]
    var name: String { "\(Self.flights[trajectory]) \(Self.weapons[weapon])" }
    var instruction: String {
        let moves = ["Straight shot", "High arc", "Low approach", "Spiral approach", "Side-to-side flight", "Curved return", "Stop-and-go flight", "Orbit then strike", "Climb then dive", "Slow start, fast finish"]
        return "\(moves[trajectory]). \(damageBand.upperBound > 2.5 ? "Dodge the marked lane." : "Jump or dodge the marked lane.")"
    }
    var damageBand: ClosedRange<Double> {
        let tops = [1.3, 1.8, 0.75, 3.0, 1.65, 3.4, 1.0, 3.8, 3.2, 1.5]
        return 0...tops[weapon]
    }
    func duration(speed: Double) -> Double { max(1.45, 48 / speed) + [0, 0.35, 0.1, 0.4, 0.25, 0.55, 0.6, 0.5, 0.3, 0.45][trajectory] }
    func flight(at raw: Double) -> (progress: Double, sideways: Double, rise: Double) {
        let t = max(0, min(1, raw)), envelope = sin(max(0, min(1, raw)) * .pi)
        switch trajectory {
        case 1: return (t, 0, envelope * 95)
        case 2: return (t, 0, -envelope * 25)
        case 3: return (t, sin(t * .pi * 8) * envelope * 34, cos(t * .pi * 8) * envelope * 32)
        case 4: return (t, asin(sin(t * .pi * 8)) * envelope * 26, envelope * 15)
        case 5: return (t + sin(t * .pi * 2) * 0.14, envelope * 65, envelope * 45)
        case 6: return (t - sin(t * .pi * 6) / (.pi * 6), 0, envelope * 20)
        case 7: return (t * t, sin(t * .pi * 4) * envelope * 65, envelope * 65)
        case 8: return (t * t * t, 0, envelope * 135)
        case 9: return (pow(t, 2.4), sin(t * .pi * 2) * envelope * 14, envelope * 30)
        default: return (t, 0, envelope * 8)
        }
    }
}

/// Shared vector artwork used by gameplay, the field guide, and visual QA exports.
/// Coordinates are normalized to a lane-sized frame; no downloaded sprite assets.
struct EncounterMark {
    let points: [CGPoint]
    let color: Int
    let filled: Bool
    let thickness: Double
}
struct EncounterPen {
    var marks: [EncounterMark] = []
    mutating func poly(_ coords: [Double], _ color: Int = 0) {
        marks.append(EncounterMark(points: stride(from: 0, to: coords.count, by: 2).map { CGPoint(x: coords[$0], y: coords[$0 + 1]) }, color: color, filled: true, thickness: 0.025))
    }
    mutating func line(_ coords: [Double], _ color: Int = 1, _ width: Double = 0.05) {
        marks.append(EncounterMark(points: stride(from: 0, to: coords.count, by: 2).map { CGPoint(x: coords[$0], y: coords[$0 + 1]) }, color: color, filled: false, thickness: width))
    }
    mutating func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Int = 0) { poly([x,y,x+w,y,x+w,y+h,x,y+h],c) }
    mutating func oval(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ c: Int = 0) {
        var coords: [Double] = []
        for i in 0..<24 { let a = Double(i) * .pi / 12; coords += [x+cos(a)*rx,y+sin(a)*ry] }
        poly(coords,c)
    }
    mutating func star(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ tips: Int, _ angle: Double = 0, _ c: Int = 0) {
        var coords: [Double] = []
        for i in 0..<tips*2 { let a = Double(i) * .pi / Double(tips)+angle; let r = i % 2 == 0 ? 1.0 : 0.45; coords += [x+cos(a)*rx*r,y+sin(a)*ry*r] }
        poly(coords,c)
    }
    mutating func ring(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ c: Int = 0) {
        var coords: [Double] = []
        for i in 0...32 { let a = Double(i) * .pi / 16; coords += [x+cos(a)*rx,y+sin(a)*ry] }
        line(coords,c,0.07)
    }
}

enum EncounterArtwork {
    // Silver, dark metal, gold, red, mint, ivory, ice, violet, ember, sea green.
    static let palette: [(Double,Double,Double)] = [(0.65,0.77,0.81),(0.13,0.23,0.29),(1,0.76,0.23),(0.94,0.21,0.22),(0.28,0.96,0.72),(0.96,0.94,0.81),(0.38,0.86,1),(0.73,0.42,0.95),(1,0.43,0.12),(0.18,0.64,0.50)]
    static func barrier(_ id: Int, time: Double) -> [EncounterMark] {
        var p = EncounterPen()
        let t = time, sway = sin(t * 3) * 0.12
        switch id {
        // Coral ruins: ten different architectural silhouettes under flat safe decks.
        case 0: p.poly([-1,0,1,0,1,0.38,0.45,0.38,0.45,0.7,-0.2,0.7,-0.2,1,-1,1]); p.box(-1,0.92,2,0.08,4)
        case 1: p.box(-0.85,0,1.7,1); for i in 0..<5 { p.ring(-0.6+Double(i)*0.3,0.3+Double(i%2)*0.3,0.16,0.13,5) }; p.box(-1,0.92,2,0.08,4)
        case 2: p.poly([-0.9,0,0.9,0,0.55,0.8,-0.55,0.8],9); p.box(-1,0.8,2,0.2,4); p.line([-0.5,0.1,0,0.5,0.5,0.1],2)
        case 3: p.poly([-0.2,0,0.2,0,1,0.9,-1,0.9],5); for i in 0..<7 { p.line([0,0.05,-0.9+Double(i)*0.3,0.9],8,0.035) }; p.box(-1,0.94,2,0.06,4)
        case 4: p.box(-1,0,0.35,1); p.box(0.65,0,0.35,1); p.box(-1,0.72,2,0.28,4); p.ring(0,0.65,0.65,0.25,2)
        case 5: p.box(-0.95,0,1.9,0.18,1); p.box(-0.3,0.18,0.6,0.65,0); p.box(-1,0.83,2,0.17,4); p.star(0,0.5,0.25,0.23,4,0,2)
        case 6: for i in 0..<3 { p.box(-0.95+Double(i)*0.14,Double(i)*0.29,1.9-Double(i)*0.28,0.18,5) }; p.box(-1,0.9,2,0.1,4); p.oval(0,0.76,0.19,0.14,2)
        case 7: p.box(-0.8,0,1.6,0.16,1); for x in [-0.5,0.0,0.5] { p.box(x-0.12,0.16,0.24,0.7,5) }; p.box(-1,0.86,2,0.14,4)
        case 8: p.poly([-0.6,0,0.6,0,0.35,0.9,-0.35,0.9],1); p.line([0,0.1,-0.2,0.3,0.2,0.5,-0.2,0.7,0,0.9],6); p.box(-1,0.9,2,0.1,4)
        case 9: p.poly([-1,0,-0.85,0.85,-0.45,0.55,0,0.95,0.45,0.55,0.85,0.85,1,0],2); p.box(-1,0.94,2,0.06,4); p.oval(0,0.35,0.16,0.14,6)
        // Harbor hurdles: distinct supports and braces, with a solid landable beam.
        case 10: p.line([-0.85,0,-0.85,1,0.85,1,0.85,0],0,0.14); p.box(-1,0.85,2,0.15,4)
        case 11: p.line([-0.85,0,-0.85,1],2,0.1); p.line([0.85,0,0.85,1],2,0.1); p.line([-0.85,0.75,-0.4,0.4,0,0.3,0.4,0.4,0.85,0.75],5,0.08); p.box(-1,0.91,2,0.09,4)
        case 12: p.poly([-1,0,-0.8,0.9,-0.6,0.85,-0.75,0],2); p.poly([0.6,0,0.5,0.95,0.8,0.8,1,0],2); p.line([-0.9,0.2,0.8,0.8,-0.9,0.65,0.9,0.15],0,0.1); p.box(-1,0.9,2,0.1,4)
        case 13: p.box(-0.9,0,0.45,0.9,8); p.box(0.45,0,0.45,0.9,8); p.line([-0.8,0.1,-0.55,0.8,0.55,0.1,0.8,0.8],1,0.07); p.box(-1,0.87,2,0.13,4)
        case 14: p.line([-0.9,0,0,0.9,0.9,0,-0.9,0],2,0.12); p.line([0,0,0,0.9],0,0.1); p.box(-1,0.9,2,0.1,4)
        case 15: p.oval(-0.65,0.4,0.28,0.4,8); p.oval(0.65,0.4,0.28,0.4,8); p.box(-0.95,0.35,0.6,0.13,5); p.box(0.35,0.35,0.6,0.13,5); p.box(-1,0.9,2,0.1,4)
        case 16: p.line([0,0.1,0,0.9],0,0.12); p.line([-0.8,0.6,-0.6,0.1,0,0.02,0.6,0.1,0.8,0.6],0,0.13); p.ring(0,0.72,0.22,0.15,2); p.box(-1,0.9,2,0.1,4)
        case 17: p.line([-0.9,0,-0.7,0.75,0,0.92,0.7,0.75,0.9,0],5,0.15); p.line([-0.5,0,-0.3,0.7,0.3,0.7,0.5,0],2,0.09); p.box(-1,0.92,2,0.08,4)
        case 18: p.box(-0.9,0,0.2,1,1); p.box(0.7,0,0.2,1,1); p.ring(0,0.45,0.43,0.32,2); p.line([-0.4,0.45,0.4,0.45,0,0.45,0,0.78,0,0.12],2); p.box(-1,0.9,2,0.1,4)
        case 19: p.poly([-0.8,0,-0.6,0.85,0,0.55,0.6,0.85,0.8,0],1); p.star(0,0.4,0.35,0.28,5,t*0.3,2); p.box(-1,0.88,2,0.12,4)
        // Blades: wheel, scissors, twins, gears, crescent, teeth, cross, petals, spiral, crown.
        case 20: p.star(0,0.5,0.95,0.48,12,t*3); p.oval(0,0.5,0.2,0.1,2)
        case 21: p.poly([-0.9,0.05,0.8,0.9,1,1,-0.4,0.1]); p.poly([0.9,0.05,-0.8,0.9,-1,1,0.4,0.1],2); p.oval(0,0.4,0.13,0.1,1)
        case 22: p.star(-0.48,0.35,0.5,0.32,8,t*4); p.star(0.48,0.65,0.5,0.32,8,-t*4,2)
        case 23: p.star(-0.4,0.3,0.6,0.3,10,t*2); p.star(0.45,0.72,0.5,0.25,10,-t*2,2); p.line([-0.4,0.3,0.45,0.72],1,0.08)
        case 24: p.poly([-0.9,0.1,-0.2,0,0.7,0.2,1,0.65,0.65,1,0.75,0.55,0.35,0.3,-0.4,0.25],5); p.line([-0.6,0,0.1,1],1,0.1)
        case 25: p.box(-1,0.35,2,0.18,1); for i in 0..<5 { let x = -1+Double(i)*0.4; p.poly([x,0.5,x+0.4,0.5,x+0.12,1]); p.poly([x,0.35,x+0.4,0.35,x+0.28,0],2) }
        case 26: p.poly([-0.95,0,-0.55,0,0.95,1,0.55,1]); p.poly([0.95,0,0.55,0,-0.95,1,-0.55,1],2); p.oval(0,0.5,0.2,0.13,1)
        case 27: for i in 0..<5 { let a=t+Double(i)*1.256; p.oval(cos(a)*0.5,0.5+sin(a)*0.25,0.42,0.19) }; p.star(0,0.5,0.2,0.1,5,t,3)
        case 28: for i in 0..<3 { p.ring(sin(t+Double(i))*0.15,0.2+Double(i)*0.3,0.85-Double(i)*0.2,0.16,i%2 == 0 ? 0 : 2) }; p.line([0,0,0,1],1,0.06)
        case 29: p.star(0,0.5,1,0.5,5,t*2,2); p.star(0,0.5,0.6,0.3,5,-t*3,0); p.oval(0,0.5,0.14,0.1,3)
        // Fire machinery with different nozzle silhouettes and plume configurations.
        case 30: p.box(-0.7,0,1.4,0.2,1); p.poly([-0.55,0.2,-0.15,1,0,0.6,0.25,0.95,0.6,0.2],8); p.poly([-0.25,0.2,0,0.7,0.25,0.2],2)
        case 31: p.poly([-0.9,0,-0.4,0.45,0.4,0.45,0.9,0],1); p.oval(0,0.7+sway,0.35,0.19,8); p.star(0,0.95,0.2,0.08,5,t,2)
        case 32: p.line([-0.6,0,-0.6,0.45,0.6,0.45,0.6,0],1,0.13); p.poly([-0.85,0.5,-0.65,1,-0.4,0.5],8); p.poly([0.35,0.5,0.65,0.85,0.9,0.5],2)
        case 33: p.box(-0.9,0,1.8,0.8,1); p.oval(0,0.4,0.55,0.28,8); for i in 0..<4 { p.line([-0.6+Double(i)*0.4,0.15,-0.6+Double(i)*0.4,0.7],0,0.06) }; p.poly([-0.3,0.8,0,1,0.3,0.8],2)
        case 34: p.poly([-1,0,-0.55,0.3,0.1,0.15,0.5,0.4,1,0],1); for i in 0..<3 { p.oval(-0.4+Double(i)*0.4,0.5+Double(i)*0.15,0.25,0.15,i%2 == 0 ? 8 : 2) }
        case 35: p.box(-0.8,0,0.4,0.3,1); p.box(0.4,0,0.4,0.3,1); p.poly([-0.9,0.3,-0.5,1,-0.2,0.3],8); p.poly([0.2,0.3,0.5,1,0.9,0.3],8); p.line([-0.5,0.1,0.5,0.1],2,0.1)
        case 36: p.poly([-1,0.1,-0.6,0.6,0.2,0.4,0.8,0.8,1,0.6,0.2,0.1],8); p.line([-0.8,0.1,-0.4,0.5,0,0.2,0.4,0.55],2,0.07); p.poly([0.5,0.8,0.65,1,0.9,0.8],2)
        case 37: p.poly([0,0,-1,0.7,-0.3,0.5,0,1,0.3,0.5,1,0.7],8); p.star(0,0.5,0.35,0.25,4,t*2,2)
        case 38: p.poly([-1,0,-0.7,0.6,-0.2,0.7,0,1,0.3,0.7,0.8,0.6,1,0],1); p.oval(-0.4,0.5,0.12,0.1,2); p.oval(0.4,0.5,0.12,0.1,2); p.poly([-0.5,0.15,0,0.65,0.5,0.15],8)
        case 39: p.star(0,0.5,1,0.5,12,t,8); p.ring(0,0.5,0.55,0.28,2); p.oval(0,0.5,0.3,0.15,5)
        // Wrecking devices: anchors, weights, pendulums, buoy, spikes, hook, hammer, rings, twin weights, bell.
        case 40: p.line([0,1,0,0.2,-0.8,0.1,-1,0.4],0,0.12); p.line([0,0.2,0.8,0.1,1,0.4],0,0.12); p.ring(0,0.8,0.2,0.1,2)
        case 41: p.line([sway,1,0,0.6],0,0.05); p.oval(0,0.3,0.7,0.3,1); p.poly([-0.6,0.3,0.2,0.1,0.5,0.5],8)
        case 42: for i in 0..<4 { p.ring(sway,0.95-Double(i)*0.17,0.12,0.09,0) }; p.poly([-0.5,0,-0.8,0.3,0,0.5,0.8,0.3,0.5,0],1)
        case 43: p.line([0,1,0,0.75],0); p.oval(0,0.4,0.75,0.36,8); p.box(-0.7,0.35,1.4,0.12,5); p.ring(0,0.8,0.13,0.08,1)
        case 44: p.line([0,1,0,0.6],0); p.star(0,0.32,0.9,0.32,8,t,0); p.oval(0,0.32,0.4,0.16,1)
        case 45: p.line([0,1,0,0.65],0); p.poly([-0.2,0.7,0.3,0.7,0.7,0.4,0.65,0.05,0,0,-0.6,0.2,-0.65,0.5,-0.25,0.25,0.2,0.25,0.2,0.5],0)
        case 46: p.line([0,1,0,0.4],2,0.12); p.box(-0.9,0.08,1.8,0.4,0); p.box(-1,0.02,0.25,0.52,2); p.box(0.75,0.02,0.25,0.52,2)
        case 47: p.line([0,1,-0.4,0.55,0,1,0.4,0.55],0); p.ring(-0.4,0.3,0.5,0.28,2); p.ring(0.4,0.3,0.5,0.28,0)
        case 48: p.line([-0.5,1,0.4+sway,0.3,0.5,1,-0.4-sway,0.3],0); p.oval(-0.45-sway,0.2,0.45,0.2,1); p.oval(0.45+sway,0.2,0.45,0.2,2)
        case 49: p.line([0,1,0,0.8],0); p.poly([-0.8,0.1,-0.5,0.7,0,0.85,0.5,0.7,0.8,0.1],2); p.box(-1,0.08,2,0.1,0); p.oval(0,0.06,0.15,0.06,1)
        // Dragons: each creature has its own anatomy, not recolored copies.
        case 50: p.oval(0,0.25,0.6,0.25,9); p.poly([-0.5,0.3,-0.8,0.7,-0.2,0.55,0,1,0.5,0.65,0.7,0.4],9); p.oval(0.25,0.7,0.1,0.07,2); p.poly([0.5,0.4,1,0.25,0.8,0.6],8)
        case 51: p.poly([-0.7,0,-0.7,0.7,-0.4,1,-0.2,0.7,0.6,0.6,0.9,0.3,0.1,0.2,-0.1,0],8); p.line([-0.6,0.8,-0.9,1],5,0.08); p.oval(0.2,0.55,0.1,0.06,2)
        case 52: p.poly([-1,1,-0.8,0.2,0,0.5,0.8,0.2,1,1,0,0.7],2); p.poly([-0.2,0,0.2,0,0.4,0.8,0,1,-0.4,0.8],8); p.oval(0,0.8,0.1,0.06,5)
        case 53: p.line([-0.9,0.1,0.6,0.15,0.8,0.45,-0.5,0.5,-0.6,0.8,0.5,0.9],9,0.24); p.poly([0.3,0.7,0.9,0.8,0.5,1],9); p.oval(0.65,0.87,0.08,0.05,2)
        case 54: p.line([-0.9,0.1,0,0.15,0.5,0.5,0.2,0.8],7,0.25); p.poly([-0.3,0.65,0.3,0.65,0.6,0.8,0.1,0.93],7); p.poly([-0.2,0.8,-0.5,1,0,0.87],5); p.poly([0.3,0.85,0.7,1,0.4,0.75],5)
        case 55: p.poly([-0.8,0,-0.5,0.7,0,1,0.7,0.75,1,0.4,0.3,0.3,0.1,0],3); p.star(-0.3,0.4,0.35,0.2,4,t,2); p.oval(0.5,0.7,0.11,0.06,5); p.poly([0.7,0.45,0.95,0.45,0.8,0.2],5)
        case 56: p.poly([-1,0.85,-0.9,0.1,-0.3,0.4,0,0,0.3,0.4,0.9,0.1,1,0.85,0,0.55],1); p.oval(0,0.7,0.27,0.27,0); p.line([-0.3,0.5,-0.6,0.2,0,0.4,0.6,0.2,0.3,0.5],8,0.07)
        case 57: p.poly([-0.7,0,-0.3,0.5,-0.8,0.9,0,0.65,0.5,1,0.9,0.5,0.4,0.3,0.2,0],6); p.line([-0.4,0.2,0.3,0.4,0,0.6,0.6,0.8],7,0.08); p.oval(0.55,0.7,0.1,0.05,5)
        case 58: p.poly([-1,0,-0.7,0.6,-0.9,1,-0.3,0.8,0,0.95,0.6,0.8,1,0.45,0.2,0.3,0,0],1); p.poly([-0.65,0.5,-0.3,0.7,0,0.5,-0.3,0.3],7); p.oval(0.55,0.68,0.1,0.05,3)
        case 59: p.poly([-1,0.15,-0.9,0.75,-0.4,0.5,0,0.1,0.4,0.5,0.9,0.75,1,0.15],7); p.oval(0,0.62,0.42,0.3,3); p.poly([-0.45,0.85,-0.4,1,-0.2,0.9,0,1,0.2,0.9,0.4,1,0.45,0.85],2); p.oval(-0.15,0.7,0.08,0.06,5); p.oval(0.15,0.7,0.08,0.06,5)
        // Spikes: radial, skeletal, thorned, fanged, quilled, jagged, needles, spears, tentacles, crown.
        case 60: p.star(0,0.4,1,0.4,11,t*0.3,7); p.oval(0,0.4,0.5,0.25,1)
        case 61: for x in [-0.6,0.0,0.6] { p.poly([x-0.2,0,x+0.2,0,x,0.9],5); p.oval(x,0.15,0.22,0.12,5) }
        case 62: p.line([-0.8,0,-0.4,0.4,0.3,0.55,0.7,1],9,0.15); for i in 0..<4 { let x = -0.6+Double(i)*0.4; p.poly([x,Double(i)*0.2,x-0.3,0.5+Double(i)*0.15,x+0.2,0.2+Double(i)*0.2],7) }
        case 63: p.poly([-1,0,-0.7,0.9,-0.2,0.25,-0.4,0],5); p.poly([0.4,0,0.2,0.25,0.7,0.9,1,0],5); p.box(-1,0,2,0.12,3)
        case 64: for i in 0..<7 { let x = -0.9+Double(i)*0.3; p.poly([x,0,x+0.12,0,x+sway,0.6+0.4*sin(Double(i)*0.5)],0) }
        case 65: p.poly([-1,0,-0.9,0.5,-0.6,0.3,-0.4,1,-0.1,0.4,0.3,0.8,0.5,0.4,0.9,0.9,1,0],1); p.line([-0.4,0,-0.4,0.8,0.3,0.3,0.9,0.7],7)
        case 66: for x in [-0.7,0.0,0.7] { p.poly([x-0.12,0.15,x,1,x+0.12,0.15,x,0],9); p.line([x,0.1,x,0.9],4,0.025) }
        case 67: for i in 0..<4 { let x = -0.75+Double(i)*0.5; p.line([x,0,x,0.8],2,0.07); p.poly([x-0.2,0.65,x,1,x+0.2,0.65],0) }
        case 68: for x in [-0.7,0.0,0.7] { p.line([x,0,x+0.12,0.4,x-0.12,0.8,x+0.18,1],7,0.15); p.poly([x,0.55,x+0.35,0.7,x+0.05,0.8],5) }
        case 69: p.poly([-1,0,-1,0.85,-0.6,0.5,-0.3,1,0,0.55,0.3,1,0.6,0.5,1,0.85,1,0],7); p.ring(0,0.2,0.7,0.15,2)
        // Crushers: slab, crate, boot, twin piston, mallet, ram, anchor press, foot, fortress, jaws.
        case 70: p.box(-0.8,0.1,1.6,0.7); p.line([-0.6,0.7,0,0.5,-0.2,0.2],1); p.box(-1,0,2,0.12,2)
        case 71: p.box(-0.9,0.05,1.8,0.9,2); p.line([-0.85,0.1,0.85,0.9,-0.85,0.9,0.85,0.1,-0.85,0.1],1,0.12)
        case 72: p.poly([-0.6,1,0.2,1,0.2,0.4,0.9,0.3,1,0,-0.8,0,-0.8,0.3,-0.6,0.4],1); p.box(-0.85,0,1.85,0.1,0)
        case 73: p.line([-0.5,1,-0.5,0.5,0.5,1,0.5,0.5],0,0.12); p.box(-1,0,0.9,0.55,1); p.box(0.1,0.2,0.9,0.55,2)
        case 74: p.line([0,1,0,0.6],2,0.18); p.poly([-1,0.1,-0.85,0.65,0.85,0.65,1,0.1],0); p.star(0,0.4,0.25,0.18,4,0,2)
        case 75: p.poly([-1,0.1,-0.7,0.7,0,1,0.7,0.7,1,0.1,0.5,0,-0.5,0],1); p.ring(-0.55,0.6,0.3,0.2,2); p.ring(0.55,0.6,0.3,0.2,2); p.poly([-0.2,0.3,0,0.05,0.2,0.3],0)
        case 76: p.box(-0.9,0,1.8,0.75,0); p.line([0,0.7,0,0.15,-0.6,0.4,0,0.15,0.6,0.4],1,0.09); p.ring(0,0.7,0.13,0.08,2)
        case 77: p.poly([-0.6,1,0.6,1,0.7,0.35,1,0.1,0.8,0,-0.8,0,-1,0.1,-0.7,0.35],7); for i in 0..<4 { p.box(-0.8+Double(i)*0.4,0,0.3,0.23,0) }
        case 78: p.poly([-1,0,-1,0.85,-0.65,0.85,-0.65,0.65,-0.25,0.65,-0.25,1,0.25,1,0.25,0.65,0.65,0.65,0.65,0.85,1,0.85,1,0],1); p.box(-0.25,0.05,0.5,0.4,8)
        case 79: p.poly([-1,0.1,-0.8,0.5,-0.4,0.15,0,0.5,0.4,0.15,0.8,0.5,1,0.1],0); p.poly([-1,0.9,-0.8,0.5,-0.4,0.85,0,0.5,0.4,0.85,0.8,0.5,1,0.9],1)
        // Electrical devices: coil, gate, rod, arc, fork, rings, cage, vortex, crown, winged bolt.
        case 80: p.line([0,0,0,1],1,0.12); for i in 0..<4 { p.ring(0,0.15+Double(i)*0.23,0.65,0.09,6) }
        case 81: p.line([-0.8,0,-0.8,1,0.8,1,0.8,0],1,0.15); p.line([-0.8,0.7,-0.3,0.45,0,0.75,0.3,0.4,0.8,0.7],6,0.09)
        case 82: p.poly([-0.2,0,-0.2,0.7,-0.6,0.7,0,1,0.6,0.7,0.2,0.7,0.2,0],2); p.star(0,0.85,0.7,0.15,6,t*2,6)
        case 83: p.oval(-0.7,0.4,0.25,0.3,1); p.oval(0.7,0.4,0.25,0.3,1); p.line([-0.7,0.5,-0.4,1,0,0.7,0.4,1,0.7,0.5],7,0.1); p.line([-0.7,0.4,0,0,0.7,0.4],6,0.07)
        case 84: p.line([0,0,0,0.8,-0.6,1,0,0.65,0.6,1],2,0.12); p.star(-0.6,0.85,0.3,0.14,4,t,6); p.star(0.6,0.85,0.3,0.14,4,-t,6)
        case 85: p.ring(0,0.5,0.9,0.45,7); p.ring(0,0.5,0.55,0.28,6); p.poly([-0.15,1,0.1,0.6,-0.1,0.6,0.15,0,0.3,0.5,0.1,0.5],2)
        case 86: for x in [-0.8,-0.4,0.0,0.4,0.8] { p.line([x,0,x,1],6,0.04) }; p.line([-1,0.1,1,0.1,1,0.9,-1,0.9,-1,0.1],1,0.14); p.star(0,0.5,0.35,0.25,4,t*2,7)
        case 87: for i in 0..<4 { p.ring(sin(t+Double(i))*0.2,0.1+Double(i)*0.25,0.3+Double(i)*0.2,0.1,i%2 == 0 ? 6 : 7) }
        case 88: p.poly([-1,0,-0.8,1,-0.4,0.4,0,0.9,0.4,0.4,0.8,1,1,0],2); p.line([-0.8,0.8,0,0.3,0.8,0.8],6,0.08)
        case 89: p.poly([-1,1,-0.2,0.65,-0.4,0.9,0.3,0.65,0,0.5,1,1,0.6,0.2,0.2,0.3,0,0,-0.3,0.4,-0.8,0.2],6); p.line([0,1,-0.2,0.6,0.2,0.5,0,0],5,0.08)
        // Ice: shard, fan, fang, snowflake, spire, comet, diamond, prism, blizzard, heart.
        case 90: p.poly([-0.7,0,-0.45,0.7,0.1,1,0.6,0.3,0.7,0],6); p.line([-0.6,0.05,0.1,1,0.15,0],5)
        case 91: for i in 0..<5 { let x = -0.9+Double(i)*0.45; p.poly([-0.12,0,x,0.6+0.4*sin(Double(i)*0.7),0.12,0],i%2 == 0 ? 6 : 5) }
        case 92: p.poly([-0.7,1,0.2,0.9,0.7,0.5,0.1,0,-0.1,0.55],6); p.poly([-0.7,1,0.1,0.65,0.1,0],5)
        case 93: for i in 0..<6 { let a = Double(i) * .pi / 3 + t * 0.2; p.line([0,0.5,cos(a)*0.95,0.5+sin(a)*0.45],6,0.06); p.star(cos(a)*0.6,0.5+sin(a)*0.3,0.23,0.12,3,a,5) }
        case 94: p.poly([-0.8,0,-0.5,0.6,-0.2,0.5,0,1,0.3,0.5,0.5,0.8,0.8,0],6); p.line([0,0,0,1],5,0.08)
        case 95: p.poly([-0.8,0.1,0.7,1,0.5,0.4,1,0.5,-0.2,0],6); p.star(-0.4,0.2,0.55,0.25,6,t*2,5)
        case 96: p.poly([-1,0.65,-0.5,1,0.5,1,1,0.65,0,0],6); p.line([-1,0.65,1,0.65,0,0,-0.5,1,0.5,1,0,0],5,0.04)
        case 97: p.poly([-0.7,0.2,-0.7,0.8,0,1,0.7,0.8,0.7,0.2,0,0],6); p.poly([0,0,0,1,0.7,0.8,0.7,0.2],7); p.line([-0.7,0.8,0,0.6,0.7,0.8],5)
        case 98: p.poly([-1,0,-0.9,0.9,-0.5,0.5,0,1,0.5,0.5,0.9,0.9,1,0],6); p.star(0,0.45,0.35,0.2,6,t,5)
        case 99: p.poly([0,0,-1,0.55,-0.8,0.9,-0.4,1,0,0.75,0.4,1,0.8,0.9,1,0.55],6); p.line([0,0,0,0.75,-0.4,1,0,0.4,1,0.55],5,0.05)
        default: break
        }
        return p.marks
    }

    static func projectile(_ attack: AttackProfile, time: Double) -> [EncounterMark] {
        var p = EncounterPen()
        // Weapon body, each with a very different silhouette.
        switch attack.weapon {
        case 0: p.oval(0,0.5,0.58,0.3,1); p.oval(-0.15,0.6,0.18,0.1,0); p.line([0.3,0.75,0.5,1],2)
        case 1: p.line([0,0,0,1],2,0.12); p.poly([-0.5,0.6,0,1,0.5,0.6,0.15,0.7,0,0.5,-0.15,0.7],0)
        case 2: p.star(0,0.5,0.8,0.4,10,time*4,0); p.ring(0,0.5,0.3,0.15,3)
        case 3: p.poly([-0.6,0,-0.8,0.5,-0.4,1,0,0.65,0.4,1,0.8,0.5,0.6,0],8); p.oval(0,0.25,0.35,0.2,2)
        case 4: p.line([0,1,0,0.15,-0.7,0.3,-0.9,0.6],0,0.13); p.line([0,0.15,0.7,0.3,0.9,0.6],0,0.13); p.ring(0,0.8,0.18,0.1,2)
        case 5: p.poly([0,0,-0.7,0.3,-0.9,0.8,-0.3,0.6,0,1,0.3,0.6,0.9,0.8,0.7,0.3],3); p.oval(-0.22,0.55,0.1,0.08,2); p.oval(0.22,0.55,0.1,0.08,2)
        case 6: p.poly([-0.15,0,-0.2,0.4,-0.7,0.65,-0.2,0.6,0,1,0.2,0.6,0.7,0.65,0.2,0.4,0.15,0],7)
        case 7: p.poly([-0.65,0,-0.8,0.5,-0.5,0.8,0,1,0.7,0.7,0.9,0.2,0.2,0],1); p.line([-0.5,0.7,0,0.6,-0.1,0.2,0.7,0.3],8,0.12)
        case 8: p.poly([0.2,1,-0.6,0.45,-0.1,0.45,-0.3,0,0.7,0.6,0.2,0.6],6)
        default: p.poly([0,0,-0.6,0.65,-0.3,1,0.3,1,0.6,0.65],6); p.line([0,0,0,1,-0.6,0.65,0.6,0.65],5,0.04)
        }
        // Structural flight fittings: ten visibly different outlines, not tint swaps.
        switch attack.trajectory {
        case 0: p.line([-0.5,0,-0.5,-0.2,0.5,-0.2,0.5,0],2)
        case 1: p.poly([-0.8,0.3,-1,0.9,-0.5,0.65],2); p.poly([0.8,0.3,1,0.9,0.5,0.65],2)
        case 2: p.line([-1,0.1,1,0.1],5,0.1)
        case 3: p.ring(0,0.5,0.95,0.22,7)
        case 4: p.poly([-0.6,0.2,-1,0.5,-0.6,0.8],3); p.poly([0.6,0.2,1,0.5,0.6,0.8],3)
        case 5: p.line([-1,0.8,-0.9,0.1,0,-0.15,0.9,0.1,1,0.8],2,0.08)
        case 6: p.box(-1,0.25,0.25,0.5,0); p.box(0.75,0.25,0.25,0.5,0)
        case 7: p.oval(cos(time*3)*0.9,0.5+sin(time*3)*0.4,0.16,0.09,7); p.ring(0,0.5,1,0.5,6)
        case 8: p.poly([-1,0.8,-0.5,0.3,-0.5,0.8],0); p.poly([1,0.8,0.5,0.3,0.5,0.8],0)
        default: p.poly([-0.5,0,-0.3,-0.25,0,-0.1,0.3,-0.25,0.5,0],8)
        }
        return p.marks
    }
}


/// Aim is captured once at firing; moving afterwards never moves the target.
enum LabProjectileKind: CaseIterable {
    case bomb, bullet
    var title: String { self == .bomb ? "BOMB" : "BULLET" }
    var duration: Double { self == .bomb ? 1.6 : 1.2 }
    var radius: Double { self == .bomb ? 0.45 : 0.18 }
}
struct AimedProjectile {
    let kind: LabProjectileKind
    let targetLane: Int
    let targetHeight: Double
    init(kind: LabProjectileKind, playerLane: Int, playerHeight: Double) {
        self.kind = kind
        targetLane = max(0, min(2, playerLane))
        targetHeight = max(0, playerHeight) + 0.65
    }
    func hits(playerLane: Int, playerHeight: Double) -> Bool {
        playerLane == targetLane && playerHeight < targetHeight + kind.radius &&
        playerHeight + 1.15 > targetHeight - kind.radius
    }
}
