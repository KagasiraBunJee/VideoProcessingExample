//
//  FilterPickerViewController.swift
//  VideoReadEditWrite
//
//  Created by Sergei on 4/29/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import UIKit
import MetalPetal

class FilterPickerViewController: UIViewController {

    private let processingQueue = DispatchQueue(label: "image.processing")
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var filterTextContainer: UIView!
    @IBOutlet weak var loadingSpinner: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
    
    @IBAction func finishPicking(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
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
        
        let maxWidth = (collectionView.frame.width - 6)/5
        
        return CGSize(width: maxWidth, height: maxWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        return UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1)
    }
}
