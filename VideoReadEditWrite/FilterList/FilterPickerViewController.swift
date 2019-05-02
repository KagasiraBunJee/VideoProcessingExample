//
//  FilterPickerViewController.swift
//  VideoReadEditWrite
//
//  Created by Sergei on 4/29/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import UIKit
import MetalPetal
import AVKit

class FilterPickerViewController: UIViewController {

    private let processingQueue = DispatchQueue(label: "image.processing")
    
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var filterTextContainer: UIView!
    @IBOutlet private weak var loadingSpinner: UIView!
    @IBOutlet private weak var previewImageView: UIImageView!
    @IBOutlet private weak var processingOverlay: UIView!
    @IBOutlet private weak var progressView: UIProgressView!
    @IBOutlet private weak var playButtonView: UIButton!
    @IBOutlet private weak var applyButton: UIButton!
    
    var asset: AVAsset?
    var processedAsset: AVAsset?
    var videoProcessed = false
    
    private var videoWriter: VideoEncoder? = LocalVideoEncoder()
    private var filterManager = MTFilterManager()
    private var filter: MTFilter?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        videoWriter?.delegate = self
        applyButton.isEnabled = false
        generatePreviews()
    }
    
    private func generatePreviews() {
        loadingSpinner.isHidden = false
        processingQueue.async {
            autoreleasepool(invoking: { () in
                
                let filterManager = MTFilterManager()
                filterManager.allFilters.forEach({ (filterType) in
                    if let url = URL(string: FileHelper.filtersPath()+"/default.jpg") {
                        let filter = filterType.init(manager: filterManager)
                        let fileName = filterType.name.replacingOccurrences(of: " ", with: "")+".jpg"
                        filter.inputImage = MTIImage(contentsOf: url, options: nil)
                        if let output = filter.outputImage, let fileUrl = URL(string: FileHelper.filtersPath()+"/"+fileName) {
                            do {
                                try? FileManager.default.removeItem(at: fileUrl)
                                try filterManager.generate(image: output)?.jpegData(compressionQuality: 1.0)?.write(to: fileUrl)
                            } catch let error {
                                debugPrint(error)
                            }
                            
                        }
                    }
                })
                DispatchQueue.main.async { [weak self] in
                    self?.collectionView.reloadData()
                    self?.loadingSpinner.isHidden = true
                }
            })
        }
    }
    
    @IBAction func cancelPicker(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func playButtonTouched(_ sender: Any) {
        let playerVC = AVPlayerViewController()
        if let asset = asset, !videoProcessed {
            let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            playerVC.player = player
        } else if let asset = processedAsset, videoProcessed {
            let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            playerVC.player = player
        }
        playerVC.player?.play()
        self.present(playerVC, animated: true, completion: nil)
    }
    
    func startProcessing() {
        self.processingOverlay.isHidden = false
        self.playButtonView.isHidden = true
        self.progressView.setProgress(0, animated: false)
    }
    
    func finishProcessing() {
        self.processingOverlay.isHidden = true
        self.playButtonView.isHidden = false
        self.progressView.setProgress(1, animated: false)
    }
    
    @IBAction func applyFilterTouched(_ sender: Any) {
        guard let asset = asset else {
            return
        }
        startProcessing()
        videoWriter?.prepare(asset: asset, outputUrl: URL(string: FileHelper.newMediaFilePath(extension: "mp4"))!)
        videoWriter?.start()
    }
}

extension FilterPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        
        if let cell = cell as? FIlterPickerCell {
            DispatchQueue.global(qos: .background).async { [cell = cell] in
                let filterType = MTFilterManager.filters[indexPath.row]
                let fileName = filterType.name.replacingOccurrences(of: " ", with: "")+".jpg"
                let image = UIImage(contentsOfFile: URL(string: FileHelper.filtersPath() + "/" + fileName)!.relativePath)
                DispatchQueue.main.async { [cell = cell, image = image] in
                    cell.filterPreviewImageView.image = image
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        DispatchQueue.global(qos: .background).async { [weak self, filterManager = self.filterManager] in
            self?.filter = MTFilterManager.filters[indexPath.row].init(manager: filterManager)
            let filterType = MTFilterManager.filters[indexPath.row]
            let fileName = filterType.name.replacingOccurrences(of: " ", with: "")+".jpg"
            let image = UIImage(contentsOfFile: URL(string: FileHelper.filtersPath() + "/" + fileName)!.relativePath)
            DispatchQueue.main.async { [weak self, image = image] in
                self?.previewImageView.image = image
                self?.applyButton.isEnabled = true
            }
        }
    }
}

extension FilterPickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return MTFilterManager.filters.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "filterCell", for: indexPath)
    }
    
}

extension FilterPickerViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let maxWidth = (collectionView.frame.width - 4)/5
        return CGSize(width: maxWidth, height: maxWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
}

extension FilterPickerViewController: VideoEncoderDelegate {
    
    func videoEncoder(progress: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.progressView.setProgress(progress, animated: true)
        }
    }
    
    func videoEncoder(finishedSuccessfully outputURL: URL) {
        DispatchQueue.main.async { [weak self] in
            self?.videoProcessed = true
            self?.processedAsset = AVAsset(url: outputURL)
            self?.finishProcessing()
        }
    }
    
    func videoEncoder(finishedWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.finishProcessing()
        }
        debugPrint(error)
    }
    
    func videoEncoder(cvImageBuffer: CVImageBuffer?, imageBufferPool: CVPixelBufferPool?, time: CMTime) -> CVImageBuffer? {
        if let filter = filter, let videoPixelBuffer = cvImageBuffer, let bufferPool = imageBufferPool {
            let image = MTIImage(cvPixelBuffer: videoPixelBuffer, alphaType: .alphaIsOne)
            filter.inputImage = image
            if let outputImage = filter.outputImage {
                var newImgBuffer: CVImageBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, bufferPool, &newImgBuffer)
                filterManager.image(outputImage, to: newImgBuffer!)
                return newImgBuffer
            }
            return cvImageBuffer
        }
        return nil
    }
}
