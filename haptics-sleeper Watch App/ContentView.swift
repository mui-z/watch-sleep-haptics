import SwiftUI
import WatchKit
import Combine

struct ContentView: View {
    @StateObject private var breathingManager = BreathingManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("4-8-7呼吸法")
                    .font(.headline)
                    .foregroundColor(.blue)

                // 現在の状態表示
                VStack(spacing: 10) {
                    Text(breathingManager.currentPhase.description)
                        .font(.title2)
                        .foregroundColor(breathingManager.currentPhase.color)
                        .animation(.easeInOut(duration: 0.5), value: breathingManager.currentPhase)

                    if breathingManager.isActive {
                        Text("\(breathingManager.remainingTime)秒")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    if breathingManager.cycleCount > 0 {
                        Text("サイクル: \(breathingManager.cycleCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 80)

                // 呼吸の強度インジケーター
                VStack(spacing: 5) {
                    Text("ハプティクス強度")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Rectangle()
                                .frame(width: 8, height: 20)
                                .foregroundColor(index < breathingManager.currentIntensityLevel ? .green : .gray.opacity(0.3))
                                .animation(.easeInOut(duration: 0.3), value: breathingManager.currentIntensityLevel)
                        }
                    }
                }

                // 開始/停止ボタン
                Button(action: {
                    if breathingManager.isActive {
                        breathingManager.stopBreathing()
                    } else {
                        breathingManager.startBreathing()
                    }
                }) {
                    Text(breathingManager.isActive ? "停止" : "開始")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(breathingManager.isActive ? Color.red : Color.blue)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .animation(.easeInOut(duration: 0.2), value: breathingManager.isActive)
            }
            .padding()
        }
    }
}

// 呼吸のフェーズ
enum BreathingPhase {
    case inhale
    case hold
    case exhale
    case pause

    var description: String {
        switch self {
        case .inhale: return "吸う"
        case .hold: return "止める"
        case .exhale: return "吐く"
        case .pause: return "休憩"
        }
    }

    var color: Color {
        switch self {
        case .inhale: return .green
        case .hold: return .orange
        case .exhale: return .blue
        case .pause: return .gray
        }
    }

    var duration: Int {
        switch self {
        case .inhale: return 4
        case .hold: return 8
        case .exhale: return 7
        case .pause: return 2
        }
    }
}

// 呼吸管理クラス
class BreathingManager: ObservableObject {
    @Published var isActive = false
    @Published var currentPhase: BreathingPhase = .inhale
    @Published var remainingTime = 0
    @Published var cycleCount = 0
    @Published var currentIntensityLevel = 5

    private var timer: Timer?
    private var hapticTimer: Timer?
    private let maxIntensity = 5
    private let intensityDecayRate = 0.1 // サイクルごとに減少する量

    func startBreathing() {
        isActive = true
        cycleCount = 0
        currentIntensityLevel = maxIntensity
        currentPhase = .inhale
        remainingTime = currentPhase.duration

        startPhaseTimer()
        startHapticFeedback()
    }

    func stopBreathing() {
        isActive = false
        timer?.invalidate()
        hapticTimer?.invalidate()
        timer = nil
        hapticTimer = nil
    }

    private func startPhaseTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.remainingTime -= 1

            if self.remainingTime <= 0 {
                self.nextPhase()
            }
        }
    }

    private func nextPhase() {
        switch currentPhase {
        case .inhale:
            currentPhase = .hold
            // フェーズ変更時に2回クリック
            playPhaseChangeHaptic()
        case .hold:
            currentPhase = .exhale
            // フェーズ変更時に2回クリック
            playPhaseChangeHaptic()
        case .exhale:
            currentPhase = .pause
            // フェーズ変更時に2回クリック
            playPhaseChangeHaptic()
        case .pause:
            currentPhase = .inhale
            cycleCount += 1
            // 強度を徐々に減らす
            let newIntensity = max(1, maxIntensity - Int(Double(cycleCount) * intensityDecayRate))
            currentIntensityLevel = newIntensity

            // サイクル完了時に3回クリック
            playSetCompleteHaptic()
        }

        remainingTime = currentPhase.duration

        // フェーズ変更時にハプティクスを再開
        hapticTimer?.invalidate()
        startHapticFeedback()
    }

    private func startHapticFeedback() {
        let hapticInterval = getHapticInterval()
        let hapticType = getHapticType()

        hapticTimer = Timer.scheduledTimer(withTimeInterval: hapticInterval, repeats: true) { _ in
            self.playHaptic(hapticType)
        }

        // 最初のハプティクスをすぐに再生
        playHaptic(hapticType)
    }

    private func getHapticInterval() -> TimeInterval {
        switch currentPhase {
        case .inhale:
            return 0.8 // ゆっくりとしたリズム
        case .hold:
            return 2.0 // 長い間隔
        case .exhale:
            return 0.6 // 少し早いリズム
        case .pause:
            return 1.0 // 休憩のリズム
        }
    }

    private func getHapticType() -> WKHapticType {
        // 全てのフェーズでクリックハプティクスのみ使用
        return .click
    }

    private func playHaptic(_ type: WKHapticType) {
        guard isActive else { return }

        // 音を鳴らさずにハプティクスのみ再生
        // 強度に基づいて複数回再生することで強度を表現
        let playCount = currentIntensityLevel

        for i in 0..<playCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                // クリックハプティクスのみ使用（音なし）
                WKInterfaceDevice.current().play(.click)
//              WKInterfaceDevice.current().play(.navigationGenericManeuver)
            }
        }
    }

    // セット完了時の特別なハプティクス（3回クリック）
    private func playSetCompleteHaptic() {
        guard isActive else { return }

        // 1回目のクリック
        WKInterfaceDevice.current().play(.success)
    }

    // フェーズ変更時のハプティクス（2回クリック）
    private func playPhaseChangeHaptic() {
        guard isActive else { return }

        // 1回目のクリック
        WKInterfaceDevice.current().play(.success)
    }
}

// 設定画面
struct SettingsView: View {
    @StateObject private var breathingManager = BreathingManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                Text("設定")
                    .font(.headline)

                Text("4-8-7呼吸法について")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 5) {
                    Text("• 4秒間息を吸う")
                    Text("• 8秒間息を止める")
                    Text("• 7秒間息を吐く")
                    Text("• 2秒間休憩")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    Text("ハプティクスの特徴:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("• サイクルを重ねるごとに強度が減少")
                    Text("• 全フェーズでクリックハプティクス使用")
                    Text("• 音なし、ハプティクスのみ")
                    Text("• リラックス効果をサポート")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
