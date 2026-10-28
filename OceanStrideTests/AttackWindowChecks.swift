import Foundation

@main
struct AttackWindowChecks {
    static func main() {
        var markedLaneAttacks = 0
        for level in 1...100 {
            let plan = LevelPlan(number: level, seed: 42)
            let flight = plan.attack.duration(speed: plan.projectileSpeed)
            var nextFire = max(5, plan.firingInterval)
            var landed = 0
            var volley = 0
            let end = min(plan.finish, plan.platforms[min(8, plan.platforms.count - 1)].end)
            var time = 0.0
            while 2 + time * plan.speed < end {
                if time >= nextFire {
                    let impact = 2 + (time + flight) * plan.speed
                    let targets = plan.attackLanes(at: impact)
                    if !targets.isEmpty {
                        let stone = plan.platforms.first { impact >= $0.start && impact <= $0.end }!
                        let selected = targets[volley % targets.count]
                        if selected == stone.safeLane { markedLaneAttacks += 1 }
                        precondition(targets.count <= 2)
                        landed += 1
                        volley += 1
                        nextFire = time + plan.firingInterval
                    }
                }
                time += 1.0 / 30
            }
            precondition(landed > 0, "No attacks reach level \(level)")
        }
        precondition(markedLaneAttacks > 0)
        print("Passed: attacks occur in all 100 levels, including the marked lane; every volley leaves a dodge lane.")
    }
}
