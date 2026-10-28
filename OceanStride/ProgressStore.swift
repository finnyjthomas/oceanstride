import Foundation

struct DailyAdSkips: Codable, Equatable {
    static let limit = 2
    private(set) var dayStart: Date?
    private(set) var used = 0

    func remaining(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let dayStart, calendar.startOfDay(for: date) <= dayStart else { return Self.limit }
        return max(0, Self.limit - used)
    }

    mutating func consume(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard remaining(at: date, calendar: calendar) > 0 else { return false }
        let today = calendar.startOfDay(for: date)
        if dayStart == nil || today > dayStart! { dayStart = today; used = 0 }
        used += 1
        return true
    }
}

struct RunCheckpoint: Codable, Equatable {
    let level: Int
    let score: Int
    let jewels: Int
    let hearts: Int
    var boostSeconds: Double? = nil
    var dailyAdSkips: DailyAdSkips? = nil
    static let fresh = RunCheckpoint(level: 1, score: 0, jewels: 0, hearts: 3)

    var nextLevel: RunCheckpoint {
        RunCheckpoint(level: level + 1, score: score, jewels: jewels,
                      hearts: hearts < 3 ? hearts + 1 : hearts, boostSeconds: boostSeconds, dailyAdSkips: dailyAdSkips)
    }
}

/// Saves the start of the current unlocked level, so quitting never duplicates pickups.
struct ProgressStore {
    let fileURL: URL
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OceanStride/progress.json")
    }
    func load() -> RunCheckpoint? {
        guard let data = try? Data(contentsOf: fileURL),
              let checkpoint = try? JSONDecoder().decode(RunCheckpoint.self, from: data),
              (1...10000).contains(checkpoint.level), checkpoint.score >= 0,
              checkpoint.jewels >= 0, checkpoint.hearts > 0 else { return nil }
        return checkpoint
    }
    func save(_ checkpoint: RunCheckpoint) throws {
        var checkpoint = checkpoint
        // Normal saves and New Game must not reset today's rewarded-ad usage.
        if checkpoint.dailyAdSkips == nil { checkpoint.dailyAdSkips = load()?.dailyAdSkips }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(checkpoint).write(to: fileURL, options: .atomic)
    }
}
