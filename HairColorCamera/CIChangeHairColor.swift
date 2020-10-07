//
//  CIChangeHairColor.swift
//  HairColorCamera
//
//  Created by yogox on 2020/10/07.
//  Copyright © 2020 Yogox Galaxy. All rights reserved.
//

import CoreImage.CIFilterBuiltins


class CIChangeHairColor: CIFilter {
    var inputImage: CIImage?
    var hairMatteImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
            , let hairMatteImage = hairMatteImage
        else { return nil }
        
        // TODO: 髪の毛の色を変更する処理を作成するまではそのまま戻す
        return inputImage
    }
}
