//
//  VideoWriter.swift
//  VideoReadEditWrite
//
//  Created by Sergei on 4/24/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import UIKit
import AVFoundation

@objc
protocol VideoEncoderDelegate: class {
    /**
     Defines when read or write has been finished with error and has not applied any changes.
     
     - parameters:
        - error: Defines an error for operation
    */
    @objc optional func videoEncoder(finishedWithError error: Error?)
    
    /**
     Defines when encoding successfuly finished with output URL link for file
     
     - parameters:
        - outputURL: URL for encoded and edited file.
     */
    @objc optional func videoEncoder(finishedSuccessfully outputURL: URL)
    
    /**
     Defines delegate method which comes with each video frame buffer and it's buufer pool it relates to and each frame time.
     Incoming buffer is immutable and you should only use it for processing or editing in it's own pool it is allocated in
     and return only new processed/edited or default one. Do not create another queues inside this delegate.
     Do all work inside this method scope, queue and pool for performance.
     
     - parameters:
        - cvImageBuffer: Frame's video pixel buffer
        - imageBufferPool: Frame's video pixel buffer pool
        - time: Frame's time in video
     */
    @objc optional func videoEncoder(cvImageBuffer: CVImageBuffer?, imageBufferPool: CVPixelBufferPool?, time: CMTime) -> CVImageBuffer?
    
    /**
     Defines delegate method which comes with audio buffer in media file. All buffer processing perform in scope of this method, including queue.
     
     - parameters:
        - audioBuffer: Video's audio buffer
        - time: Frame's time in video
     */
    @objc optional func videoEncoder(audioBuffer: CMSampleBuffer?, time: CMTime) -> CMSampleBuffer?
    
    /**
     Tracks writing progress
     
     - parameters:
        - progress: Current writing progress. (from 0.0 to 1.0)
     */
    @objc optional func videoEncoder(progress: Float)
}

protocol VideoEncoder: class {
    var delegate: VideoEncoderDelegate? { get set }
    
    func prepare(asset: AVAsset, outputUrl: URL)
    func start()
}

class LocalVideoEncoder: VideoEncoder {
    
    //reader
    private var assetReader: AVAssetReader?
    private var assetReaderVideoOutput: AVAssetReaderTrackOutput?
    private var assetReaderAudioOutput: AVAssetReaderTrackOutput?
    
    //writer
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var assetWriterAudioInput: AVAssetWriterInput?
    private var assetWriterVideoInputAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    //videoInfo
    private var originalVideoSize: CGSize = .zero
    private var originalVideoTransform: CGAffineTransform = .identity
    /** An asset to be processed */
    private(set) var asset: AVAsset?
    /** Output file location (URL must be isFileType true) */
    private(set) var outputUrl: URL?
    
    /** Video processing queue */
    private let writeVideoQueue = DispatchQueue(label: "video.processing")
    /** Audio processing queue */
    private let writeAudioQueue = DispatchQueue(label: "audio.processing")
    /** Finish writing queue */
    private let processVideoQueue = DispatchQueue(label: "video.finish")
    /** Audio and video queue synchronyzer */
    private var dispatchgroup: DispatchGroup?
    
    /** The object that acts as the delegate of the video encoder. */
    weak var delegate: VideoEncoderDelegate?
    
    init() {}
    
    /**
     Prepare asset for processing, setting output URL for output file
     
     - parameters:
        - asset: An asset to be processed
        - outputUrl: Output file location (URL must be isFileType true)
     
     - Important:
     An asset must be media type (audio or video)!
     */
    func prepare(asset: AVAsset, outputUrl: URL) {
        self.asset = asset
        self.outputUrl = outputUrl
        prepareReader()
        prepareWriter()
    }
    
    /** Start reencoding asset */
    func start() {
        if let reader = assetReader, let writer = assetWriter {
            guard reader.startReading(), writer.startWriting() else { return }
            writer.startSession(atSourceTime: .zero)
    
            processVideoQueue.async { [weak self] in
                
                self?.dispatchgroup = DispatchGroup()

                if let writerVideo = self?.assetWriterVideoInput,
                    let adaptor = self?.assetWriterVideoInputAdaptor,
                    let readerVideo = self?.assetReaderVideoOutput
                {
                    self?.dispatchgroup?.enter()
                    writerVideo.requestMediaDataWhenReady(on: self!.writeVideoQueue) { [weak self] in
                        var complete = false
                        while writerVideo.isReadyForMoreMediaData && !complete {
                            var sample = readerVideo.copyNextSampleBuffer()
                            if let sampleBuffer = sample, let duration = self?.asset?.duration {
                                
                                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                                let progress = CMTimeGetSeconds(time)/CMTimeGetSeconds(duration)
                                self?.delegate?.videoEncoder?(progress: Float(progress))
                                
                                let newSample = autoreleasepool(invoking: { [adaptor = adaptor] () -> (pixelBuffer: CVImageBuffer?, time: CMTime) in
                                    let imgBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                                    let newBuffer = self?.delegate?.videoEncoder?(cvImageBuffer: imgBuffer, imageBufferPool: adaptor.pixelBufferPool, time: time) ?? imgBuffer
                                    return (newBuffer, time)
                                })
                                
                                adaptor.append(newSample.pixelBuffer!, withPresentationTime: newSample.time)
                                sample = nil
                            } else {
                                writerVideo.markAsFinished()
                                complete = true
                            }
                        }
                        
                        if complete {
                            self?.dispatchgroup?.leave()
                        }
                    }
                }
                
                if let writerAudio = self?.assetWriterAudioInput,
                    let readerAudio = self?.assetReaderAudioOutput
                {
                    self?.dispatchgroup?.enter()
                    writerAudio.requestMediaDataWhenReady(on: self!.writeAudioQueue, using: {
                        var complete = false
                        while writerAudio.isReadyForMoreMediaData && !complete {
                            var sample = readerAudio.copyNextSampleBuffer()
                            if sample != nil {
                                let time = CMSampleBufferGetPresentationTimeStamp(sample!)
                                let newSample = autoreleasepool(invoking: { () -> CMSampleBuffer? in
                                    return self?.delegate?.videoEncoder?(audioBuffer: sample, time: time) ?? sample
                                })
                                writerAudio.append(newSample!)
                                sample = nil
                            } else {
                                writerAudio.markAsFinished()
                                complete = true
                            }
                        }
                        if complete {
                            self?.dispatchgroup?.leave()
                        }
                    })
                }
                
                self?.dispatchgroup?.notify(queue: self!.processVideoQueue) { [weak self] in
                    
                    var processingFinished = true
                    var error: Error?
                    
                    if reader.status == .failed {
                        processingFinished = false
                        error = reader.error
                    }
                    
                    if processingFinished {
                        if writer.error != nil {
                            error = writer.error
                            processingFinished = false
                        }
                    }
                    
                    if processingFinished {
                        self?.assetWriter?.finishWriting(completionHandler: {
                            if let url = self?.outputUrl {
                                DispatchQueue.main.async { [weak self] in
                                    self?.delegate?.videoEncoder?(finishedSuccessfully: url)
                                }
                            }
                        })
                    } else {
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.videoEncoder?(finishedWithError: error)
                        }
                    }
                }
            }
        }
    }
    
    private func prepareReader() {
        guard let asset = asset else { return }
        assetReader = try? AVAssetReader(asset: asset)
        guard let reader = assetReader else { return }
        
        asset.tracks.forEach {
            switch $0.mediaType {
            case .video:
                originalVideoSize = $0.naturalSize
                originalVideoTransform = $0.preferredTransform
                let settings = [
                    kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                    kCVPixelBufferWidthKey: originalVideoSize.width,
                    kCVPixelBufferHeightKey: originalVideoSize.height
                ] as! [String: Any]
                assetReaderVideoOutput = AVAssetReaderTrackOutput(track: $0, outputSettings: settings)
                assetReaderVideoOutput?.alwaysCopiesSampleData = false
                reader.add(assetReaderVideoOutput!)
            case .audio:
                assetReaderAudioOutput = AVAssetReaderTrackOutput(track: $0, outputSettings: nil)
                assetReaderAudioOutput?.alwaysCopiesSampleData = false
                reader.add(assetReaderAudioOutput!)
            default:
                break
            }
        }
    }
    
    private func prepareWriter() {
        guard let fileURL = outputUrl, fileURL.isFileURL else { return }
        do {
            try? FileManager.default.removeItem(at: fileURL)
            assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mov)
            guard let writer = assetWriter else { return }
            
            let videoWriterSettings = [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: originalVideoSize.width,
                AVVideoHeightKey: originalVideoSize.height
            ] as [String : Any]
            
            assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoWriterSettings)
            assetWriterVideoInput?.expectsMediaDataInRealTime = true
            assetWriterVideoInput?.transform = originalVideoTransform
            assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            assetWriterAudioInput?.expectsMediaDataInRealTime = true
            
            if let input = assetWriterVideoInput {
                let settings = [
                    kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
                    ] as! [String: Any]
                assetWriterVideoInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: settings)
                writer.add(input)
            }
            
            if let input = assetWriterAudioInput {
                writer.add(input)
            }
            
        } catch let error {
            debugPrint(error)
        }
    }
}
