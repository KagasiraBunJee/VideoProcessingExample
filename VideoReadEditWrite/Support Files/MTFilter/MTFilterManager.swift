//
//  MTFilterManager.swift
//  MetalFilters
//
//  Created by xushuifeng on 2018/6/10.
//  Copyright © 2018 shuifeng.me. All rights reserved.
//

import Foundation
import UIKit
import MetalPetal
import AVFoundation

class MTFilterManager {

    static let shard = MTFilterManager()
    static let filters: [MTFilter.Type] = {
        return [
            MTNormalFilter.self,
            MTClarendonVideoFilter.self,
            MTGinghamVideoFilter.self,
            MTMoonVideoFilter.self,
            MTLarkFilter.self,
            MTReyesFilter.self,
            MTJunoFilter.self,
            MTSlumberFilter.self,
            MTCremaFilter.self,
            MTLudwigFilter.self,
            MTAdenFilter.self,
            MTPerpetuaFilter.self,
            MTAmaroFilter.self,
            MTMayfairFilter.self,
            MTRiseFilter.self,
            MTHudsonFilter.self,
            MTValenciaFilter.self,
            MTXpro2Filter.self,
            MTSierraFilter.self,
            MTWillowFilter.self,
            MTLoFiFilter.self,
            MTEarlybirdFilter.self,
            MTBrannanFilter.self,
            MTInkwellFilter.self,
            MTHefeFilter.self,
            MTNashvilleFilter.self,
            MTSutroFilter.self,
            MTToasterFilter.self,
            MTWaldenFilter.self,
            MT1977Filter.self,
            MTKelvinFilter.self,
            MTStinsonVideoFilter.self,
            MTVesperVideoFilter.self,
            MTMavenVideoFilter.self,
            MTGinzaVideoFilter.self,
            MTSkylineVideoFilter.self,
            MTDogpatchVideoFilter.self,
            MTBrooklynVideoFilter.self,
            MTHelenaVideoFilter.self,
            MTAshbyVideoFilter.self,
            MTCharmesVideoFilter.self
        ]
    }()

    var allFilters: [MTFilter.Type] = []

    private var resourceBundle: Bundle

    private var context: MTIContext?

    init() {

        allFilters.append(MTNormalFilter.self)
        allFilters.append(MTClarendonVideoFilter.self)
        allFilters.append(MTGinghamVideoFilter.self)
        allFilters.append(MTMoonVideoFilter.self)
        allFilters.append(MTLarkFilter.self)
        allFilters.append(MTReyesFilter.self)
        allFilters.append(MTJunoFilter.self)
        allFilters.append(MTSlumberFilter.self)
        allFilters.append(MTCremaFilter.self)
        allFilters.append(MTLudwigFilter.self)
        allFilters.append(MTAdenFilter.self)
        allFilters.append(MTPerpetuaFilter.self)
        allFilters.append(MTAmaroFilter.self)
        allFilters.append(MTMayfairFilter.self)
        allFilters.append(MTRiseFilter.self)
        allFilters.append(MTHudsonFilter.self)
        allFilters.append(MTValenciaFilter.self)
        allFilters.append(MTXpro2Filter.self)
        allFilters.append(MTSierraFilter.self)
        allFilters.append(MTWillowFilter.self)
        allFilters.append(MTLoFiFilter.self)
        allFilters.append(MTEarlybirdFilter.self)
        allFilters.append(MTBrannanFilter.self)
        allFilters.append(MTInkwellFilter.self)
        allFilters.append(MTHefeFilter.self)
        allFilters.append(MTNashvilleFilter.self)
        allFilters.append(MTSutroFilter.self)
        allFilters.append(MTToasterFilter.self)
        allFilters.append(MTWaldenFilter.self)
        allFilters.append(MT1977Filter.self)
        allFilters.append(MTKelvinFilter.self)
        allFilters.append(MTStinsonVideoFilter.self)
        allFilters.append(MTVesperVideoFilter.self)
        allFilters.append(MTMavenVideoFilter.self)
        allFilters.append(MTGinzaVideoFilter.self)
        allFilters.append(MTSkylineVideoFilter.self)
        allFilters.append(MTDogpatchVideoFilter.self)
        allFilters.append(MTBrooklynVideoFilter.self)
        allFilters.append(MTHelenaVideoFilter.self)
        allFilters.append(MTAshbyVideoFilter.self)
        allFilters.append(MTCharmesVideoFilter.self)

        context = try? MTIContext(device: MTLCreateSystemDefaultDevice()!)

        let url = Bundle.main.url(forResource: "FilterAssets", withExtension: "bundle")!
        resourceBundle = Bundle(url: url)!
    }

    deinit {
        debugPrint("deinit VideoFilterPresenterImp")
    }

    func url(forResource name: String) -> URL? {
        return resourceBundle.url(forResource: name, withExtension: nil)
    }

    func generateThumbnailsForImage(_ image: UIImage?, with type: MTFilter.Type) -> UIImage? {
        guard let cgImage = image?.cgImage else { return nil }
        let inputImage = MTIImage(cgImage: cgImage, options: [.SRGB: false], alphaType: .alphaIsOne)
        let filter = type.init(manager: self)
        filter.inputImage = inputImage
        if let cgImage = try? context?.makeCGImage(from: filter.outputImage!) {
            return UIImage(cgImage: cgImage!)
        }
        return nil
    }

    func generate(image: MTIImage) -> UIImage? {
        if let cgImage = try? context?.makeCGImage(from: image) {
            return UIImage(cgImage: cgImage!)
        }
        return nil
    }

    func generateCI(image: MTIImage) -> CIImage? {
        if let ciImage = try? context?.makeCIImage(from: image) {
            return ciImage
        }
        return nil
    }

    func image(_ image: MTIImage, to pixelBuffer: CVImageBuffer) {
        try? context?.render(image, to: pixelBuffer)
    }

    func imageTask(_ image: MTIImage, to pixelBuffer: CVImageBuffer) throws -> MTIRenderTask {
        return try self.context!.startTask(toRender: image, to: pixelBuffer, sRGB: false)
    }

    func flush() {
        context?.reclaimResources()
    }
}
