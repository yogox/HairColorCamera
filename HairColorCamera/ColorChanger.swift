//
//  ColorChanger.swift
//  HairColorCamera
//
//  Created by yogox on 2021/02/26.
//  Copyright © 2021 Yogox Galaxy. All rights reserved.
//

import SwiftUI
import CoreImage

class ColorChanger: ObservableObject {
    private let colorContext = CIContext(options: [.workingColorSpace: kCFNull])
    private let context = CIContext(options: nil)

    @Published var image: UIImage?
    var photoImage: CIImage?
    var hairImage: CIImage?
    var minColor: CIColor?
    var modeColor: CIColor?
    var maxColor: CIColor?
    var minLightness: CGFloat?
    var modeLightness: CGFloat?
    var maxLightness: CGFloat?
    var printRange = true

    func setupPhoto(_ photo: CIImage, _ hairMatte: CIImage) {
        // 写真に合わせてMatte画像のスケールを拡大
        let resizeFilter = CIResizeImageWith()
        resizeFilter.inputImage = photo
        resizeFilter.backgroundImage = hairMatte
        
        // マット画像で写真を切り抜いて、グレースケール変換
        let cutoutFilter = CICutoutSegmentGray()
        cutoutFilter.inputImage = resizeFilter.outputImage!
        cutoutFilter.matteImage = hairMatte
        
        self.photoImage = resizeFilter.outputImage!
        self.hairImage = cutoutFilter.outputImage!
        
        computeLightness()
    }
    
    func computeLightness() {
        guard let hairImage = self.hairImage else {
            self.minLightness = nil
            self.modeLightness = nil
            self.maxLightness = nil
            return
        }
        let lightnessInfoFilter = CILightnessInfo()
        lightnessInfoFilter.inputImage = hairImage
        let colorInfo = lightnessInfoFilter.outputImage!

        let point = CGPoint(x: 0, y: 0)
        var bitmap = [UInt8](repeating: 0, count: 4)
        self.colorContext.render(colorInfo, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: point.x, y: point.y, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let redInteger = Int(bitmap[0].description) ?? 0
        let redc = CGFloat(redInteger)/255
        let greenInteger = Int(bitmap[1].description) ?? 0
        let greenc = CGFloat(greenInteger)/255
        let blueInteger = Int(bitmap[2].description) ?? 0
        let bluec = CGFloat(blueInteger)/255

        print( (redc, greenc, bluec) )
        self.minLightness = redc
        self.modeLightness = greenc
        self.maxLightness = bluec
    }
    
    func setupColor( _ colorChart: (minColor: CIColor, modeColor: CIColor, maxColor: CIColor) ) {
        self.minColor = colorChart.minColor
        self.modeColor = colorChart.modeColor
        self.maxColor = colorChart.maxColor
    }
    
    func makeImage() {
        guard let photoImage = self.photoImage
              , let hairImage = self.hairImage
              , let minColor = self.minColor
              , let modeColor = self.modeColor
              , let maxColor = self.maxColor
              , let minLightness = self.minLightness
              , let modeLightness = self.modeLightness
              , let maxLightness = self.maxLightness
        else {
            self.image = nil
            return
        }
        
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
        mapFIlter.inputImage = hairImage
        mapFIlter.gradientImage = gradientFilter.outputImage!

        // 合成用フィルターを定義
        let compositeFilter = CIFilter.sourceOverCompositing()
        // 色変更した髪の毛を元写真と合成
        compositeFilter.inputImage = mapFIlter.outputImage!
        compositeFilter.backgroundImage = photoImage

        if self.printRange {
            let newPhoto = compositeFilter.outputImage!
            // 識別用文字列
            var text = String()
            text += String(format: "min(%.4f) - ", minLightness)
            text += String(format: "max(%.4f)", maxLightness)
            // 識別用テキストを画像化
            let textFilter = CIFilter.textImageGenerator()
            textFilter.fontSize = 30
            textFilter.text = text
            let clumpFilter = CIFilter.colorClamp()
            clumpFilter.inputImage = textFilter.outputImage!
            clumpFilter.minComponents = CIVector(x: 1, y: 1, z: 1, w: 0)
            // 合成写真を回転して識別用テキストを合成
            compositeFilter.inputImage = clumpFilter.outputImage!
            compositeFilter.backgroundImage = newPhoto
        }

        let newImage = compositeFilter.outputImage!
        // Imageクラスで描画されるようにCGImage経由でUIImageに変換する必要がある
        let cgImage = context.createCGImage(newImage, from: newImage.extent)
        self.image = UIImage(cgImage: cgImage!)
    }
    
    func clear() {
        photoImage = nil
        hairImage = nil
        minColor = nil
        modeColor = nil
        maxColor = nil
        minLightness = nil
        modeLightness = nil
        maxLightness = nil
    }
}
