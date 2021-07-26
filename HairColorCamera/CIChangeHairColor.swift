//
//  CIChangeHairColor.swift
//  HairColorCamera
//
//  Created by yogox on 2020/10/07.
//  Copyright © 2020 Yogox Galaxy. All rights reserved.
//

import CoreImage.CIFilterBuiltins

extension CIImage {
    func getColorAtPoint (point: CGPoint = CGPoint(x: 0, y: 0)) -> CIColor {
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(self, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: point.x, y: point.y, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let redInteger = Int(bitmap[0].description) ?? 0
        let redc = CGFloat(redInteger)/255
        let greenInteger = Int(bitmap[1].description) ?? 0
        let greenc = CGFloat(greenInteger)/255
        let blueInteger = Int(bitmap[2].description) ?? 0
        let bluec = CGFloat(blueInteger)/255
        let alphaInteger = Int(bitmap[3].description) ?? 0
        let alphac = CGFloat(alphaInteger)/255
        
        let color = CIColor(red: redc, green: greenc, blue: bluec, alpha: alphac)
        
        return color
    }
}

class CILightnessInfo: CIFilter {
    let batchSize = 500
    var inputImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        
        let scaleFilter = CIFilter.bicubicScaleTransform()
        let scale = CGFloat(batchSize) / max(inputImage.extent.width, inputImage.extent.height)
        scaleFilter.inputImage = inputImage
        scaleFilter.scale = Float(scale)
        scaleFilter.parameterB = 1
        scaleFilter.parameterC = 0

        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        let kernel = try! CIKernel(functionName: "minMaxModeLightness", fromMetalLibraryData: data)
        let outputImage = kernel.apply(extent: CGRect(x: 0, y: 0, width: 1, height: 1),
                                       roiCallback: { index, rect in
                                        return scaleFilter.outputImage!.extent
                                       },
                                       arguments: [scaleFilter.outputImage!])
        
        return outputImage
    }
}

class CIResizeImageWith: CIFilter {
    var inputImage: CIImage?
    var backgroundImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
        , let backgraoundImage = backgroundImage
        else { return nil }
        
        // Matte画像に合わせて写真のスケールを縮小
        let scaleFilter = CIFilter.lanczosScaleTransform()
        let targetHeight = backgraoundImage.extent.height
        let baseHight = inputImage.extent.height
        scaleFilter.inputImage = inputImage
        scaleFilter.scale = Float(targetHeight / baseHight)
        scaleFilter.aspectRatio = 1.0
        
        return scaleFilter.outputImage!
    }
}

class CICutoutSegmentGray: CIFilter {
    var inputImage: CIImage?
    var matteImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
            , let matteImage = matteImage
        else { return nil }
        
        // マット画像のアルファを変更
        let maskFilter = CIFilter.maskToAlpha()
        maskFilter.inputImage = matteImage

        // マット領域で写真を切り抜き
        let cutFilter = CIFilter.sourceInCompositing()
        cutFilter.inputImage = inputImage
        cutFilter.backgroundImage = maskFilter.outputImage!
        
        // 切り抜いたマット領域を輝度でグレースケール変換
        let grayFilter = CIFilter.falseColor()
        grayFilter.inputImage = cutFilter.outputImage!
        grayFilter.color0 = CIColor.black
        grayFilter.color1 = CIColor.white

        return grayFilter.outputImage!
    }
}

class CIIkaHairGradient: CIFilter {
    var minPoint = CGFloat(0.0)
    var modePoint = CGFloat(0.5)
    var maxPoint = CGFloat(1.0)
    var minColor: CIColor?
    var modeColor: CIColor?
    var maxColor: CIColor?
    
    override var outputImage: CIImage? {
        guard let minColor = minColor
            , let modeColor = modeColor
            , let maxColor = maxColor
        else { return nil }
        
        // 合成用フィルターを定義
        let compositeFilter = CIFilter.sourceOverCompositing()

        //TODO: maxLightnessを参照して明るさを落としたい

        // グラデーションマップの左側を作成
        let gradientFilter = CIFilter.smoothLinearGradient()
        gradientFilter.point0 = CGPoint(x: minPoint * 1000, y: 0)
        gradientFilter.color0 = minColor
        gradientFilter.point1 = CGPoint(x: modePoint * 1000, y: 0)
        gradientFilter.color1 = modeColor
        compositeFilter.inputImage = gradientFilter.outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: modePoint * 1000, height: 480))
        
        // グラデーションマップの右側を作成
        gradientFilter.point0 = CGPoint(x: modePoint * 1000, y: 0)
        gradientFilter.color0 = modeColor
        gradientFilter.point1 = CGPoint(x: maxPoint * 1000, y: 0)
        gradientFilter.color1 = maxColor
        compositeFilter.backgroundImage = gradientFilter.outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: 1000, height: 480))

        return compositeFilter.outputImage!
    }
}

class CIChangeHairColor: CIFilter {
    var inputImage: CIImage?
    var hairMatteImage: CIImage?
    var minColor: CIColor?
    var modeColor: CIColor?
    var maxColor: CIColor?
    var printRange = false

    override var outputImage: CIImage? {
        guard let inputImage = inputImage
            , let hairMatteImage = hairMatteImage
            , let minColor = minColor
            , let modeColor = modeColor
            , let maxColor = maxColor
        else { return nil }
        
        // 写真に合わせてMatte画像のスケールを拡大
        let resizeFilter = CIResizeImageWith()
        resizeFilter.inputImage = inputImage
        resizeFilter.backgroundImage = hairMatteImage
        
        // マット画像で写真を切り抜いて、グレースケール変換
        let cutoutFilter = CICutoutSegmentGray()
        cutoutFilter.inputImage = resizeFilter.outputImage!
        cutoutFilter.matteImage = hairMatteImage
        
        // グレースケール画像の明度を最低値・最頻値・最高値で取得
        let lightnessInfoFilter = CILightnessInfo()
        lightnessInfoFilter.inputImage = cutoutFilter.outputImage!
        let lightnessInfo = lightnessInfoFilter.outputImage!.getColorAtPoint()
        print(lightnessInfo)
        let minLightness = lightnessInfo.red
        let maxLightness = lightnessInfo.green
        let modeLightness = lightnessInfo.blue
        
        // グラデーションマップを作成
        let gradientFilter = CIIkaHairGradient()
        gradientFilter.minPoint = minLightness
        gradientFilter.modePoint = modeLightness
        gradientFilter.maxPoint = maxLightness
        gradientFilter.minColor = minColor
        gradientFilter.modeColor = modeColor
        gradientFilter.maxColor = maxColor

        // グラデーションマップで髪の毛の色を変更
        let mapFIlter = CIFilter.colorMap()
        mapFIlter.inputImage = cutoutFilter.outputImage!
        mapFIlter.gradientImage = gradientFilter.outputImage!

        // 合成用フィルターを定義
        let compositeFilter = CIFilter.sourceOverCompositing()
        // 色変更した髪の毛を元写真と合成
        compositeFilter.inputImage = mapFIlter.outputImage!
        compositeFilter.backgroundImage = resizeFilter.outputImage!

        if printRange {
            let newPhoto = compositeFilter.outputImage!
            // 識別用文字列
            var text = String()
            text += String(format: "min(%.4f) - ", minLightness)
            text += String(format: "max(%.4f)", maxLightness)
            // 識別用テキストを画像化
            let textFilter = CIFilter.textImageGenerator()
            textFilter.fontSize = 100
            textFilter.text = text
            let clumpFilter = CIFilter.colorClamp()
            clumpFilter.inputImage = textFilter.outputImage!
            clumpFilter.minComponents = CIVector(x: 1, y: 1, z: 1, w: 0)
            // 合成写真を回転して識別用テキストを合成
            compositeFilter.inputImage = clumpFilter.outputImage!
            compositeFilter.backgroundImage = newPhoto
        }

        return compositeFilter.outputImage!
    }
}
