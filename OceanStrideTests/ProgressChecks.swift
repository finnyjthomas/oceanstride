import Foundation

@main
struct ProgressChecks {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ocean-progress-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("progress.json")
        let store = ProgressStore(fileURL: file)
        precondition(store.load() == nil)

        let checkpoint = RunCheckpoint(level: 11, score: 140, jewels: 213, hearts: 5)
        try store.save(checkpoint)
        // A new store instance reads exactly the checkpoint after an app relaunch.
        precondition(ProgressStore(fileURL: file).load() == checkpoint)
        let cleared = checkpoint.nextLevel
        try store.save(cleared)
        precondition(ProgressStore(fileURL: file).load()?.level == 12)
        precondition(cleared.hearts == 5 && cleared.jewels == 213 && cleared.score == 140)
        let withBoost = RunCheckpoint(level: 11, score: 140, jewels: 0, hearts: 3, boostSeconds: 2.5)
        try store.save(withBoost)
        precondition(ProgressStore(fileURL: file).load()?.boostSeconds == 2.5)
        precondition(withBoost.nextLevel.boostSeconds == 2.5)
        let seeded = RunCheckpoint(level: 42, score: 140, jewels: 0, hearts: 3, layoutSeed: UInt64.max)
        try store.save(seeded)
        precondition(ProgressStore(fileURL: file).load()?.layoutSeed == UInt64.max)
        precondition(seeded.nextLevel.layoutSeed == UInt64.max)
        // Existing saves without the new optional field still load.
        try Data(#"{"level":11,"score":140,"jewels":50,"hearts":3}"#.utf8).write(to: file)
        precondition(store.load()?.level == 11 && store.load()?.boostSeconds == nil && store.load()?.layoutSeed == nil)
        precondition(RunCheckpoint(level: 3, score: 12, jewels: 4, hearts: 1).nextLevel.hearts == 2)

        // Invalid or partial data is safe to load, and an atomic save repairs it.
        try Data("{broken".utf8).write(to: file)
        precondition(store.load() == nil)
        try store.save(checkpoint)
        precondition(store.load() == checkpoint)
        try store.save(RunCheckpoint(level: -1, score: 0, jewels: 0, hearts: 3))
        precondition(store.load() == nil)
        print("Passed: saved-level relaunch, immediate next-level unlock, bonus lives/rewards, missing and corrupt saves.")
    }
}
