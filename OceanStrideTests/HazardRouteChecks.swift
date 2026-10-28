import Foundation

@main
struct HazardRouteChecks {
    static func main() {
        precondition(HazardVariant.names.count == 100)
        precondition(Set(HazardVariant.names).count == 100)
        var fingerprints = Set<String>()
        for seed in 0..<64 {
            for level in 1...100 {
                let plan = LevelPlan(number: level, seed: UInt64(seed))
                let barriers = plan.platforms.flatMap(\.barriers)
                precondition(barriers.contains { $0.variantID == level - 1 })
                precondition(!plan.attackLanes.contains(plan.safeLane))
                precondition(Set(plan.attackLanes).count == 2)
                precondition(plan.platforms[1].barriers.allSatisfy(\.isLandable))
                for (index, stone) in plan.platforms.enumerated() {
                    precondition(stone.brokenLane != plan.safeLane)
                    precondition(stone.barriers.allSatisfy { $0.lane != plan.safeLane })
                    for lane in plan.attackLanes {
                        let laneBarriers = stone.barriers.filter { $0.lane == lane }.sorted { $0.position < $1.position }
                        if index > 0 && index < plan.platforms.count - 1 {
                            precondition((1...2).contains(laneBarriers.count))
                        }
                        for barrier in laneBarriers {
                            precondition(barrier.position - Barrier.halfLength > stone.start + plan.speed * 0.4)
                            precondition(barrier.position + Barrier.halfLength < stone.end - plan.speed * 0.4)
                            if lane == stone.brokenLane {
                                precondition(abs(barrier.position - (stone.start + stone.length / 2)) > 2.4 + Barrier.halfLength)
                            }
                            if barrier.isLandable {
                                precondition(barrier.canLand(previousHeight: barrier.topHeight + 0.1, height: barrier.topHeight - 0.1))
                                precondition(!barrier.causesDamage(height: barrier.topHeight, supported: true, time: 1))
                            }
                        }
                        if laneBarriers.count == 2 {
                            precondition((laneBarriers[1].position - laneBarriers[0].position) / plan.speed > 1.05)
                        }
                    }
                    guard index < plan.platforms.count - 1 else { continue }
                    let next = plan.platforms[index + 1]
                    let center = (stone.end + next.start) / 2
                    // Construct an actual one-jump trajectory along the marked lane,
                    // sampled at 120 Hz. Water contact must stay clear on both edges.
                    for frame in 0...126 {
                        let t = Double(frame) / 120
                        let d = center + (t - 0.525) * plan.speed
                        let h = sin(t / 1.05 * .pi) * 2.7
                        if d > stone.end && d < next.start { precondition(h > 0.25) }
                        let over = plan.platforms[index...min(index + 1, plan.platforms.count - 1)]
                        for platform in over {
                            precondition(!platform.barriers.contains { $0.contains(distance: d, lane: plan.safeLane) })
                        }
                    }
                    precondition(next.length / plan.speed > 2.5) // time to recover before next gap
                }
                if level == 50 {
                    fingerprints.insert(barriers.map { "\($0.lane):\($0.position):\($0.variantID!)" }.joined(separator: ","))
                }
                let repeatPlan = LevelPlan(number: level, seed: UInt64(seed))
                precondition(barriers.map(\.position) == repeatPlan.platforms.flatMap(\.barriers).map(\.position))
            }
        }
        precondition(fingerprints.count == 64)
        // Every animated variant has a safe phase, active phase and a visible warning.
        for id in 20..<100 {
            let b = Barrier(id: id, lane: 0, position: 0, variantID: id)
            precondition(!b.isLandable)
            precondition(b.active(at: 0))
            precondition(!b.active(at: b.variant!.period * 0.65))
            precondition(b.warning(at: b.variant!.period * 0.9))
            precondition(b.causesDamage(height: 0, supported: false, time: 0))
            precondition(!b.causesDamage(height: 0, supported: false, time: b.variant!.period * 0.65))
        }
        print("Passed: 100 distinct variants, 6,400 seeded levels, complete safe-lane jump routes, enemy exclusions, density/spacing, hazard phases and reproducible randomness.")
    }
}
