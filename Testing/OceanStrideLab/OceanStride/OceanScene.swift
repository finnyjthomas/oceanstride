import SpriteKit
import UIKit

final class OceanScene: SKScene {
    weak var session: GameSession?
    private var plan = LevelPlan(number: 1)
    private var runningSpeed: Double { plan.speed * (session?.boost.speedMultiplier ?? 1) }
    private var distance = 2.0
    private var lane = 1
    private var visualLane = 1.0
    private var jumpTime = 0.0
    private var jumpsUsed = 0
    private var jumpStartHeight = 0.0
    private let jumpDuration = 1.05
    private var jumping = false
    private var elapsed = 0.0
    private var lastTime: TimeInterval = 0
    private var fireTimer = 5.0
    private var invulnerable = 0.0
    private var reached: Set<Int> = []
    private var collected: Set<Int> = []
    private var collectedMedicine: Set<Int> = []
    private var ridingShipID: Int?
    private var groundedHeight = 0.0
    private var boatOffset = 0.0
    private var runnerX: Double { Double(lane - 1) * 2 / 3 + boatOffset }
    private var noticeTimer = 0.0
    private var hitObstacles: Set<Int> = []
    private struct PlayfieldTouch {
        let start: CGPoint
        var swipeHandled = false
    }
    private var playfieldTouches: [UITouch: PlayfieldTouch] = [:]
    private var jumpBuffer = 0.0
    private let edgeTolerance = 0.45
    private var edgeGrace = 0.15
    private var shots: [Shot] = []
    private let world = SKNode()
    private var feedback = UIImpactFeedbackGenerator(style: .light)
    private struct Shot {
        var age = 0.0
        let aim: AimedProjectile
        var duration: Double { aim.kind.duration }
        var lane: Int { aim.targetLane }
        let origin: CGPoint // Normalized screen position of the actual gun muzzle at firing.
        let airborne: Bool
    }
    private var volleyCount = 0
    private var footstepTimer = 0.0
    private let sea = UIColor(red: 0.025, green: 0.28, blue: 0.36, alpha: 1)
    private let mint = UIColor(red: 0.37, green: 1, blue: 0.78, alpha: 1)

    override func didMove(to view: SKView) {
        backgroundColor = sea
        if world.parent == nil { addChild(world) }
        view.isMultipleTouchEnabled = true
        render()
    }

    func begin(level: Int) {
        session?.resetSkipRequest()
        session?.pauseBoost(save: false)
        plan = LevelPlan(number: level, seed: session?.layoutSeed ?? 0)
        clearTouch(); jumpBuffer = 0; edgeGrace = 0.15; jumpsUsed = 0; jumpStartHeight = 0
        distance = 2; lane = plan.safeLane; visualLane = Double(plan.safeLane); jumping = false; jumpTime = 0
        elapsed = 0; volleyCount = 0; footstepTimer = 0; fireTimer = max(5, plan.firingInterval); invulnerable = 0; lastTime = 0
        collectedMedicine.removeAll(); ridingShipID = nil; groundedHeight = 0; boatOffset = 0; noticeTimer = 0
        reached.removeAll(); collected.removeAll(); hitObstacles.removeAll(); shots.removeAll()
        session?.platforms = 0; session?.target = plan.platforms.count
        session?.progress = 0; session?.message = "LAB · MIXED BARRIERS · AIMED SHOTS"; noticeTimer = 4; session?.phase = .playing
        feedback.prepare()
        render()
    }

    func move(_ direction: Int) {
        guard session?.phase == .playing else { return }
        let previous = lane
        lane = max(0, min(2, lane + direction))
        if lane != previous {
            visualLane += (Double(lane) - visualLane) * 0.55
            session?.audio.play(.dodge)
        }
    }
    func jump() {
        guard session?.phase == .playing else { return }
        if jumping && jumpsUsed < 2 {
            beginJump()
            session?.message = "DOUBLE JUMP"; noticeTimer = 0.7
            return
        }
        // After both jumps, a press just before landing can still be buffered.
        jumpBuffer = 0.14
        if !jumping && edgeGrace > 0 { beginJump() }
    }
    private func beginJump() {
        guard jumpsUsed < 2 else { return }
        // Start the airborne boost at the current height, avoiding a snap to the ground.
        jumpStartHeight = jumpHeight
        ridingShipID = nil
        jumpsUsed += 1
        jumpBuffer = 0; edgeGrace = 0
        jumping = true; jumpTime = 0
        session?.audio.play(.jump)
        feedback.impactOccurred(intensity: 0.35)
    }
    private var jumpHeight: Double {
        guard jumping else { return groundedHeight }
        let progress = min(1, jumpTime / jumpDuration)
        return jumpStartHeight * (1 - progress) + sin(progress * .pi) * 2.7
    }

    private func clearTouch() { playfieldTouches.removeAll() }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard session?.phase == .playing else { return }
        for touch in touches {
            playfieldTouches[touch] = PlayfieldTouch(start: touch.location(in: self))
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard var input = playfieldTouches[touch], !input.swipeHandled else { continue }
            let point = touch.location(in: self)
            let dx = point.x - input.start.x, dy = point.y - input.start.y
            // Track each finger independently so another held touch cannot swallow a jump.
            if abs(dx) >= 12 && abs(dx) > abs(dy) {
                move(dx > 0 ? 1 : -1); input.swipeHandled = true
            } else if dy >= 12 && dy > abs(dx) {
                jump(); input.swipeHandled = true
            }
            playfieldTouches[touch] = input
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesMoved(touches, with: event)
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let input = playfieldTouches.removeValue(forKey: touch), !input.swipeHandled { jump() }
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { playfieldTouches.removeValue(forKey: touch) }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime
        guard let session, session.phase == .playing else { clearTouch(); jumpBuffer = 0; return }
        session.advanceBoost(dt)
        let previousDistance = distance
        let previousHeight = jumpHeight
        elapsed += dt
        distance = min(plan.finish, distance + runningSpeed * dt)
        if let id = ridingShipID, !jumping, let ship = plan.crossingShips.first(where: { $0.id == id }) {
            boatOffset += ship.lateralPosition(distance: distance, speed: plan.speed) - ship.lateralPosition(distance: previousDistance, speed: plan.speed)
        } else {
            boatOffset *= max(0, 1 - dt * 6)
        }
        visualLane += (Double(lane) - visualLane) * min(1, dt * 36)
        invulnerable = max(0, invulnerable - dt)
        noticeTimer = max(0, noticeTimer - dt)
        if jumping {
            jumpTime += dt
            if jumpTime >= jumpDuration { jumping = false; jumpTime = 0; groundedHeight = 0 }
        }
        if !jumping {
            footstepTimer -= dt
            if footstepTimer <= 0 { session.audio.play(.step); footstepTimer = 0.31 * 10 / runningSpeed }
        }
        // A small foot-width allowance applies to both takeoff and landing edges.
        let stoneIndex = plan.platforms.firstIndex { distance >= $0.start - edgeTolerance && distance <= $0.end + edgeTolerance }
        let contactLane = max(0, min(2, Int((runnerX * 1.5).rounded()) + 1))
        let stoneGround = stoneIndex.map { index in
            let stone = plan.platforms[index]
            return !(stone.brokenLane == contactLane && abs(distance - (stone.start + stone.length * 0.5)) < 2.4 - edgeTolerance)
        } ?? false
        let barrierUnderfoot = stoneIndex.flatMap { index in
            plan.platforms[index].barriers.first {
                $0.contains(distance: distance, lane: contactLane) && !hitObstacles.contains($0.id)
            }
        }
        let landedOnBarrier = barrierUnderfoot.map {
            jumping && $0.canLand(previousHeight: previousHeight, height: jumpHeight)
        } ?? false
        let standingOnBarrier = barrierUnderfoot.map {
            $0.isLandable && !jumping && groundedHeight >= $0.topHeight - 0.01
        } ?? false
        let barrierSupport = landedOnBarrier || standingOnBarrier
        if landedOnBarrier {
            jumping = false; jumpTime = 0; groundedHeight = barrierUnderfoot?.topHeight ?? 0
            session.message = "SAFE TOP · JUMP AGAIN"; noticeTimer = 1.2
        }
        let deck = plan.crossingShips.first { $0.supports(distance: distance, x: runnerX, speed: plan.speed) }
        // The shield provides a temporary floor over water and broken stone.
        let hasGround = barrierSupport || stoneGround || deck != nil || session.isBoosting
        if let deck, !stoneGround, jumping, jumpHeight <= previousHeight,
           previousHeight >= deck.deckHeight - 0.12, jumpHeight <= deck.deckHeight + 0.05 {
            // Land on the moving deck while descending; this restores both jumps.
            jumping = false; jumpTime = 0
        }
        if !jumping {
            if hasGround {
                groundedHeight = barrierSupport ? (barrierUnderfoot?.topHeight ?? 0) : (stoneGround ? 0 : (deck?.deckHeight ?? 0))
                let newRide = stoneGround ? nil : deck?.id
                if newRide != nil && ridingShipID != newRide {
                    session.message = "ON DECK · JUMP TO THE NEXT STONE"; noticeTimer = 1.2
                }
                ridingShipID = newRide
            } else { ridingShipID = nil }
            if hasGround && jumpsUsed > 0 {
                jumpsUsed = 0; jumpStartHeight = 0
                session.audio.play(.land)
            }
            edgeGrace = hasGround ? 0.15 : max(0, edgeGrace - dt)
            if jumpBuffer > 0 && edgeGrace > 0 { beginJump() }
        }
        jumpBuffer = max(0, jumpBuffer - dt)
        // The first 40 ms of an upward jump count as airborne, including a late edge press.
        let clearsWater = hasGround || (jumping && (jumpHeight >= 0.25 || jumpTime < 0.04)) || (!jumping && edgeGrace > 0)
        if let index = stoneIndex {
            let stone = plan.platforms[index]
            let center = stone.start + stone.length * 0.5
            let inHole = stone.brokenLane == contactLane && abs(distance - center) < 2.4 - edgeTolerance
            if inHole && !clearsWater { lose("You fell through a broken stone."); return }
            if !inHole && !reached.contains(index) {
                reached.insert(index); session.platforms += 1; session.score += 1; session.record()
            }
            for barrier in stone.barriers where barrier.contains(distance: distance, lane: contactLane)
                && barrier.causesDamage(height: jumpHeight,
                    supported: barrierSupport && barrierUnderfoot?.id == barrier.id, time: elapsed)
                && !hitObstacles.contains(barrier.id) {
                hitObstacles.insert(barrier.id)
                damage(barrier.variant.map { "\($0.name.uppercased()) · WATCH THE WARNING" } ?? "Jump onto the barrier from above!")
                if session.phase == .lost { return }
            }
            for jewel in stone.jewels where jewel.lane == contactLane && abs(distance - jewel.position) < 0.85 && abs(jumpHeight + 0.8 - jewel.elevation) < 1.05 && !collected.contains(jewel.id) {
                collected.insert(jewel.id); session.jewels += jewel.value; session.audio.play(.jewel)
                feedback.impactOccurred(intensity: 0.5)
            }
            if stone.medicalLane == contactLane && abs(distance - stone.medicalPosition) < 1 && jumpHeight < 1.3 && !collectedMedicine.contains(index) {
                collectedMedicine.insert(index); session.hearts += 1
                session.message = "MEDICAL PACK · +1 LIFE"; noticeTimer = 2
                session.audio.play(.heal); feedback.impactOccurred(intensity: 0.65)
            }
        } else if !clearsWater {
            lose("You missed the next platform."); return
        }

        for ship in plan.crossingShips {
            let remaining = ship.position - distance
            if remaining > 0 && remaining < runningSpeed * 1.8 && noticeTimer == 0 && invulnerable == 0 {
                session.message = "CROSSING BOAT · LAND ON DECK OR JUMP OVER"
                noticeTimer = 0.15
            }

        }

        fireTimer -= dt
        // The last platform is a protected landing and finish area.
        let onFinish = stoneIndex == plan.platforms.count - 1
        if onFinish { shots.removeAll() }
        // Always aim at the character's actual lane and elevation, never a random lane.
        if fireTimer <= 0 && !onFinish && shots.isEmpty {
            let kind: LabProjectileKind = volleyCount % 2 == 0 ? .bomb : .bullet
            let aim = AimedProjectile(kind: kind, playerLane: contactLane, playerHeight: jumpHeight)
            let impactDistance = distance + runningSpeed * kind.duration
            if !plan.escapeLanes(at: impactDistance, from: aim.targetLane).isEmpty {
                fire(aim: aim, side: volleyCount % 2 == 0 ? -1 : 1,
                     helicopter: plan.hasHelicopters && kind == .bullet)
                volleyCount += 1
                fireTimer = plan.firingInterval
            }
        }
        for i in shots.indices {
            let previousAge = shots[i].age
            shots[i].age += dt
            if previousAge < shots[i].duration && shots[i].age >= shots[i].duration && shots[i].aim.hits(playerLane: contactLane, playerHeight: jumpHeight) && !plan.escapeLanes(at: distance, from: shots[i].lane).isEmpty {
                damage("\(shots[i].aim.kind.title) HIT · MOVE AFTER THE RED TARGET APPEARS")
                if session.phase == .lost { return }
            }
        }
        shots.removeAll { $0.age >= $0.duration }
        session.progress = min(1, distance / plan.finish)
        if invulnerable == 0 && noticeTimer == 0 { session.message = "" }
        if distance >= plan.finish && !jumping { session.completeLevel(); session.audio.play(.finish); session.record() }
        render()
    }

    private func damage(_ message: String) {
        guard invulnerable <= 0, let session, !session.isBoosting else { return }
        session.hearts -= 1; session.message = message; invulnerable = 1.7
        feedback.impactOccurred(intensity: 1)
        if session.hearts <= 0 { lose("The enemies and barriers got you.") }
        else { session.audio.play(.hit) }
    }
    private func lose(_ message: String) {
        session?.message = message; session?.phase = .lost; session?.record()
        session?.saveProgress()
        session?.audio.play(.death)
        feedback.impactOccurred(intensity: 1)
        render()
    }

    // A perspective projection keeps the entire game asset-free and sharp on iPad and iPhone.
    private func project(_ x: Double, _ z: Double, elevation: Double = 0) -> CGPoint {
        let depth = 1 / (1 + max(-3, z) * 0.045)
        let halfWidth = min(size.width * 0.43, 260)
        let horizon = size.height * 0.71
        return CGPoint(x: size.width * 0.5 + x * halfWidth * depth,
                       y: horizon - size.height * 0.49 * depth + elevation * 23 * depth)
    }
    @discardableResult private func polygon(_ points: [CGPoint], fill: UIColor, stroke: UIColor = .clear, width: CGFloat = 1) -> SKShapeNode {
        let path = CGMutablePath()
        if let first = points.first { path.move(to: first); for point in points.dropFirst() { path.addLine(to: point) }; path.closeSubpath() }
        let node = SKShapeNode(path: path); node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = width
        world.addChild(node); return node
    }
    private func line(_ points: [CGPoint], color: UIColor, width: CGFloat) {
        let path = CGMutablePath()
        if let first = points.first { path.move(to: first); for point in points.dropFirst() { path.addLine(to: point) } }
        let node = SKShapeNode(path: path); node.strokeColor = color; node.lineWidth = width; node.lineCap = .round; world.addChild(node)
    }
    private func ellipse(_ position: CGPoint, width: CGFloat, height: CGFloat, color: UIColor) {
        let node = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        node.position = position; node.fillColor = color; node.strokeColor = .clear; world.addChild(node)
    }
    private func tile(_ left: Double, _ right: Double, _ near: Double, _ far: Double, color: UIColor) {
        guard far > -3, near < 95 else { return }
        let n = max(-3, near), f = min(95, far)
        polygon([project(left, n), project(right, n), project(right, f), project(left, f)], fill: color, stroke: UIColor(red: 0.12, green: 0.24, blue: 0.27, alpha: 1), width: 1.5)
        if near > -3 {
            polygon([project(left, n), project(right, n), project(right, n, elevation: -0.55), project(left, n, elevation: -0.55)], fill: UIColor(red: 0.2, green: 0.31, blue: 0.32, alpha: 1))
        }
    }
    private func render() {
        guard size.width > 0 else { return }
        world.removeAllChildren()
        let horizon = size.height * 0.71
        polygon([CGPoint(x: 0, y: horizon), CGPoint(x: size.width, y: horizon), CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)], fill: UIColor(hue: CGFloat(plan.signature.family.rawValue) / 12 + 0.05, saturation: 0.5, brightness: 0.22, alpha: 1))
        ellipse(CGPoint(x: size.width * 0.76, y: size.height * 0.78), width: 65, height: 65, color: UIColor(red: 0.94, green: 0.76, blue: 0.49, alpha: 1))
        drawMountains(horizon: horizon)
        for i in 0..<32 {
            let z = (Double(i) * 3.7 - distance.truncatingRemainder(dividingBy: 3.7))
            let side = i % 2 == 0 ? -1.0 : 1.0
            let x = side * (1.4 + Double((i * 7) % 9) / 5)
            line([project(x, z), project(x + 0.35, z)], color: UIColor.white.withAlphaComponent(0.12), width: 2)
        }
        drawBoat(side: -1, z: boatDepth(-1))
        drawBoat(side: 1, z: boatDepth(1))
        if plan.hasHelicopters { drawHelicopter() }
        for (index, stone) in plan.platforms.enumerated().reversed() {
            if let ship = plan.crossingShips.first(where: { $0.id == index }) { drawCrossingShip(ship) }
            guard stone.end - distance > -3, stone.start - distance < 95 else { continue }
            let center = stone.start + stone.length * 0.5
            // Split each lane into masonry blocks, leaving actual holes in the surface.
            for row in stride(from: stone.end, to: stone.start, by: -2.4) {
                let far = row - distance, near = max(stone.start, row - 2.4) - distance
                for column in 0..<3 {
                    let left = -1.0 + Double(column) * 2 / 3
                    let right = left + 2 / 3
                    let shade = CGFloat((index + column + Int(row)) % 3) * 0.035
                    let color = UIColor(red: 0.49 + shade, green: 0.57 + shade, blue: 0.55 + shade, alpha: 1)
                    if stone.brokenLane == column {
                        let holeNear = center - 2.4 - distance, holeFar = center + 2.4 - distance
                        if near < holeNear { tile(left, right, near, min(far, holeNear), color: color) }
                        if far > holeFar { tile(left, right, max(near, holeFar), far, color: color) }
                    } else { tile(left, right, near, far, color: color) }
                }
            }
            // Mint marks the low-obstacle route; attacks can still target it.
            let routeX = Double(stone.safeLane - 1) * 2 / 3
            tile(routeX - 0.035, routeX + 0.035, stone.start - distance, stone.end - distance,
                 color: UIColor.systemMint.withAlphaComponent(0.65))
            if index == plan.platforms.count - 1 { drawFinish(stone) }
            // Pale edges make jump takeoffs legible.
            if stone.end - distance > 0 {
                line([project(-1, stone.end - distance), project(1, stone.end - distance)], color: UIColor(red: 0.92, green: 0.86, blue: 0.65, alpha: 1), width: 3)
            }
            for barrier in stone.barriers.reversed() where !hitObstacles.contains(barrier.id) {
                drawObstacle(barrier, z: barrier.position - distance)
            }
            for jewel in stone.jewels.sorted(by: { $0.position > $1.position }) where !collected.contains(jewel.id) {
                drawJewel(jewel)
            }
            if let medicalLane = stone.medicalLane, !collectedMedicine.contains(index) {
                drawMedicine(lane: medicalLane, z: stone.medicalPosition - distance)
            }
        }
        for shot in shots {
            let target = project(Double(shot.lane - 1) * 2 / 3, 0)
            ellipse(target, width: 44, height: 16, color: UIColor.systemRed.withAlphaComponent(0.35 + 0.2 * sin(elapsed * 12)))
            line([CGPoint(x: target.x - 14, y: target.y), CGPoint(x: target.x + 14, y: target.y)], color: .systemRed, width: 2)
            let origin = CGPoint(x: shot.origin.x * size.width, y: shot.origin.y * size.height)
            let destination = project(Double(shot.lane - 1) * 2 / 3, 0, elevation: shot.aim.targetHeight)
            let t = min(1, shot.age / shot.duration)
            func flight(_ fraction: Double) -> CGPoint {
                let arc = shot.aim.kind == .bomb ? sin(fraction * .pi) * 42 : 0
                return CGPoint(x: origin.x + (destination.x - origin.x) * fraction,
                               y: origin.y + (destination.y - origin.y) * fraction + arc)
            }
            let p = flight(t), scale = 0.45 + t * 0.55
            if shot.age < 0.2 {
                ellipse(origin, width: 32 * (1 - shot.age / 0.2), height: 32 * (1 - shot.age / 0.2), color: .systemYellow)
            }
            line((0...6).map { flight(max(0, t - Double(6 - $0) * 0.018)) }, color: UIColor.systemOrange.withAlphaComponent(0.65), width: 3 * scale)
            if shot.aim.kind == .bomb {
                ellipse(p, width: 22 * scale, height: 22 * scale, color: .init(white: 0.12, alpha: 1))
                ellipse(CGPoint(x: p.x - 3 * scale, y: p.y + 3 * scale), width: 7 * scale, height: 7 * scale, color: .lightGray)
                line([CGPoint(x:p.x + 5 * scale,y:p.y + 8 * scale),CGPoint(x:p.x + 9 * scale,y:p.y + 15 * scale)], color:.systemOrange,width:2 * scale)
            } else {
                line([flight(max(0,t-0.045)),p],color:.systemYellow,width:5 * scale)
                ellipse(p,width:7 * scale,height:7 * scale,color:.white)
            }

        }
        drawRunner()
    }

    private func drawJewel(_ jewel: JewelPickup) {
        let z = jewel.position - distance
        guard z > -1, z < 90 else { return }
        let phase = elapsed * 4 + Double(jewel.id) * 0.7
        let p = project(Double(jewel.lane - 1) * 2 / 3, z, elevation: jewel.elevation + sin(phase) * 0.18)
        let s = 11 / (1 + z * 0.045)
        let halfWidth = s * (0.2 + abs(cos(phase)) * 0.65)
        let color: UIColor = jewel.value > 1 ? .init(red: 1, green: 0.78, blue: 0.28, alpha: 1) : mint
        ellipse(p, width: s * (3 + sin(phase)), height: s * (3 + sin(phase)), color: color.withAlphaComponent(0.12))
        polygon([CGPoint(x: p.x, y: p.y + s), CGPoint(x: p.x + halfWidth, y: p.y), CGPoint(x: p.x, y: p.y - s), CGPoint(x: p.x - halfWidth, y: p.y)], fill: color, stroke: .white.withAlphaComponent(0.8))
        line([CGPoint(x: p.x, y: p.y + s), CGPoint(x: p.x - halfWidth * 0.3, y: p.y), CGPoint(x: p.x, y: p.y - s)], color: .white.withAlphaComponent(0.5), width: 1)
        if jewel.value > 1 && z < 35 {
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = "×\(jewel.value)"; label.fontSize = 9 / (1 + z * 0.03)
            label.position = CGPoint(x: p.x, y: p.y + s * 1.4); world.addChild(label)
        }
        let sparkle = CGPoint(x: p.x + cos(phase) * s * 1.6, y: p.y + sin(phase) * s * 1.6)
        line([CGPoint(x: sparkle.x - 2, y: sparkle.y), CGPoint(x: sparkle.x + 2, y: sparkle.y)], color: .white.withAlphaComponent(0.7), width: 1)
    }
    private func drawMedicine(lane: Int, z: Double) {
        guard z > -1, z < 90 else { return }
        let p = project(Double(lane - 1) * 2 / 3, z, elevation: 0.8 + sin(elapsed * 3) * 0.15)
        let s = 14 / (1 + z * 0.045)
        ellipse(p, width: s * (3.3 + sin(elapsed * 4) * 0.3), height: s * 3, color: UIColor.systemGreen.withAlphaComponent(0.18))
        polygon([CGPoint(x: p.x - s, y: p.y - s * 0.7), CGPoint(x: p.x + s, y: p.y - s * 0.7), CGPoint(x: p.x + s, y: p.y + s * 0.7), CGPoint(x: p.x - s, y: p.y + s * 0.7)], fill: .init(red: 0.92, green: 0.98, blue: 0.93, alpha: 1), stroke: .systemGreen, width: 2)
        line([CGPoint(x: p.x - s * 0.3, y: p.y + s * 0.7), CGPoint(x: p.x - s * 0.3, y: p.y + s), CGPoint(x: p.x + s * 0.3, y: p.y + s), CGPoint(x: p.x + s * 0.3, y: p.y + s * 0.7)], color: .systemGreen, width: 2)
        line([CGPoint(x: p.x - s * 0.45, y: p.y), CGPoint(x: p.x + s * 0.45, y: p.y)], color: .systemGreen, width: s * 0.3)
        line([CGPoint(x: p.x, y: p.y - s * 0.45), CGPoint(x: p.x, y: p.y + s * 0.45)], color: .systemGreen, width: s * 0.3)
    }
    private func drawCrossingShip(_ ship: CrossingShip) {
        let z = ship.position - distance
        guard z > -3, z < 85 else { return }
        let x = ship.lateralPosition(distance: distance, speed: plan.speed)
        let near = z - ship.halfLength, far = z + ship.halfLength
        let left = x - ship.halfWidth, right = x + ship.halfWidth
        line([project(left - 0.2, near), project(right + 0.2, near)], color: .white.withAlphaComponent(0.35), width: 5)
        polygon([project(left, near, elevation: ship.deckHeight), project(right, near, elevation: ship.deckHeight), project(right - 0.15, near, elevation: -0.4), project(left + 0.15, near, elevation: -0.4)], fill: .init(red: 0.48, green: 0.22, blue: 0.13, alpha: 1), stroke: .init(red: 0.93, green: 0.65, blue: 0.32, alpha: 1), width: 2)
        polygon([project(left, near, elevation: ship.deckHeight), project(right, near, elevation: ship.deckHeight), project(right - 0.1, far, elevation: ship.deckHeight), project(left + 0.1, far, elevation: ship.deckHeight)], fill: .init(red: 0.78, green: 0.58, blue: 0.32, alpha: 1), stroke: mint, width: 2)
        for row in 1..<5 {
            let depth = near + Double(row) * ship.halfLength * 2 / 5
            line([project(left + 0.1, depth, elevation: ship.deckHeight), project(right - 0.1, depth, elevation: ship.deckHeight)], color: .init(red: 0.5, green: 0.34, blue: 0.18, alpha: 1), width: 1)
        }
        // Clear, flat deck and mint border signal a safe landing surface.
        for offset in [-0.55, 0.55] {
            let p = project(x + offset, near, elevation: 0.1)
            let radius = 10 / (1 + max(0, near) * 0.045)
            ellipse(p, width: radius, height: radius, color: .init(white: 0.12, alpha: 1))
        }
    }

    private func drawMarks(_ marks: [EncounterMark], transform: (CGPoint) -> CGPoint, scale: Double = 1) {
        for mark in marks {
            let rgb = EncounterArtwork.palette[mark.color]
            let color = UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            let points = mark.points.map(transform)
            if mark.filled { polygon(points, fill: color, stroke: UIColor.black.withAlphaComponent(0.5), width: max(0.5, scale)) }
            else { line(points, color: color, width: max(1, mark.thickness * 32 * scale)) }
        }
    }

    private func drawObstacle(_ barrier: Barrier, z: Double) {
        guard z > -3, z < 90 else { return }
        let v = barrier.variant ?? HazardVariant(id: barrier.hasFire ? 30 : 0)
        let x = Double(barrier.lane - 1) * 2 / 3
        let active = barrier.active(at: elapsed), warning = barrier.warning(at: elapsed)
        let signal: UIColor = active ? .systemRed : (warning ? .systemYellow : .systemMint)
        let scale = 1 / (1 + max(-3, z) * 0.045)
        tile(x - 0.25, x + 0.25, z - Barrier.halfLength, z + Barrier.halfLength,
             color: signal.withAlphaComponent(active ? 0.3 : 0.12))
        // Artwork and collision share the same live vertical bounds.
        let band = barrier.damageBand(at: elapsed)
        let bottom: Double
        let height: Double
        if barrier.isLandable { bottom = 0; height = barrier.topHeight }
        else if let band { bottom = band.lowerBound; height = band.upperBound - band.lowerBound }
        else if [.blade, .wrecking, .crusher].contains(v.family) { bottom = 3.3; height = 1.4 }
        else { bottom = 0; height = warning ? 0.75 : 0.4 }
        if [.blade, .wrecking, .crusher].contains(v.family) {
            line([project(x, z, elevation: 5), project(x, z, elevation: bottom + height)], color: .gray, width: 2 * scale)
        }
        let art = EncounterArtwork.barrier(v.id, time: elapsed)
        drawMarks(art, transform: { pt in
            project(x + Double(pt.x) * 0.25, z - 0.6, elevation: bottom + Double(pt.y) * height)
        }, scale: scale)
        if active && (v.family == .flame || v.family == .dragon) {
            // Spitting fire stays inside this barrier's lane and collision footprint.
            for tongue in 0..<3 {
                let dx = Double(tongue - 1) * 0.08
                let flicker = 0.8 + 0.2 * sin(elapsed * 18 + Double(tongue))
                let tip = min(bottom + height, (bottom + height) * flicker)
                polygon([project(x + dx - 0.05,z - 0.85,elevation:0.1),
                         project(x + dx + 0.05,z - 0.85,elevation:0.1),
                         project(x + dx,z - 1.15,elevation:tip)], fill:.systemOrange)
                polygon([project(x + dx - 0.025,z - 0.9,elevation:0.1),
                         project(x + dx + 0.025,z - 0.9,elevation:0.1),
                         project(x + dx,z - 1.15,elevation:tip * 0.65)], fill:.systemYellow)
            }
        }
        if active && v.family == .wrecking {
            // A swinging body uses the same vertical damage bounds and stays in-lane.
            let swing = sin(elapsed * 2.8 + barrier.phaseOffset) * 0.09
            line([project(x,z,elevation:5),project(x + swing,z - 0.7,elevation:bottom + height * 0.5)],color:.lightGray,width:3 * scale)
            ellipse(project(x + swing,z - 0.7,elevation:bottom + height * 0.5),width:30 * scale,height:30 * scale,color:.darkGray)
        }
        if barrier.isLandable {
            polygon([project(x - 0.25,z - 1.2,elevation:height),project(x + 0.25,z - 1.2,elevation:height),project(x + 0.25,z + 1.2,elevation:height),project(x - 0.25,z + 1.2,elevation:height)], fill: .systemMint.withAlphaComponent(0.8), stroke: .white, width: 1)
        }
        if z > 2 && z < 22 {
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = warning ? "!" : (active ? "×" : (barrier.isLandable ? "LAND" : "CLEAR"))
            label.fontSize = 12 * scale; label.fontColor = signal
            label.position = project(x, z, elevation: max(bottom + height + 0.3, 3))
            world.addChild(label)
        }
    }
    private func drawBoat(side: Double, z: Double) {
        let p = project(side * 2.15, z)
        let s = 1 / (1 + z * 0.025)
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: p.x + x * s, y: p.y + y * s) }
        ellipse(pt(0, -5), width: 100 * s, height: 15 * s, color: .white.withAlphaComponent(0.12))
        polygon([pt(-49, 10), pt(45, 10), pt(30, -10), pt(-32, -10)], fill: UIColor(red: 0.2, green: 0.15, blue: 0.16, alpha: 1), stroke: .init(red: 0.69, green: 0.36, blue: 0.24, alpha: 1), width: 2)
        line([pt(-7, 10), pt(-7, 88)], color: .init(white: 0.14, alpha: 1), width: 4 * s)
        polygon([pt(-3, 84), pt(34, 27), pt(-3, 29)], fill: UIColor(red: 0.8, green: 0.31, blue: 0.25, alpha: 1))
        line([pt(0, 8), pt(-side * 34, 23)], color: .darkGray, width: 12 * s)
        ellipse(pt(12, 46), width: 9 * s, height: 12 * s, color: .init(white: 0.9, alpha: 0.8))
    }
    private func boatDepth(_ side: Double) -> Double {
        side < 0 ? 27 + sin(elapsed) * 3 : 43 + cos(elapsed * 0.8) * 4
    }
    private func boatMuzzle(_ side: Double) -> CGPoint {
        let z = boatDepth(side), p = project(side * 2.15, z)
        let scale = 1 / (1 + z * 0.025)
        return CGPoint(x: p.x - side * 34 * scale, y: p.y + 23 * scale)
    }
    private var helicopterPosition: CGPoint {
        project(sin(elapsed * 0.55) * 1.5, 48, elevation: 10 + sin(elapsed * 1.2) * 0.5)
    }
    private var helicopterMuzzle: CGPoint {
        let p = helicopterPosition
        return CGPoint(x: p.x, y: p.y - 17)
    }
    private func fire(aim: AimedProjectile, side: Double, helicopter: Bool) {
        let muzzle = helicopter ? helicopterMuzzle : boatMuzzle(side)
        shots.append(Shot(aim: aim, origin: CGPoint(x: muzzle.x / size.width, y: muzzle.y / size.height), airborne: helicopter))
        session?.audio.play(helicopter ? .laser : .cannon)
        session?.message = "\(aim.kind.title) AIMED AT YOU · JUMP OR CHANGE LANES"
        noticeTimer = aim.kind.duration
    }
    private func drawHelicopter() {
        let p = helicopterPosition
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: p.x + x, y: p.y + y) }
        line([pt(-10, 1), pt(-46, 7)], color: .init(red: 0.28, green: 0.37, blue: 0.4, alpha: 1), width: 7)
        polygon([pt(-49, 3), pt(-47, 20), pt(-39, 6)], fill: .init(red: 0.82, green: 0.36, blue: 0.21, alpha: 1))
        ellipse(pt(0, 0), width: 49, height: 27, color: .init(red: 0.28, green: 0.38, blue: 0.4, alpha: 1))
        ellipse(pt(12, 2), width: 22, height: 18, color: .init(red: 0.4, green: 0.76, blue: 0.82, alpha: 1))
        line([pt(-5, -8), pt(-5, -19), pt(22, -19)], color: .lightGray, width: 2)
        line([pt(3, 12), pt(3, 22)], color: .darkGray, width: 3)
        let rotor = 45 * cos(elapsed * 55)
        ellipse(pt(3, 23), width: 94, height: 7, color: .white.withAlphaComponent(0.12))
        line([pt(3 - rotor, 23), pt(3 + rotor, 23)], color: .init(white: 0.7, alpha: 0.85), width: 3)
        line([pt(0, -7), helicopterMuzzle], color: .init(white: 0.13, alpha: 1), width: 5)
        ellipse(pt(-12, 4), width: 5, height: 5, color: .systemRed)
    }
    private func drawMountains(horizon: CGFloat) {
        for layer in 0..<3 {
            for i in 0..<6 {
                let x = size.width * CGFloat(i) / 4 - 70 + CGFloat(layer * 23)
                let height = CGFloat(70 + (i * 37 + layer * 17) % 85) * (1 - CGFloat(layer) * 0.2)
                let peak = CGPoint(x: x + 12, y: horizon + height)
                let base = horizon - CGFloat(layer * 7)
                let shade = CGFloat(layer) * 0.025
                polygon([CGPoint(x: x - 95, y: base), peak, CGPoint(x: x + 105, y: base)], fill: .init(red: 0.12 - shade, green: 0.29 - shade, blue: 0.35 - shade, alpha: 1))
                polygon([peak, CGPoint(x: x + 40, y: base), CGPoint(x: x + 105, y: base)], fill: .init(red: 0.08 - shade, green: 0.22 - shade, blue: 0.29 - shade, alpha: 1))
                if layer == 0 {
                    polygon([peak, CGPoint(x: peak.x - 23, y: peak.y - height * 0.23), CGPoint(x: peak.x - 6, y: peak.y - height * 0.17), CGPoint(x: peak.x + 6, y: peak.y - height * 0.27), CGPoint(x: peak.x + 23, y: peak.y - height * 0.23)], fill: .init(red: 0.57, green: 0.7, blue: 0.73, alpha: 1))
                }
            }
        }
        line([CGPoint(x: 0, y: horizon - 23), CGPoint(x: size.width, y: horizon - 23)], color: .white.withAlphaComponent(0.08), width: 3)
    }
    private func drawFinish(_ stone: StonePlatform) {
        let z = plan.finish - distance
        guard z > -3, stone.start - distance < 90 else { return }
        // Checkerboard inlay and a celebratory gate on the final safe stone.
        for row in 0..<2 {
            for column in 0..<10 {
                let x = -1 + Double(column) * 0.2
                tile(x, x + 0.2, z + Double(row) * 0.9, z + Double(row + 1) * 0.9,
                     color: (row + column) % 2 == 0 ? .init(white: 0.93, alpha: 1) : .init(white: 0.17, alpha: 1))
            }
        }
        for x in [-0.97, 0.97] {
            line([project(x, z), project(x, z, elevation: 5)], color: .init(red: 0.91, green: 0.76, blue: 0.43, alpha: 1), width: max(2, 6 / (1 + max(0, z) * 0.045)))
        }
        polygon([project(-1, z, elevation: 5), project(1, z, elevation: 5), project(1, z, elevation: 4), project(-1, z, elevation: 4)], fill: .init(red: 0.12, green: 0.46, blue: 0.39, alpha: 1), stroke: mint)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "FINISH"; label.fontColor = .white
        label.fontSize = 18 / (1 + max(0, z) * 0.045)
        label.verticalAlignmentMode = .center
        label.position = project(0, z, elevation: 4.5)
        world.addChild(label)
    }

    private func drawRunner() {
        let base = project((visualLane - 1) * 2 / 3 + boatOffset, 0)
        if session?.isBoosting == true {
            ellipse(CGPoint(x: base.x, y: base.y + jumpHeight * 23 + 35), width: 85, height: 110,
                    color: mint.withAlphaComponent(0.25 + 0.08 * sin(elapsed * 8)))
        }
        ellipse(CGPoint(x: base.x, y: base.y + (ridingShipID == nil ? 0 : groundedHeight * 23)), width: 44 - jumpHeight * 4, height: 13, color: .black.withAlphaComponent(0.25))
        if invulnerable > 0 && Int(elapsed * 12) % 2 == 0 { return }
        let cycle = (distance - 2) * 18 / 10
        let bounce = jumping ? 0 : abs(sin(cycle)) * 2
        let y = base.y + jumpHeight * 23 + bounce
        let lean = (Double(lane) - visualLane) * 5
        func pt(_ x: Double, _ dy: Double) -> CGPoint { CGPoint(x: base.x + x + lean, y: y + dy) }
        let navy = UIColor(red: 0.13, green: 0.22, blue: 0.29, alpha: 1)
        let skin = UIColor(red: 0.79, green: 0.52, blue: 0.34, alpha: 1)
        // Fixed hip/foot x positions: stride advances in depth and lifts at the knee.
        // Opposite phases and changing boot size provide forward motion, not sideways kicking.
        for side in [-1.0, 1.0] {
            let phase = cycle + (side > 0 ? .pi : 0)
            let forward = jumping ? 0.4 : sin(phase)
            let lift = jumping ? 12 : max(0, cos(phase)) * 10
            let footY = 6 + forward * 5 + lift
            line([pt(side * 8, 34), pt(side * 8, 20 + lift * 0.45), pt(side * 8, footY)], color: navy, width: 11)
            line([pt(side * 6, 31), pt(side * 6, 21 + lift * 0.45)], color: UIColor.white.withAlphaComponent(0.12), width: 2)
            ellipse(pt(side * 8, footY), width: 12 - forward * 1.5, height: 16 - forward * 3, color: .init(red: 0.16, green: 0.14, blue: 0.13, alpha: 1))
            line([pt(side * 8 - 4, footY - 5), pt(side * 8 + 4, footY - 5)], color: .init(red: 0.87, green: 0.81, blue: 0.67, alpha: 1), width: 3)
            let swing = jumping ? 8 : sin(phase + .pi) * 7
            line([pt(side * 14, 57), pt(side * 19, 44 + swing * 0.4), pt(side * 17, 37 + swing)], color: skin, width: 8)
            ellipse(pt(side * 17, 37 + swing), width: 8, height: 9, color: skin)
        }
        // Layered jacket, shoulder panels, seams, and fitted expedition backpack.
        polygon([pt(-11, 64), pt(11, 64), pt(17, 57), pt(13, 32), pt(-13, 32), pt(-17, 57)], fill: .init(red: 0.92, green: 0.61, blue: 0.23, alpha: 1), stroke: .init(red: 0.52, green: 0.31, blue: 0.12, alpha: 1), width: 1.5)
        line([pt(-13, 55), pt(-11, 35)], color: .init(red: 0.68, green: 0.4, blue: 0.15, alpha: 1), width: 3)
        line([pt(-12, 33), pt(12, 33)], color: navy, width: 4)
        for x in [-9.0, 9.0] { line([pt(x, 61), pt(x, 37)], color: .init(red: 0.12, green: 0.28, blue: 0.26, alpha: 1), width: 4) }
        ellipse(pt(0, 48), width: 23, height: 29, color: .init(red: 0.16, green: 0.36, blue: 0.32, alpha: 1))
        polygon([pt(-9, 55), pt(9, 55), pt(8, 45), pt(-8, 45)], fill: .init(red: 0.3, green: 0.52, blue: 0.44, alpha: 1), stroke: .init(red: 0.13, green: 0.29, blue: 0.25, alpha: 1))
        line([pt(-6, 41), pt(6, 41)], color: .init(red: 0.61, green: 0.69, blue: 0.52, alpha: 1), width: 2)
        ellipse(pt(0, 48), width: 4, height: 5, color: .init(red: 0.9, green: 0.75, blue: 0.4, alpha: 1))
        ellipse(pt(0, 69), width: 12, height: 16, color: skin)
        ellipse(pt(-13, 76), width: 6, height: 9, color: skin)
        ellipse(pt(13, 76), width: 6, height: 9, color: skin)
        ellipse(pt(0, 78), width: 27, height: 30, color: skin)
        ellipse(pt(0, 85), width: 29, height: 21, color: .init(red: 0.2, green: 0.15, blue: 0.13, alpha: 1))
        for x in [-8.0, -2.0, 5.0] { line([pt(x, 91), pt(x - 2, 85)], color: .init(red: 0.32, green: 0.24, blue: 0.18, alpha: 1), width: 2) }
        line([pt(-13, 77), pt(0, 75), pt(13, 77)], color: mint, width: 5)
        polygon([pt(10, 76), pt(26 + sin(cycle) * 3, 69), pt(23, 62), pt(10, 72)], fill: mint)
    }
}
