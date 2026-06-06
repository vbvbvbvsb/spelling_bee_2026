import AudioToolbox
import UIKit

enum FeedbackService {
    static func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if let soundName = AppTheme.successSoundName,
           let url = Bundle.main.url(forResource: soundName, withExtension: nil) {
            var soundID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
            AudioServicesPlaySystemSound(soundID)
        } else {
            AudioServicesPlaySystemSound(1057)
        }
    }

    static func playMiss() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        guard let soundName = AppTheme.missSoundName,
              let url = Bundle.main.url(forResource: soundName, withExtension: nil) else {
            return
        }

        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        AudioServicesPlaySystemSound(soundID)
    }
}
