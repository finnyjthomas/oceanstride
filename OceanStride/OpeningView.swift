import SwiftUI

struct OpeningView: View {
    @ObservedObject var game: GameSession
    @ObservedObject var ads: RewardedAds
    @State private var showsInstructions = false
    @State private var confirmsNewGame = false
    @State private var showsAdPrivacy = false
    private let ink = Color(red: 0.025, green: 0.18, blue: 0.23)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.15, green: 0.57, blue: 0.94)
                Image("OpeningArtwork")
                    .resizable().aspectRatio(contentMode: geometry.size.width > 600 ? .fit : .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height - max(geometry.safeAreaInsets.top, 54), alignment: .top)
                    .clipped()
                    .offset(y: max(geometry.safeAreaInsets.top, 54) / 2)
                    .accessibilityLabel("Ocean Stride adventure poster")
                LinearGradient(stops: [
                    .init(color: ink.opacity(0.25), location: 0),
                    .init(color: .clear, location: 0.25),
                    .init(color: .clear, location: 0.62),
                    .init(color: ink.opacity(0.65), location: 0.83),
                    .init(color: ink.opacity(0.96), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    VStack(spacing: 14) {
                        Text("CHASE THE HORIZON")
                            .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(3)
                            .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.87))
                        Button {
                            if game.hasSavedGame { game.start() } else { game.newGame() }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "play.fill").font(.system(size: 23, weight: .bold))
                                VStack(spacing: 3) {
                                    Text(game.hasSavedGame ? "CONTINUE FROM" : "NEW GAME")
                                        .font(.system(size: 23, weight: .black, design: .rounded))
                                        .tracking(0.5).minimumScaleFactor(0.75).lineLimit(1)
                                    Text("LEVEL \(game.level)")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(2)
                                }
                            }
                            .foregroundStyle(ink).frame(maxWidth: .infinity).frame(height: 80)
                            .background {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color(red: 1, green: 0.83, blue: 0.3))
                                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 2))
                                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(OpeningPressStyle())
                            .accessibilityLabel(game.hasSavedGame ? "Continue from level \(game.level)" : "New game, level 1")
                        if game.hasSavedGame {
                            Button { confirmsNewGame = true } label: {
                                Label("NEW GAME", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .tracking(1).frame(maxWidth: .infinity).frame(height: 52)
                                    .background(ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 17))
                                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.75), lineWidth: 1.5))
                            }.buttonStyle(OpeningPressStyle())
                                .accessibilityLabel("Start a new game from level 1")
                        }
                        if game.saveFailed {
                            Text("Progress could not be saved. Please check device storage.")
                                .font(.caption).foregroundStyle(.yellow).multilineTextAlignment(.center)
                        } else if game.hasSavedGame {
                            Label("Progress saved · Level \(game.level)", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        }
                        Button { showsInstructions = true } label: {
                            Label("How to play", systemImage: "questionmark.circle")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(minHeight: 44).padding(.horizontal, 16)
                        }.foregroundStyle(.white.opacity(0.9))
                        Button("Privacy & ads") { showsAdPrivacy = true }
                            .font(.footnote.bold()).frame(minHeight: 44)
                    HStack {
                        Label("BEST  \(game.best)", systemImage: "trophy.fill")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1).padding(.horizontal, 14).padding(.vertical, 11)
                            .background(ink.opacity(0.5), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                            .accessibilityLabel("Best score: \(game.best) platforms")
                        Spacer()
                        Button { game.toggleSound() } label: {
                            Image(systemName: game.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44)
                                .background(ink.opacity(0.5), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                        }.accessibilityLabel(game.muted ? "Enable sound" : "Mute sound")
                    }.padding(.top, 2)

                    }
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 26)
                .padding(.top, max(geometry.safeAreaInsets.top, 54) + 6)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 6)
            }.foregroundStyle(.white)
        }
        .alert("Start a new game?", isPresented: $confirmsNewGame) {
            Button("Cancel", role: .cancel) { }
            Button("New Game", role: .destructive) { game.newGame() }
        } message: {
            Text("This replaces your saved level \(game.level) and starts at level 1. Your best score stays saved.")
        }
        .sheet(isPresented: $showsAdPrivacy) { AdPrivacyView(ads: ads) }
        .sheet(isPresented: $showsInstructions) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Find your stride.").font(.system(size: 28, weight: .black, design: .rounded))
                instruction("arrow.left.arrow.right", "Swipe to dodge", "Mint marks fewer barriers, not protection from shots. Switch lanes and jump gaps; take other lanes for richer jewels. Yellow warns, red means active.")
                instruction("arrow.up", "Jump. Then jump again.", "Tap JUMP or swipe up. Jump again in the air for a second boost.")
                instruction("diamond.fill", "Take the daring route", "Land on mint stone and hurdle tops. Dodge saws, flames, dragons and moving traps. Medical packs add lives from level 11.")
                instruction("flag.checkered", "Reach the next shore", "Ride crossing boats or jump from them. Your unlocked level is saved when you leave.")
                Button("Got it") { showsInstructions = false }
                    .font(.headline).frame(maxWidth: .infinity).padding(15)
                    .background(.teal, in: RoundedRectangle(cornerRadius: 16))
            }.padding(26).presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    private func instruction(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.title3.bold()).foregroundStyle(.mint).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}


private struct OpeningPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
