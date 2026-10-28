import Foundation

@main
struct LevelPlanChecks {
    static func main() {
        let safeBarrier = Barrier(id: 1, lane: 1, position: 10)
        let fireBarrier = Barrier(id: 2, lane: 1, position: 10, hasFire: true)
        precondition(safeBarrier.canLand(previousHeight: 1.5, height: 1.2))
        precondition(!safeBarrier.canLand(previousHeight: 1.2, height: 1.5))
        precondition(!safeBarrier.canLand(previousHeight: 0.5, height: 0.2))
        // Regression: crossing the top between frames just before entering the
        // barrier used to turn a visually valid landing into a side hit.
        precondition(safeBarrier.canLand(previousHeight: 1.24, height: 1.05))
        precondition(safeBarrier.canLand(previousHeight: 0.95, height: 0.78))
        precondition(!safeBarrier.causesDamage(height: Barrier.height, supported: true))
        precondition(!safeBarrier.causesDamage(height: 0.78, supported: true))
        precondition(safeBarrier.causesDamage(height: 0, supported: false))
        precondition(fireBarrier.causesDamage(height: Barrier.height, supported: true))
        precondition(!fireBarrier.canLand(previousHeight: 1.5, height: 1.2))
        precondition(safeBarrier.contains(distance: 10.8, lane: 1))
        precondition(!safeBarrier.contains(distance: 10, lane: 0))
        precondition(!safeBarrier.contains(distance: 11.3, lane: 1))
        var boost = JewelBoost()
        var balance = 99
        precondition(!boost.activate(jewels: &balance) && balance == 99 && !boost.isActive)
        balance = 200
        precondition(boost.activate(jewels: &balance) && balance == 100)
        precondition(boost.remaining == 5 && boost.speedMultiplier == 3)
        // A held/repeated activation cannot charge again or extend an active use.
        precondition(!boost.activate(jewels: &balance) && balance == 100 && boost.remaining == 5)
        boost.advance(2)
        boost.pause()
        precondition(!boost.isActive && boost.remaining == 3 && boost.speedMultiplier == 1)
        boost.advance(30)
        precondition(boost.remaining == 3)
        precondition(boost.activate(jewels: &balance) && balance == 100 && boost.remaining == 3)
        boost.advance(2.9)
        precondition(boost.isActive)
        boost.advance(0.11)
        precondition(!boost.isActive && boost.speedMultiplier == 1 && boost.remaining == 0)
        precondition(boost.activate(jewels: &balance) && balance == 0)
        boost = JewelBoost()
        precondition(!boost.isActive && !boost.activate(jewels: &balance))
        boost = JewelBoost(remaining: 2.5)
        precondition(!boost.isActive && boost.activate(jewels: &balance) && balance == 0)
        precondition(boost.remaining == 2.5)
        for number in 1...100 {
            let plan = LevelPlan(number: number)
            precondition(plan.platforms.count == 5 + (number - 1) * 2)
            precondition(plan.speed <= 19 && plan.firingInterval >= 1.1)
            precondition(plan.platforms.last!.brokenLane == nil && plan.platforms.last!.obstacleLane == nil)
            precondition(plan.hasHelicopters == (number >= 4))
            precondition(plan.volleySize == (number > 70 ? 2 : 1))
            precondition(plan.finish < plan.platforms.last!.end)
            precondition(plan.platforms.last!.barriers.isEmpty)
            let first = plan.platforms[0]
            precondition(first.length >= plan.platforms[1].length * 1.5)
            precondition((first.end - 2) / plan.speed >= 4 - 0.000001)
            precondition(first.brokenLane == nil && first.barriers.isEmpty)
            precondition(plan.platforms.filter { $0.medicalLane != nil }.count == (number >= 11 && number % 2 == 1 ? 1 : 0))
            let allJewels = plan.platforms.flatMap(\.jewels)
            let allBarriers = plan.platforms.flatMap(\.barriers)
            let originalSpeed = 10 + 9 * (1 - exp(-Double(number - 1) / 28))
            let paceFraction = number < 10 ? 1.0 : 0.9
            precondition(abs(plan.speed / originalSpeed - paceFraction * 0.9) < 0.000001)
            let expectedInterval = number >= 91 ? 3.0 : min(10, 3.8 / pow(0.9, Double(number - 1)))
            precondition(abs(plan.firingInterval - expectedInterval) < 0.000001)
            precondition(plan.firingInterval <= 10)
            // Even advanced levels must fire repeatedly during their opening thirty seconds.
            let firstAttack = max(5, plan.firingInterval)
            precondition(1 + Int((30 - firstAttack) / plan.firingInterval) >= 3)
            precondition(allBarriers.count >= (plan.platforms.count - 2) * 2)
            precondition(allBarriers.count <= (plan.platforms.count - 2) * 4)
            precondition(allBarriers.map(\.id) == LevelPlan(number: number).platforms.flatMap(\.barriers).map(\.id))
            precondition(Set(allJewels.map(\.id)).count == allJewels.count)
            precondition(Set(allBarriers.map(\.id)).count == allBarriers.count)
            precondition(plan.crossingShips.isEmpty == (number < 6))
            for ship in plan.crossingShips {
                let before = plan.platforms[ship.id], after = plan.platforms[ship.id + 1]
                precondition(ship.position > before.end && ship.position < after.start)
                precondition(ship.lateralPosition(distance: ship.position, speed: plan.speed) == 0)
                precondition(ship.supports(distance: ship.position, x: 0, speed: plan.speed))
                for lane in 0...2 {
                    precondition(ship.supports(distance: ship.position, x: Double(lane - 1) * 2 / 3, speed: plan.speed))
                }
                precondition(!ship.supports(distance: ship.position + ship.halfLength + 0.3, x: 0, speed: plan.speed))
                precondition(!ship.supports(distance: ship.position, x: 2, speed: plan.speed))
                // A rider carried by the boat remains supported throughout the deck's depth.
                for step in -10...10 {
                    let d = ship.position + Double(step) * 0.1
                    let carriedX = ship.lateralPosition(distance: d, speed: plan.speed)
                    precondition(ship.supports(distance: d, x: carriedX, speed: plan.speed))
                }
                // Simulate a jump centered on the ship at 120 Hz, including both water edges.
                for frame in 0...126 {
                    let time = Double(frame) / 120
                    let position = ship.position + (time - 0.525) * plan.speed
                    let height = sin(time / 1.05 * .pi) * 2.7
                    if position > before.end && position < after.start { precondition(height > 0.25) }
                    if abs(position - ship.position) < 0.7 { precondition(height > 1.35) }
                }
            }
            for (i, stone) in plan.platforms.enumerated() {
                precondition((0...2).contains(stone.jewelLane))
                let safeLanes = (0...2).filter { candidate in
                    candidate != stone.brokenLane && !stone.barriers.contains { $0.lane == candidate }
                }
                precondition(!safeLanes.isEmpty)
                if let medicalLane = stone.medicalLane { precondition(safeLanes.contains(medicalLane)) }
                for jewel in stone.jewels {
                    precondition(jewel.position > stone.start && jewel.position < stone.end)
                    precondition((1...3).contains(jewel.value))
                    if jewel.value > 1 { precondition(jewel.elevation > 1.5) }
                }
                for barrier in stone.barriers {
                    precondition(barrier.position > stone.start + 2 && barrier.position < stone.end - 2)
                    precondition(stone.jewels.filter { $0.lane == stone.jewelLane && $0.value == 1 }.count == 2)
                }
                precondition(stone.brokenLane != plan.safeLane)
                if i > 0 {
                    let gap = stone.start - plan.platforms[i - 1].end
                    precondition(gap > 0)
                    // Leave at least 20% of the airborne window for imperfect timing.
                    precondition(gap < plan.speed * 1.05 * 0.8)
                }
                // A hole followed by a barrier can always be avoided in the remaining lane.
                let safe = (0...2).filter { $0 != stone.brokenLane && $0 != stone.obstacleLane }
                precondition(!safe.isEmpty)
            }
            if number > 1 {
                let previous = LevelPlan(number: number - 1)
                if number != 10 {
                    precondition(plan.speed > previous.speed)
                    precondition(plan.speed - previous.speed < 0.33)
                }
                if number < 91 {
                    precondition(abs(plan.firingInterval - min(10, previous.firingInterval / 0.9)) < 0.000001)
                }
                precondition(plan.projectileSpeed >= previous.projectileSpeed)
            }
        }
        print("Passed: paid boost cost, duration, repeat prevention and reset; 100 levels of bounded hazard density, safe routes, rare medicine, reward IDs/placement, crossing-ship jump clearance, and difficulty scaling.")
    }
}
