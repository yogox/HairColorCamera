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

class CIChangeHairColor: CIFilter {
    var inputImage: CIImage?
    var hairMatteImage: CIImage?
    var printRange = false

    override var outputImage: CIImage? {
        guard let inputImage = inputImage
            , let hairMatteImage = hairMatteImage
        else { return nil }
        
        // 写真に合わせてMatte画像のスケールを拡大
        let scaleFilter = CIFilter.lanczosScaleTransform()
        let matteHeight = hairMatteImage.extent.height
        let photoHeight = inputImage.extent.height
        scaleFilter.inputImage = inputImage
        scaleFilter.scale = Float(matteHeight / photoHeight)
        scaleFilter.aspectRatio = 1.0
        
        // マット画像のアルファを変更
        let maskFilter = CIFilter.maskToAlpha()
        maskFilter.inputImage = hairMatteImage

        // マット領域で写真を切り抜き
        let cutFilter = CIFilter.sourceInCompositing()
        cutFilter.inputImage = scaleFilter.outputImage!
        cutFilter.backgroundImage = maskFilter.outputImage!
        
        // 切り抜いたマット領域を輝度でグレースケール変換
        let grayFilter = CIFilter.falseColor()
        grayFilter.inputImage = cutFilter.outputImage!
        grayFilter.color0 = CIColor.black
        grayFilter.color1 = CIColor.white
        
        // グレースケール画像の明度を最低値・最頻値・最高値で取得
        let lightnessInfoFilter = CILightnessInfo()
        lightnessInfoFilter.inputImage = grayFilter.outputImage!
        let lightnessInfo = lightnessInfoFilter.outputImage!.getColorAtPoint()
        
        print(lightnessInfo)
        let minLightness = lightnessInfo.red
        let maxLightness = lightnessInfo.green
        let modeLightness = lightnessInfo.blue
        
        // 合成用フィルターを定義
        let compositeFilter = CIFilter.sourceOverCompositing()
        
        // グラデーションマップの左側を作成
        //TODO: テストカラーを変更可能にする
        //TODO: maxLightnessを参照して明るさを落としたい
        let gradientFilter = CIFilter.smoothLinearGradient()
        gradientFilter.point0 = CGPoint(x: minLightness * 1000, y: 0)
        gradientFilter.color0 = CIColor(red: 0, green: 0.27, blue: 0)
        gradientFilter.point1 = CGPoint(x: modeLightness * 1000, y: 0)
        gradientFilter.color1 = CIColor(red: 0.22, green: 0.94, blue: 0.27)
        compositeFilter.inputImage = gradientFilter.outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: modeLightness * 1000, height: 480))
        
        // グラデーションマップの右側を作成
        //TODO: テストカラーを変更可能にする
        //TODO: maxLightnessを参照して明るさを落としたい
        gradientFilter.point0 = CGPoint(x: modeLightness * 1000, y: 0)
        gradientFilter.color0 = CIColor(red: 0.22, green: 0.94, blue: 0.27)
        gradientFilter.point1 = CGPoint(x: maxLightness * 1000, y: 0)
        gradientFilter.color1 = CIColor(red: 1, green: 1, blue: 1)
        compositeFilter.backgroundImage = gradientFilter.outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: 1000, height: 480))

        // グラデーションマップで髪の毛の色を変更
        let mapFIlter = CIFilter.colorMap()
        mapFIlter.inputImage = grayFilter.outputImage!
        mapFIlter.gradientImage = compositeFilter.outputImage!
        
        // 色変更した髪の毛を元写真と合成
        compositeFilter.inputImage = mapFIlter.outputImage!
        compositeFilter.backgroundImage = scaleFilter.outputImage!

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
