// Cuts a simulator recording into an App Store app preview:
// 886x1920 portrait, 30 fps, H.264, with the game's music (stereo AAC) faded at the end.
//
// swift tools/make_preview.swift <recording.mov> <music.m4a> <out.mp4> <start-end> [<start-end> ...]
// e.g. swift tools/make_preview.swift raw.mov music-stereo.m4a preview.mp4 2.4-4.8 4.8-16 25.5-37.3
import AVFoundation

let a = CommandLine.arguments
guard a.count >= 5 else { fatalError("usage: make_preview <rec.mov> <music.m4a> <out.mp4> <start-end>...") }
let src = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let music = AVURLAsset(url: URL(fileURLWithPath: a[2]))
let out = URL(fileURLWithPath: a[3])
let ranges = a.dropFirst(4).map { r -> CMTimeRange in
    let p = r.split(separator: "-").map { Double($0)! }
    return CMTimeRange(start: CMTime(seconds: p[0], preferredTimescale: 600),
                       end: CMTime(seconds: p[1], preferredTimescale: 600))
}

let sem = DispatchSemaphore(value: 0)
Task {
    let comp = AVMutableComposition()
    let vSrc = try await src.loadTracks(withMediaType: .video)[0]
    let natural = try await vSrc.load(.naturalSize)
    let v = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    var cursor = CMTime.zero
    for r in ranges {
        try v.insertTimeRange(r, of: vSrc, at: cursor)
        cursor = cursor + r.duration
    }
    let total = cursor

    // music, looped to fill the cut
    let mSrc = try await music.loadTracks(withMediaType: .audio)[0]
    let mDur = try await music.load(.duration)
    let m = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    var at = CMTime.zero
    while at < total {
        let len = min(mDur, total - at)
        try m.insertTimeRange(CMTimeRange(start: .zero, duration: len), of: mSrc, at: at)
        at = at + len
    }
    let mixParams = AVMutableAudioMixInputParameters(track: m)
    let fade = CMTime(seconds: 1.2, preferredTimescale: 600)
    mixParams.setVolumeRamp(fromStartVolume: 0, toEndVolume: 0.9, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.4, preferredTimescale: 600)))
    mixParams.setVolumeRamp(fromStartVolume: 0.9, toEndVolume: 0, timeRange: CMTimeRange(start: total - fade, duration: fade))
    let mix = AVMutableAudioMix()
    mix.inputParameters = [mixParams]

    // scale to 886 wide, centre-crop to 1920 tall
    let render = CGSize(width: 886, height: 1920)
    let s = render.width / natural.width
    let dy = (render.height - natural.height * s) / 2
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: v)
    layer.setTransform(CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: 0, y: dy)), at: .zero)
    let inst = AVMutableVideoCompositionInstruction()
    inst.timeRange = CMTimeRange(start: .zero, duration: total)
    inst.layerInstructions = [layer]
    let vc = AVMutableVideoComposition()
    vc.renderSize = render
    vc.frameDuration = CMTime(value: 1, timescale: 30)
    vc.instructions = [inst]

    try? FileManager.default.removeItem(at: out)
    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    ex.videoComposition = vc
    ex.audioMix = mix
    try await ex.export(to: out, as: .mp4)
    print(String(format: "wrote %@ (%.1f s)", out.lastPathComponent, total.seconds))
    sem.signal()
}
sem.wait()
