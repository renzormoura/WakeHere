import Foundation
import AVFoundation
import AudioToolbox

/// Toca o som do alarme em tela cheia (Foreground).
///
/// Usa `AlarmTone.wav` em loop quando presente no bundle; caso contrário,
/// cai para um beep do sistema + vibração em loop (nunca falha).
final class AlarmSoundPlayer {
    private var audioPlayer: AVAudioPlayer?
    private var beepTimer: Timer?
    private var volume: Float = 1.0
    private(set) var isPlaying = false

    func start(volume: Float) {
        guard !isPlaying else { return }
        isPlaying = true
        self.volume = max(0, min(1, volume))

        activateAudioSession()

        if let url = Bundle.main.url(forResource: "AlarmTone", withExtension: "wav"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            audioPlayer = player
            player.numberOfLoops = -1
            player.volume = self.volume
            player.prepareToPlay()
            player.play()
        } else {
            startBeeping()
        }
    }

    func stop() {
        isPlaying = false
        audioPlayer?.stop()
        audioPlayer = nil
        beepTimer?.invalidate()
        beepTimer = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private func startBeeping() {
        let timer = Timer(timeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.beep()
        }
        RunLoop.main.add(timer, forMode: .common)
        beepTimer = timer
        timer.fire()
    }

    private func beep() {
        AudioServicesPlaySystemSound(1005) // tom de alerta do sistema
        if volume > 0.5 {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
}
