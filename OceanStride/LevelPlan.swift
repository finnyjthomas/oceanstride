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
        return cycle(at: time) < variant.duty
    }
    func warning(at time: Double) -> Bool { !active(at: time) && cycle(at: time) > 0.78 }
    func damageBand(at time: Double) -> ClosedRange<Double>? {
        guard let v = variant, !v.landable, active(at: time) else { return nil }
        switch v.family {
        case .blade: return (0.15 + Double(v.tier % 3) * 0.35)...(1.05 + Double(v.tier % 3) * 0.35)
        case .wrecking: return 0.25...(1.55 + Double(v.tier) * 0.04)
        case .crusher: return 0...2.8
        case .storm: return 0...2.4
        default: return 0...(v.height + 0.75)
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
    let safeLane: Int
    var signature: HazardVariant { HazardVariant(id: (number - 1) % 100) }
    var attackLanes: [Int] { (0...2).filter { $0 != safeLane } }
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
        let safeLane = rng.int(3)
        self.safeLane = safeLane
        let occupied = (0...2).filter { $0 != safeLane }
        let featuredID = (self.number - 1) % 100
        var stones: [StonePlatform] = []
        var cursor = 0.0
        for index in 0..<(5 + (self.number - 1) * 2) {
            // Preserve a full jump-recovery window at both edges and between rows.
            let standardLength = max(30, speed * 2.7)
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
                    let count = rng.int(2) + 1
                    for row in 0..<count {
                        // Do not put a landing surface on a broken patch.
                        let fraction = count == 1 ? (brokenLane == obstacleLane ? 0.27 : 0.5) : (row == 0 ? 0.27 : 0.73)
                        let position = cursor + length * fraction + (rng.unit() - 0.5) * 0.6
                        // The first interior platform teaches two safe tops; later
                        // platforms always include the level's signature hazard.
                        let kind = index == 1 ? rng.int(20) :
                            (slot == 0 && row == 0 ? featuredID : (rng.int(4) == 0 ? rng.int(20) : featuredID))
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
            stones.append(StonePlatform(start: cursor, length: length, brokenLane: brokenLane,
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
