import SwiftUI
import SpriteKit

@main
struct OceanStrideApp: App {
    var body: some Scene {
        WindowGroup { GameView().preferredColorScheme(.dark) }
    }
}

final class GameSession: ObservableObject {
    @Published var level = 1
    @Published var platforms = 0
    @Published var target = 5
    @Published var score = 0
    @Published var jewels = 0
    @Published var hearts = 3
    @Published var progress = 0.0
    let audio = GameAudio()
    @Published var muted = UserDefaults.standard.bool(forKey: "muted")
    @Published private(set) var boost = JewelBoost()
    var isBoosting: Bool { boost.isActive }
    @Published var phase: Phase = .ready {
        didSet {
            if phase != .playing { boost.pause() }
            audio.setPlaying(phase == .playing)
        }
    }
    func activateBoost() {
        guard phase == .playing, boost.activate(jewels: &jewels) else { return }
        // Spend this attempt's pickups first, then persist any cost paid from saved jewels.
        levelStartJewels = min(levelStartJewels, jewels)
        saveProgress()
        audio.play(.heal)
    }
    func advanceBoost(_ seconds: Double) {
        if phase == .playing && isBoosting { boost.advance(seconds) }
    }
    func pauseBoost(save: Bool = true) {
        boost.pause()
        if save { saveProgress() }
    }
    @Published var message = ""
    @Published var best = UserDefaults.standard.integer(forKey: "bestPlatforms")
    private let progressStore = ProgressStore()
    @Published var hasSavedGame = false
    @Published var saveFailed = false
    @Published var skipRequest = RewardedSkipRequest()
    @Published private(set) var dailyAdSkips = DailyAdSkips()
    @Published private(set) var earnedSkipPending = false
    var skipsLeftToday: Int { dailyAdSkips.remaining() }
    func refreshDailyAdSkips() {
        dailyAdSkips = progressStore.load()?.dailyAdSkips ?? DailyAdSkips()
    }
    func resetSkipRequest() {
        skipRequest = RewardedSkipRequest()
        earnedSkipPending = false
    }
    func requestLevelSkip() -> UUID? {
        refreshDailyAdSkips()
        guard (phase == .lost || phase == .paused), skipsLeftToday > 0, !earnedSkipPending else { return nil }
        return skipRequest.request()
    }
    func finishLevelSkip(_ token: UUID, earned: Bool) {
        guard skipRequest.complete(token, earned: earned && (phase == .lost || phase == .paused)) else { return }
        earnedSkipPending = true
        applyEarnedLevelSkip()
    }
    func applyEarnedLevelSkip() {
        guard earnedSkipPending, phase == .lost || phase == .paused else { return }
        refreshDailyAdSkips()
        var usage = dailyAdSkips
        guard usage.consume() else { earnedSkipPending = false; return }
        let checkpoint = RunCheckpoint(level: level + 1, score: score, jewels: jewels,
            hearts: max(3, hearts), boostSeconds: boost.remaining, dailyAdSkips: usage, layoutSeed: layoutSeed)
        // Commit the level unlock and daily usage together before granting the skip.
        do { try progressStore.save(checkpoint); hasSavedGame = true; saveFailed = false }
        catch { saveFailed = true; return }
        dailyAdSkips = usage
        restore(checkpoint)
        scene.begin(level: level)
        phase = .paused
        message = "LEVEL SKIPPED"
    }
    private(set) var layoutSeed = UInt64.random(in: 1...UInt64.max)
    private var levelStartHearts = 3
    private var levelStartScore = 0
    private var levelStartJewels = 0
    enum Phase { case ready, playing, paused, lost, cleared }
    lazy var scene: OceanScene = {
        let scene = OceanScene(size: CGSize(width: 430, height: 932))
        scene.scaleMode = .resizeFill
        scene.session = self
        return scene
    }()
    init() {
        refreshDailyAdSkips()
        if let checkpoint = progressStore.load() {
            restore(checkpoint)
            hasSavedGame = true
        }
    }
    private func restore(_ checkpoint: RunCheckpoint) {
        layoutSeed = checkpoint.layoutSeed ?? layoutSeed
        boost = JewelBoost(remaining: checkpoint.boostSeconds ?? 0)
        level = checkpoint.level; score = checkpoint.score; jewels = checkpoint.jewels
        hearts = max(3, checkpoint.hearts)
        levelStartScore = score; levelStartJewels = jewels; levelStartHearts = hearts
        target = 5 + (level - 1) * 2
    }
    private func save(_ checkpoint: RunCheckpoint) {
        do { try progressStore.save(checkpoint); hasSavedGame = true; saveFailed = false }
        catch { saveFailed = true }
    }
    func saveProgress() {
        guard phase != .ready else { return }
        if phase == .cleared {
            save(RunCheckpoint(level: level, score: score, jewels: jewels, hearts: hearts, boostSeconds: boost.remaining, layoutSeed: layoutSeed).nextLevel)
        } else {
            save(RunCheckpoint(level: level, score: levelStartScore, jewels: levelStartJewels, hearts: levelStartHearts, boostSeconds: boost.remaining, layoutSeed: layoutSeed))
        }
    }
    func start() {
        // Resume the saved level from its beginning, including previously earned rewards.
        restore(progressStore.load() ?? .fresh)
        scene.begin(level: level)
        saveProgress()
    }
    func newGame() {
        layoutSeed = UInt64.random(in: 1...UInt64.max)
        restore(.fresh)
        scene.begin(level: 1)
        saveProgress()
    }
    func startTestLevel(_ selectedLevel: Int) {
        let selected = max(1, min(100, selectedLevel))
        layoutSeed = UInt64.random(in: 1...UInt64.max)
        restore(RunCheckpoint(level: selected, score: 0, jewels: 0, hearts: 3,
            boostSeconds: 0, dailyAdSkips: dailyAdSkips, layoutSeed: layoutSeed))
        scene.begin(level: selected)
        saveProgress()
    }
    func completeLevel() {
        phase = .cleared
        saveProgress() // Unlock the next level even if the app closes on the victory screen.
    }
    func next() {
        restore(RunCheckpoint(level: level, score: score, jewels: jewels, hearts: hearts, boostSeconds: boost.remaining, layoutSeed: layoutSeed).nextLevel)
        scene.begin(level: level)
        saveProgress()
    }
    func retryLevel() {
        score = levelStartScore; jewels = levelStartJewels; hearts = max(3, levelStartHearts)
        scene.begin(level: level)
        saveProgress()
    }
    func pause() { if phase == .playing { phase = .paused } }
    func returnToMainMenu() {
        pause()
        saveProgress()
        guard !saveFailed else { return }
        if let checkpoint = progressStore.load() { restore(checkpoint) }
        platforms = 0; progress = 0; message = ""
        phase = .ready
    }
    func toggleSound() { muted.toggle(); audio.muted = muted }
    func record() {
        if score > best { best = score; UserDefaults.standard.set(best, forKey: "bestPlatforms") }
    }
}

struct GameView: View {
    @StateObject private var game = GameSession()
    @StateObject private var ads = RewardedAds()
    @Environment(\.scenePhase) private var appPhase
    @State private var showsAdPrivacy = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SpriteView(scene: game.scene, preferredFramesPerSecond: 120).ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OCEAN / STRIDE").font(.system(size: 13, weight: .heavy, design: .rounded)).tracking(3)
                            Text("LEVEL \(game.level)").font(.system(size: 28, weight: .black, design: .rounded))
                        }.allowsHitTesting(false)
                        Spacer()
                        Button { game.toggleSound() } label: {
                            Image(systemName: game.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").padding(12).background(.white.opacity(0.12), in: Circle())
                        }.accessibilityLabel(game.muted ? "Enable sound" : "Mute sound")
                        Button { game.pause() } label: { Image(systemName: "pause.fill").padding(15).background(.white.opacity(0.12), in: Circle()) }
                            .accessibilityLabel("Pause game").disabled(game.phase != .playing)
                    }
                    HStack {
                        stat("PLATFORMS", "\(game.platforms) / \(game.target)")
                        Spacer()
                        stat("JEWELS", "◆ \(game.jewels)")
                        Spacer()
                        stat("LIVES", game.hearts > 3 ? "♥ ×\(game.hearts)" : String(repeating: "♥", count: max(0, game.hearts)))
                    }
                    ProgressView(value: game.progress).tint(Color(red: 0.4, green: 0.95, blue: 0.83)).allowsHitTesting(false)
                    if game.isBoosting && game.phase == .playing {
                        BoostCountdown(remaining: game.boost.remaining)
                            .allowsHitTesting(false)
                    }
                    Spacer()
                    if game.phase == .playing {
                        BoostControl(game: game)
                        Text(game.message.isEmpty ? "SWIPE TO DODGE · TAP TO JUMP" : game.message)
                            .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1)
                            .padding(10).background(.black.opacity(0.25), in: Capsule())
                            .allowsHitTesting(false)
                        HStack(spacing: 16) {
                            control("arrow.left", label: "Move left") { game.scene.move(-1) }
                            Button { game.scene.jump() } label: {
                                Text("JUMP").font(.system(size: 17, weight: .black, design: .rounded)).tracking(3)
                                    .frame(maxWidth: .infinity).frame(height: 64)
                                    .background(Color(red: 0.18, green: 0.7, blue: 0.62), in: RoundedRectangle(cornerRadius: 22))
                            }.buttonStyle(TouchDownControlStyle()).accessibilityLabel("Jump")
                            control("arrow.right", label: "Move right") { game.scene.move(1) }
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 16)
                if game.phase == .ready {
                    OpeningView(game: game, ads: ads).ignoresSafeArea()
                } else if game.phase != .playing { overlay(width: geometry.size.width) }
            }.foregroundStyle(.white)
        }.onChange(of: appPhase) { _, phase in
            if phase != .active { game.pause(); game.saveProgress(); game.audio.setPlaying(false) }
            else { game.refreshDailyAdSkips() }
        }
        .task {
            await ads.updateConsentAtLaunch()
        }
        .onChange(of: game.phase) { _, phase in
            if phase != .lost && phase != .paused { ads.cancelPending() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            game.refreshDailyAdSkips()
        }
        .sheet(isPresented: $showsAdPrivacy) { AdPrivacyView(ads: ads) }
    }
    func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.system(size: 19, weight: .bold, design: .rounded))
        }.allowsHitTesting(false)
    }
    func control(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title2.bold()).frame(width: 64, height: 64).background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 22)) }.buttonStyle(TouchDownControlStyle()).accessibilityLabel(label)
    }
    func overlay(width: CGFloat) -> some View {
        ZStack {
            Color(red: 0.01, green: 0.09, blue: 0.15).opacity(0.72).ignoresSafeArea()
            ScrollView {
            VStack(spacing: 18) {
                Text(game.phase == .cleared ? "PASSAGE COMPLETE" : "THE OPEN SEA AWAITS")
                    .font(.system(size: 10, weight: .heavy)).tracking(3).foregroundStyle(.mint)
                Text(title).font(.system(size: min(48, width * 0.11), weight: .black, design: .rounded)).multilineTextAlignment(.center)
                Text(detail).font(.system(size: 15)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).lineSpacing(5)
                if (game.phase == .lost || game.phase == .paused) && ads.enabled {
                    Button {
                        if game.earnedSkipPending { game.applyEarnedLevelSkip(); return }
                        guard let token = game.requestLevelSkip() else { return }
                        game.audio.setPlaying(false)
                        ads.watchForLevelSkip { earned in game.finishLevelSkip(token, earned: earned) }
                    } label: {
                        VStack(spacing: 5) {
                            Label(game.earnedSkipPending ? "Apply earned level skip" : (ads.isBusy ? "Loading ad…" : "Watch ad → Skip level"), systemImage: "forward.end.fill")
                                .font(.headline)
                            Text("Level \(game.level + 1) · \(game.skipsLeftToday) of 2 skips left today")
                                .font(.caption)
                        }.frame(maxWidth: .infinity).padding(16)
                            .background(Color.orange.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                    }.disabled(ads.isBusy || game.skipsLeftToday == 0)
                    if game.skipsLeftToday == 0 {
                        Text("Daily limit reached. Skips reset tomorrow.").font(.footnote)
                    }
                    if game.earnedSkipPending && game.saveFailed {
                        Text("Ad completed. Couldn't save the next level—tap Apply earned level skip to try again without another ad.")
                            .font(.footnote).foregroundStyle(.yellow)
                    }
                    if !ads.status.isEmpty {
                        Text(ads.status).font(.footnote).multilineTextAlignment(.center)
                    }
                    #if DEBUG
                    Text("TEST AD · NO REVENUE").font(.caption2.bold()).foregroundStyle(.yellow)
                    #endif
                }
                if game.phase == .ready {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Tap again in the air to double jump", systemImage: "arrow.up")
                        Label("Swipe left / right to change lanes", systemImage: "arrow.left.arrow.right")
                        Label("Dodge red cannonball warnings", systemImage: "scope")
                        Label("Reach stones to score. Collect jewels!", systemImage: "diamond.fill")
                    }.font(.system(size: 12, weight: .medium)).padding(18).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                }
                Button {
                    switch game.phase {
                    case .paused: game.phase = .playing
                    case .cleared: game.next()
                    case .lost: game.retryLevel()
                    default: game.start()
                    }
                } label: {
                    HStack { Text(buttonTitle); Spacer(); Image(systemName: "arrow.right") }
                        .font(.system(size: 16, weight: .bold)).padding(20).background(Color(red: 0.13, green: 0.61, blue: 0.53), in: RoundedRectangle(cornerRadius: 18))
                }
                if game.phase == .paused {
                    Button("Restart level \(game.level)") { game.retryLevel() }.font(.footnote.bold())
                }
                Button { game.returnToMainMenu() } label: {
                    Label("Main menu", systemImage: "house.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }
                if game.saveFailed {
                    Text("Couldn't save your progress. Please try Main menu again.")
                        .font(.footnote).foregroundStyle(.yellow).multilineTextAlignment(.center)
                }
                Button(game.muted ? "Sound: off" : "Sound: on") { game.toggleSound() }.font(.footnote.bold()).foregroundStyle(.mint)
                Button("Privacy & ads") { showsAdPrivacy = true }.font(.footnote.bold())
                Text("BEST  \(game.best) PLATFORMS").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.45))
            }.padding(28).frame(maxWidth: 420)
            }.defaultScrollAnchor(.center)
        }
    }
    var title: String {
        switch game.phase {
        case .ready: "Ocean\nStride."
        case .paused: "Take a breath."
        case .lost: "The sea\nwill wait."
        case .cleared: "Onward,\nexplorer."
        case .playing: ""
        }
    }
    var detail: String {
        switch game.phase {
        case .ready: "An endless ocean. An ancient stone path.\nHow far can you go?"
        case .paused: game.message == "LEVEL SKIPPED" ? "Level \(game.level) is unlocked.\nResume when you're ready." : "Your journey is paused."
        case .lost: "\(game.message)\n\(game.score) platforms reached · \(game.jewels) jewels collected"
        case .cleared: "\(game.score) platforms reached · \(game.jewels) jewels collected\nNext passage: \(game.target + 2) platforms. Faster seas."
        case .playing: ""
        }
    }
    var buttonTitle: String {
        switch game.phase {
        case .paused: "Resume journey"
        case .cleared: "Enter level \(game.level + 1)"
        case .lost: "Retry level \(game.level)"
        default: "Begin journey"
        }
    }
}

private struct BoostCountdown: View {
    let remaining: Double
    private var seconds: Int { Int(ceil(remaining)) }
    private var accent: Color { remaining <= 2 ? .yellow : .mint }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("SHIELD BOOST", systemImage: "shield.fill")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                    Text(remaining <= 2 ? "ENDING SOON" : "PROTECTED · 3× SPEED")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(seconds)")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text("SEC").font(.system(size: 13, weight: .heavy, design: .rounded))
                }
            }
            ProgressView(value: min(1, max(0, remaining / 5)))
                .tint(accent).accessibilityHidden(true)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 16).padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(accent, lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shield boost active")
        .accessibilityValue("\(seconds) seconds remaining")
    }
}

private struct BoostControl: View {
    @ObservedObject var game: GameSession
    @GestureState private var held = false

    private var canActivate: Bool { game.boost.remaining > 0 || game.jewels >= JewelBoost.cost }
    private var title: String {
        if game.isBoosting { return "SHIELDED · 3× SPEED · \(Int(ceil(game.boost.remaining)))s" }
        if game.boost.remaining > 0 { return String(format: "HOLD TO RESUME · %.1fs LEFT", game.boost.remaining) }
        return canActivate ? "HOLD: SHIELD BOOST · ◆\(JewelBoost.cost)" : "SHIELD BOOST · \(game.jewels)/\(JewelBoost.cost) ◆"
    }

    var body: some View {
        Label(title, systemImage: "shield.lefthalf.filled")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(game.isBoosting ? Color.black : Color.white)
            .frame(maxWidth: 300).frame(height: 48)
            .background(game.isBoosting ? Color.yellow : Color.black.opacity(0.55), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.8), lineWidth: 1.5))
            .contentShape(Capsule())
            .opacity(canActivate || game.isBoosting ? 1 : 0.6)
            .gesture(LongPressGesture(minimumDuration: 0.5)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .updating($held) { value, state, _ in
                    if case .second(true, _) = value { state = true }
                })
            .onChange(of: held) { _, pressed in
                if pressed { game.activateBoost() } else { game.pauseBoost() }
            }
            .onDisappear { game.pauseBoost() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Shield boost")
            .accessibilityValue(game.boost.remaining > 0 ? "\(game.isBoosting ? "Active" : "Saved"), \(Int(ceil(game.boost.remaining))) seconds remaining" : "\(game.jewels) jewels, costs \(JewelBoost.cost)")
            .accessibilityHint("Double tap to start or pause. Saved time is used before spending \(JewelBoost.cost) jewels for five more seconds.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if game.isBoosting { game.pauseBoost() } else { game.activateBoost() }
            }
    }
}

/// Fires once on press, with automatic cancellation reset and VoiceOver activation support.
private struct TouchDownControlStyle: PrimitiveButtonStyle {
    @GestureState private var pressed = false
    @State private var fired = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.96 : 1)
            .gesture(DragGesture(minimumDistance: 0)
                .updating($pressed) { _, state, _ in state = true }
                .onChanged { _ in
                    // Dispatch directly, even when a quick tap begins and ends between view updates.
                    guard !fired else { return }
                    fired = true
                    configuration.trigger()
                }
                .onEnded { _ in fired = false })
            .onChange(of: pressed) { _, isPressed in
                if !isPressed { fired = false }
            }
            .onDisappear { fired = false }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { configuration.trigger() }
    }
}
