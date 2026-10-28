import Foundation

@main
struct LabChecks {
    static func main() {
        for kind in LabProjectileKind.allCases {
            for lane in 0...2 {
                let shot = AimedProjectile(kind:kind,playerLane:lane,playerHeight:0)
                precondition(shot.targetLane == lane)
                precondition(shot.hits(playerLane:lane,playerHeight:0))
                precondition(!shot.hits(playerLane:(lane+1)%3,playerHeight:0))
                precondition(!shot.hits(playerLane:lane,playerHeight:2.7))
                let airborneShot = AimedProjectile(kind:kind,playerLane:lane,playerHeight:2.7)
                precondition(airborneShot.hits(playerLane:lane,playerHeight:2.7))
                precondition(!airborneShot.hits(playerLane:lane,playerHeight:0))
                precondition(shot.targetLane == lane && shot.targetHeight == 0.65) // immutable after dodging
            }
        }
        var shotCount = 0
        for seed in 0..<32 {
            for level in 1...100 {
                let plan = LevelPlan(number:level,seed:UInt64(seed))
                let barriers = plan.platforms.flatMap(\.barriers)
                precondition(Set(barriers.map { $0.variant!.family.rawValue }) == Set([1,2,3,4,5]))
                let again = LevelPlan(number:level,seed:UInt64(seed))
                precondition(barriers.map(\.variantID) == again.platforms.flatMap(\.barriers).map(\.variantID))
                precondition(barriers.map(\.position) == again.platforms.flatMap(\.barriers).map(\.position))
                for stone in plan.platforms {
                    precondition(stone.barriers.allSatisfy { $0.lane != stone.safeLane })
                    precondition(stone.brokenLane != stone.safeLane)
                    for lane in 0...2 { precondition(stone.barriers.filter { $0.lane == lane }.count <= 2) }
                    for step in 0...20 {
                        let position = stone.start + stone.length * Double(step)/20
                        for target in 0...2 {
                            for escape in plan.escapeLanes(at:position,from:target) {
                                precondition(abs(escape-target) == 1)
                                precondition(!stone.barriers.contains { $0.lane == escape && abs($0.position-position) < Barrier.halfLength+plan.speed*0.45 })
                                precondition(!(stone.brokenLane == escape && abs(position-stone.start-stone.length/2) < 2.4+plan.speed*0.45))
                                precondition(position > stone.start+plan.speed*0.8 && position < stone.end-plan.speed*0.8)
                            }
                        }
                    }
                }
                // A runner following the open route must still receive aimed shots.
                if seed == 0 {
                    var time = 0.0, nextFire = max(5,plan.firingInterval), landed = 0
                    let end = min(plan.finish,plan.platforms[min(8,plan.platforms.count-1)].end)
                    while 2+time*plan.speed < end {
                        let d = 2+time*plan.speed
                        let stone = plan.platforms.last { $0.start <= d }!
                        let kind: LabProjectileKind = landed%2 == 0 ? .bomb : .bullet
                        if time >= nextFire && !plan.escapeLanes(at:d+plan.speed*kind.duration,from:stone.safeLane).isEmpty {
                            landed += 1; nextFire = time+plan.firingInterval
                        }
                        time += 1.0/30
                    }
                    precondition(landed > 0,"No aimed attacks at level \(level)")
                    shotCount += landed
                }
            }
        }
        print("Passed: fixed player-lane/height targeting, dodge/jump evasion, 3,200 mixed seeded levels, all five families per level, sparse density, open lanes, safe escape windows, and aimed attacks on all 100 levels (\(shotCount) volleys).")
    }
}
