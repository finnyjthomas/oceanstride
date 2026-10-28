import Foundation

@main
struct RewardedSkipChecks {
    static func main() throws {
        var request = RewardedSkipRequest()
        let cancelled = request.request()!
        precondition(request.request() == nil)
        precondition(!request.complete(cancelled, earned: false) && !request.used)
        precondition(!request.complete(cancelled, earned: true))
        let success = request.request()!
        precondition(request.complete(success, earned: true))
        precondition(!request.complete(success, earned: true) && request.request() == nil)
        request = RewardedSkipRequest()
        let old = request.request()!
        request = RewardedSkipRequest()
        let current = request.request()!
        precondition(!request.complete(old, earned: true))
        precondition(request.complete(current, earned: true))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        var usage = DailyAdSkips()
        precondition(usage.remaining(at: today, calendar: calendar) == 2)
        precondition(usage.consume(at: today, calendar: calendar))
        precondition(usage.remaining(at: today, calendar: calendar) == 1)
        precondition(usage.consume(at: today, calendar: calendar))
        precondition(!usage.consume(at: today, calendar: calendar))
        precondition(!usage.consume(at: yesterday, calendar: calendar))

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ocean-skip-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("progress.json")
        let store = ProgressStore(fileURL: file)
        let checkpoint = RunCheckpoint(level: 12, score: 5, jewels: 100, hearts: 3, boostSeconds: 2.5, dailyAdSkips: usage)
        try store.save(checkpoint)
        let reloaded = ProgressStore(fileURL: file).load()!
        precondition(reloaded == checkpoint)
        precondition(reloaded.dailyAdSkips!.remaining(at: today, calendar: calendar) == 0)
        try store.save(.fresh) // New Game retains the usage even though progress resets.
        precondition(store.load()!.level == 1)
        precondition(store.load()!.dailyAdSkips == usage)
        try store.save(checkpoint.nextLevel)
        precondition(store.load()!.dailyAdSkips == usage)
        precondition(usage.remaining(at: tomorrow, calendar: calendar) == 2)
        precondition(usage.consume(at: tomorrow, calendar: calendar))
        precondition(usage.remaining(at: tomorrow, calendar: calendar) == 1)
        // Legacy saves still decode without a daily-usage field.
        try Data(#"{"level":11,"score":0,"jewels":0,"hearts":3}"#.utf8).write(to: file)
        precondition(store.load()?.dailyAdSkips == nil && store.load()?.level == 11)
        print("Passed: two daily skips, next-day reset, clock rollback, relaunch/New Game persistence, legacy saves, cancelled/duplicate/stale reward callbacks.")
    }
}
