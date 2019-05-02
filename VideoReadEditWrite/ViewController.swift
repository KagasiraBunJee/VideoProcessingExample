//
//  ViewController.swift
//  VideoReadEditWrite
//
//  Created by Sergei on 4/24/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import UIKit
import MetalPetal
import Photos
import AVFoundation
import AVKit

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var randomFilterAction: UIButton!
    
    var selectedAsset: AVAsset?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        acquirePermissions()
        progressView.setProgress(0, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func download() {
        
    }
    
    func acquirePermissions() {
        
        let galleryStatus = PHPhotoLibrary.authorizationStatus()
        switch galleryStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { (status) in
                debugPrint(status)
            }
        default:
            return
        }
    }
    
    @IBAction func getVideo(_ sender: Any) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.allowsEditing = true
            imagePickerController.mediaTypes = ["public.movie"]
            imagePickerController.videoMaximumDuration = 30
            self.present(imagePickerController, animated: true, completion: nil)
        }
    }
    
    @IBAction func saveVideo(_ sender: Any) {
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
                if let outputURL = URL(string: FileHelper.newMediaFilePath(extension: "mp4")) {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                }
            }, completionHandler: { (complete, error) in
                if complete {
                    debugPrint("in gallery")
                }
            })
        }
    }
    
    @IBAction func watchResult(_ sender: Any) {
        if let url = URL(string: FileHelper.newMediaFilePath(extension: "mp4")) {
            let playerController = AVPlayerViewController()
            playerController.player = AVPlayer(playerItem: AVPlayerItem(asset: AVAsset(url: url)))
            self.present(playerController, animated: true, completion: nil)
        }
    }
    
    @IBAction func applyRandomFilter(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "FilterPickerViewController") as! FilterPickerViewController
        vc.asset = self.selectedAsset
        self.navigationController?.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func reencodeAction(_ sender: Any) {
        
    }
    
    func makeImagePreview() {
        guard let asset = selectedAsset else { return }
        if let cgImage = try? AVAssetImageGenerator(asset: asset).copyCGImage(at: .zero, actualTime: nil) {
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            imageView.image = image
            
            let previewImagePath = FileHelper.filtersPath()
            if FileHelper.validateDirectory(path: previewImagePath, createIfNotExists: true) {
                do {
                    try image.jpegData(compressionQuality: 0.5)?.write(to: URL(string: previewImagePath+"/default.jpg")!)
                    self.showAlert(text: "default image created")
                } catch let error {
                    self.showAlert(text: error.localizedDescription)
                }
            } else {
                self.showAlert(text: "there is no dir " + previewImagePath)
            }
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        debugPrint(info)
        if let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
            selectedAsset = AVAsset(url: url)
            picker.dismiss(animated: true, completion: nil)
            makeImagePreview()
        }
    }
}

extension UIViewController {
    
    func showAlert(text: String) {
        let alertVC = UIAlertController(title: "Test", message: text, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertVC.addAction(okAction)
        self.present(alertVC, animated: true, completion: nil)
    }
    
}
