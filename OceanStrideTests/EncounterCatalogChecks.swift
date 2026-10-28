import Foundation
#if canImport(AppKit)
import AppKit
#endif

@main
struct EncounterCatalogChecks {
    static func fingerprint(_ marks: [EncounterMark]) -> String {
        marks.map { "\($0.color):\($0.filled):" + $0.points.map { String(format: "%.4f,%.4f", $0.x, $0.y) }.joined(separator: ";") }.joined(separator: "|")
    }
    static func main() throws {
        var barriers = Set<String>(), attacks = Set<String>(), flights = Set<String>(), schedules = Set<String>()
        for id in 0..<100 {
            let v = HazardVariant(id: id), attack = AttackProfile(id: id)
            let art = EncounterArtwork.barrier(id, time: 0.6)
            precondition(!art.isEmpty)
            barriers.insert(fingerprint(art))
            attacks.insert(fingerprint(EncounterArtwork.projectile(attack, time: 0.6)))
            for time in [0.0, 0.3, 1.0, 2.0, 5.0] {
                for mark in EncounterArtwork.barrier(id, time: time) + EncounterArtwork.projectile(attack, time: time) {
                    precondition((0..<EncounterArtwork.palette.count).contains(mark.color))
                    precondition(mark.points.count >= 2)
                    precondition(mark.points.allSatisfy { $0.x.isFinite && $0.y.isFinite && abs($0.x) < 1.5 && $0.y > -0.4 && $0.y < 1.5 })
                }
            }
            precondition(attack.duration(speed: 34) >= 1.45)
            let start = attack.flight(at: 0), end = attack.flight(at: 1)
            precondition(abs(start.progress) < 0.00001 && abs(end.progress - 1) < 0.00001)
            precondition(abs(start.sideways) < 0.00001 && abs(end.sideways) < 0.00001 && abs(end.rise) < 0.00001)
            if id < 10 {
                flights.insert((0...40).map { t in
                    let p = attack.flight(at: Double(t) / 40)
                    return String(format: "%.3f,%.3f,%.3f",p.progress,p.sideways,p.rise)
                }.joined(separator: ";"))
                schedules.insert((0..<100).map { v.isActive(phase: Double($0)/100) ? "1" : "0" }.joined())
            }
            let plan = LevelPlan(number: id+1, seed: 83)
            precondition(plan.platforms.flatMap(\.barriers).allSatisfy { $0.variantID == id })
        }
        precondition(barriers.count == 100, "Repeated barrier geometry")
        precondition(attacks.count == 100, "Repeated projectile geometry")
        precondition(flights.count == 10 && schedules.count == 10)
        precondition(Set((0..<100).map { AttackProfile(id: $0).name }).count == 100)
        print("Passed: 100 distinct barrier geometries, 100 projectile geometries/names, 10 flight curves, 10 activation sequences, bounded art, exact impact endpoints, level-exclusive spawning.")
        #if canImport(AppKit)
        if CommandLine.arguments.count > 1 {
            try export(to: CommandLine.arguments[1], projectile: false)
            try export(to: CommandLine.arguments[1], projectile: true)
        }
        #endif
    }
    #if canImport(AppKit)
    static func export(to folder: String, projectile: Bool) throws {
        let width = 2000, height = 1900
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        NSColor(calibratedRed: 0.025, green: 0.12, blue: 0.17, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0,y: 0,width: width,height: height)).fill()
        for id in 0..<100 {
            let x = Double(id % 10) * 200, y = Double(9-id/10) * 190
            let marks = projectile ? EncounterArtwork.projectile(AttackProfile(id: id), time: 0.6) : EncounterArtwork.barrier(id, time: 0.6)
            for mark in marks {
                let path = NSBezierPath()
                for (i, pt) in mark.points.enumerated() {
                    let point = NSPoint(x: x+100+pt.x*76,y: y+65+pt.y*90)
                    if i == 0 { path.move(to: point) } else { path.line(to: point) }
                }
                let rgb = EncounterArtwork.palette[mark.color]
                NSColor(calibratedRed: rgb.0,green: rgb.1,blue: rgb.2,alpha: 1).set()
                if mark.filled { path.close(); path.fill() }
                else { path.lineWidth = max(1,mark.thickness*76); path.stroke() }
            }
            let name = projectile ? AttackProfile(id: id).name : HazardVariant(id: id).name
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            ("\(id+1). \(name)" as NSString).draw(in: NSRect(x:x+3,y:y+3,width:194,height:35), withAttributes: [.font:NSFont.systemFont(ofSize:12,weight:.semibold),.foregroundColor:NSColor.white,.paragraphStyle:paragraph])
        }
        NSGraphicsContext.restoreGraphicsState()
        try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
        let path = folder + (projectile ? "/100-attacks.png" : "/100-barriers.png")
        try bitmap.representation(using:.png,properties:[:])!.write(to: URL(fileURLWithPath:path))
        print("Exported \(path)")
    }
    #endif
}
