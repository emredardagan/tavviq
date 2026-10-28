// Cuts a simulator recording into an App Store app preview:
// 886x1920 portrait, 30 fps, H.264 (High, level 4.0), with the game's music as
// stereo AAC at 256 kbps / 44.1 kHz (the bit rate App Store Connect requires), faded at the end.
//
// swift tools/make_preview.swift <recording.mov> <music.m4a> <out.mp4> <start-end> [<start-end> ...]
// e.g. swift tools/make_preview.swift raw.mov music-stereo.m4a preview.mp4 2.4-4.8 4.8-16 25.5-37.3
//
// Fix only the audio of an existing preview (video is copied untouched):
// swift tools/make_preview.swift --fix-audio <in.mp4> <out.mp4>
import AVFoundation

/// Copies the video samples as they are and re-encodes the audio to 256 kbps stereo AAC.
/// AVAssetExportSession picks its own (lower) audio bit rate, so this always runs last.
func remuxAudio(_ input: URL, _ output: URL) async throws {
    let asset = AVURLAsset(url: input)
    let reader = try AVAssetReader(asset: asset)
    try? FileManager.default.removeItem(at: output)
    let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)

    let vTrack = try await asset.loadTracks(withMediaType: .video)[0]
    let vFormat = try await vTrack.load(.formatDescriptions).first
    let vOut = AVAssetReaderTrackOutput(track: vTrack, outputSettings: nil)
    reader.add(vOut)
    let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: vFormat)
    vIn.expectsMediaDataInRealTime = false
    writer.add(vIn)

    let aTrack = try await asset.loadTracks(withMediaType: .audio)[0]
    let aOut = AVAssetReaderTrackOutput(track: aTrack, outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
    ])
    reader.add(aOut)
    let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 256_000,
    ])
    aIn.expectsMediaDataInRealTime = false
    writer.add(aIn)

    reader.startReading()
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    await withTaskGroup(of: Void.self) { group in
        for (input, output, label) in [(vIn, vOut, "v"), (aIn, aOut, "a")] {
            group.addTask {
                await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                    input.requestMediaDataWhenReady(on: DispatchQueue(label: label)) {
                        while input.isReadyForMoreMediaData {
                            guard let buf = output.copyNextSampleBuffer() else {
                                input.markAsFinished()
                                done.resume()
                                return
                            }
                            input.append(buf)
                        }
                    }
                }
            }
        }
    }
    await writer.finishWriting()
    if let e = writer.error ?? reader.error { throw e }
}

func build(_ a: [String]) async throws {
    let src = AVURLAsset(url: URL(fileURLWithPath: a[1]))
    let music = AVURLAsset(url: URL(fileURLWithPath: a[2]))
    let out = URL(fileURLWithPath: a[3])
    let ranges = a.dropFirst(4).map { r -> CMTimeRange in
        let p = r.split(separator: "-").map { Double($0)! }
        return CMTimeRange(start: CMTime(seconds: p[0], preferredTimescale: 600),
                           end: CMTime(seconds: p[1], preferredTimescale: 600))
    }

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

    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("preview-\(UUID().uuidString).mp4")
    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    ex.videoComposition = vc
    ex.audioMix = mix
    try await ex.export(to: tmp, as: .mp4)
    try await remuxAudio(tmp, out)
    try? FileManager.default.removeItem(at: tmp)
    print(String(format: "wrote %@ (%.1f s)", out.lastPathComponent, total.seconds))
}

let args = CommandLine.arguments
let sem = DispatchSemaphore(value: 0)
Task {
    do {
        if args.count == 4, args[1] == "--fix-audio" {
            try await remuxAudio(URL(fileURLWithPath: args[2]), URL(fileURLWithPath: args[3]))
            print("wrote \(args[3])")
        } else if args.count >= 5 {
            try await build(args)
        } else {
            print("usage: make_preview <rec.mov> <music.m4a> <out.mp4> <start-end>... | --fix-audio <in.mp4> <out.mp4>")
        }
    } catch {
        print("error:", error)
    }
    sem.signal()
}
sem.wait()
