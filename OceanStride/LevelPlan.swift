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

struct Barrier {
    let id: Int
    let lane: Int
    let position: Double
    var hasFire = false
    static let height = 1.3
    static let halfLength = 1.2
    func contains(distance: Double, lane: Int) -> Bool {
        self.lane == lane && abs(distance - position) <= Self.halfLength
    }
    func canLand(previousHeight: Double, height: Double) -> Bool {
        // Catch near-edge landings even when the feet crossed the top just before
        // entering the footprint. Match this tolerance to side-hit detection.
        !hasFire && previousHeight >= Self.sideHitHeight && height <= Self.height + 0.08 && height < previousHeight
    }
    static let sideHitHeight = height - 0.45
    func causesDamage(height: Double, supported: Bool) -> Bool {
        if hasFire { return height < Self.height + 0.85 }
        return !supported && height < Self.sideHitHeight
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
    var finish: Double { platforms.last!.end - 6 }
    // Reduce frequency by 10% per level, but keep attacks at most ten seconds apart.
    var firingInterval: Double {
        if (91...100).contains(number) { return 3 }
        return min(10, 3.8 / pow(0.9, Double(number - 1)))
    }
    var projectileSpeed: Double { min(34, 18 + Double(number - 1) * 1.5) }
    var hasHelicopters: Bool { number >= 4 }
    var volleySize: Int { number > 70 ? 2 : 1 }

    init(number: Int) {
        self.number = max(1, number)
        paceScale = self.number < 10 ? 1 : 0.9
        speed = (10 + 9 * (1 - exp(-Double(self.number - 1) / 28))) * paceScale * 0.9
        var stones: [StonePlatform] = []
        var cursor = 0.0
        // Thin barriers evenly across the whole level, keeping retry layouts identical.
        // Level 35 belongs to the 50% reduction range; counts round up.
        let barrierStride = self.number < 10 ? 1 : ((35...70).contains(self.number) ? 2 : 4)
        var barrierOrdinal = 0
        var retainedBarrierOrdinal = 0
        for index in 0..<(5 + (self.number - 1) * 2) {
            let standardLength = max(17, 28 - Double(self.number - 1))
            // The runner starts at distance 2: allow at least four seconds before the first gap.
            let length = index == 0 ? max(standardLength * 1.5, 2 + speed * 4) : standardLength
            // Every gap remains shorter than the distance of one jump.
            let gap = min(6.5, 3.4 + Double(self.number - 1) * 0.3, speed * 1.05 * 0.75)
            let isFinish = index == 4 + (self.number - 1) * 2
            let broken = !isFinish && index > 0 && (self.number >= 3 || index % 3 == 2)
            let obstacle = !isFinish && index > 0 && (self.number >= 2 || index % 2 == 1)
            let brokenLane = broken ? (index + self.number) % 3 : nil
            let obstacleLane = obstacle ? (index + self.number + 1) % 3 : nil
            let safeLane = (index + self.number + 2) % 3
            var barriers: [Barrier] = []
            var jewels = (0..<2).map { offset in
                JewelPickup(id: index * 100 + offset, lane: safeLane,
                            position: cursor + 3 + Double(offset) * 2, elevation: 0.8, value: 1)
            }
            if let obstacleLane {
                let rows = min(3, 1 + (self.number - 1) / 3)
                for row in 0..<rows {
                    let position = cursor + length * (Double(row + 1) / Double(rows + 1))
                    barriers.append(Barrier(id: index * 10 + row, lane: obstacleLane, position: position))
                    // A jump over a barrier earns a three-jewel arc, worth more than the safe route.
                    for offset in 0..<3 {
                        jewels.append(JewelPickup(id: index * 100 + 10 + row * 3 + offset,
                            lane: obstacleLane, position: position + Double(offset - 1),
                            elevation: 1.9, value: self.number >= 5 ? 3 : 2))
                    }
                    if self.number >= 7 && row != rows / 2 {
                        barriers.append(Barrier(id: index * 10 + 5 + row, lane: (obstacleLane + 2) % 3, position: position))
                    }
                }
            }
            barriers = barriers.filter { _ in
                defer { barrierOrdinal += 1 }
                return barrierOrdinal % barrierStride == 0
            }
            // Two safe tops followed by one fire top, after density reduction.
            // Even sparse levels keep their first two barriers landable.
            barriers = barriers.map { barrier in
                var result = barrier
                result.hasFire = retainedBarrierOrdinal % 3 == 2
                retainedBarrierOrdinal += 1
                return result
            }
            if let brokenLane {
                for offset in 0..<3 {
                    jewels.append(JewelPickup(id: index * 100 + 30 + offset, lane: brokenLane,
                        position: cursor + length * 0.5 + Double(offset - 1) * 1.5, elevation: 1.8, value: 3))
                }
            }
            // One deterministic rare pack every other level starting at level 11; retries keep the same layout.
            let medicalIndex = 1 + (self.number * 3) % (3 + (self.number - 1) * 2)
            let medicalLane = self.number >= 11 && self.number % 2 == 1 && index == medicalIndex && !isFinish ? safeLane : nil
            stones.append(StonePlatform(start: cursor, length: length,
                brokenLane: brokenLane, obstacleLane: obstacleLane,
                jewelLane: safeLane, barriers: barriers, jewels: jewels, medicalLane: medicalLane))
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
