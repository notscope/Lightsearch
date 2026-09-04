//
//  ColorPickerController.swift
//  Lightsearch
//

import AppKit

@MainActor
final class ColorPickerController {
    private static let screenshotSoundPaths = [
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif",
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Shutter.aif",
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif"
    ]

    private static let selectionSound: NSSound? = {
        for path in screenshotSoundPaths {
            if let sound = NSSound(contentsOfFile: path, byReference: true) {
                return sound
            }
        }
        return nil
    }()

    private var completion: ((NSColor) -> Void)?
    private var sampler: NSColorSampler?

    func start(onPick: @escaping (NSColor) -> Void) {
        cancel()
        completion = onPick

        let sampler = NSColorSampler()
        self.sampler = sampler

        Task { @MainActor [weak self] in
            guard let self, let sampler = self.sampler else { return }
            let selectedColor = await sampler.sample()

            guard self.sampler === sampler else { return }
            let completion = self.completion
            self.sampler = nil
            self.completion = nil
            if let selectedColor {
                completion?(selectedColor)
                Self.selectionSound?.play()
            }
        }
    }

    func cancel() {
        sampler = nil
        completion = nil
    }
}
