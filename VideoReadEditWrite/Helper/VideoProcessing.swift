//
//  VideoWriter.swift
//  VideoReadEditWrite
//
//  Created by Sergei on 4/24/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import UIKit
import AVFoundation

protocol VideoProcessingDelegate: class {
    func videoProcessing(finishedWithError error: Error?)
    func videoProcessing(finishedSuccessfully outputURL: URL)
    func videoProcessing(cvImageBuffer: CVImageBuffer?, imageBufferPool: CVPixelBufferPool?) -> CVImageBuffer?
    func videoProcessing(progress: Float)
}

class VideoProcessing: NSObject {
    
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
    
    weak var delegate: VideoProcessingDelegate?
    
    override init() {
        super.init()
    }
    
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
        if let reader = assetReader,
            let writer = assetWriter,
            let readerVideo = assetReaderVideoOutput,
            let readerAudio = assetReaderAudioOutput,
            let writerVideo = assetWriterVideoInput,
            let writerAudio = assetWriterAudioInput,
            let adaptor = assetWriterVideoInputAdaptor
        {
            
            guard reader.startReading(), writer.startWriting() else { return }
            writer.startSession(atSourceTime: .zero)
    
            processVideoQueue.async { [weak self] in
                
                self?.dispatchgroup = DispatchGroup()
                self?.dispatchgroup?.enter()
                
                writerVideo.requestMediaDataWhenReady(on: self!.writeVideoQueue) { [weak self] in
                    var complete = false
                    while writerVideo.isReadyForMoreMediaData && !complete {
                        var sample = readerVideo.copyNextSampleBuffer()
                        if let sampleBuffer = sample, let duration = self?.asset?.duration {
                            
                            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            let progress = CMTimeGetSeconds(time)/CMTimeGetSeconds(duration)
                            self?.delegate?.videoProcessing(progress: Float(progress))
                            
                            let newSample = autoreleasepool(invoking: { [adaptor = adaptor] () -> (pixelBuffer: CVImageBuffer?, time: CMTime) in
                                
                                let imgBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                                
                                if let delegateBuffer = self?.delegate?.videoProcessing(cvImageBuffer: imgBuffer, imageBufferPool: adaptor.pixelBufferPool) {
                                    return (delegateBuffer, time)
                                }
                                
                                return (imgBuffer, time)
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
                
                self?.dispatchgroup?.enter()
                writerAudio.requestMediaDataWhenReady(on: self!.writeAudioQueue, using: {
                    var complete = false
                    while writerAudio.isReadyForMoreMediaData && !complete {
                        var sample = readerAudio.copyNextSampleBuffer()
                        if sample != nil {
                            let newSample = autoreleasepool(invoking: { () -> CMSampleBuffer? in
                                return sample
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
                                    self?.delegate?.videoProcessing(finishedSuccessfully: url)
                                }
                            }
                        })
                    } else {
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.videoProcessing(finishedWithError: error)
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
