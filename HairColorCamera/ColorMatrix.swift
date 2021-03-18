//
//  ColorMatrix.swift
//  HairColorCamera
//
//  Created by yogox on 2021/02/25.
//  Copyright © 2021 Yogox Galaxy. All rights reserved.
//

import CoreImage.CIColor
import SwiftUI

extension Color {
    init(_ color: CIColor) {
        let uiColor = UIColor(ciColor: color)
        self.init(uiColor)
    }
}

class ColorMatrix: ObservableObject {
    struct ColorChart {
        var minColor: CIColor
        var modeColor: CIColor
        var maxColor: CIColor
    }
    
    private var matrix = Array<ColorChart>()
    private var current: Int = 0
    
    init() {
        let bundle = Bundle.main.path(forResource: "ColorData", ofType: "csv")
        do {
            let csvData = try String(contentsOfFile: bundle!, encoding: String.Encoding.utf8)
            let csvLines = csvData.components(separatedBy: .newlines)
            for line in csvLines {
                let columns = line.components(separatedBy: ",")
                guard columns.count == 9  else {
                    continue
                }
                
                let minString =  columns[0...2].reduce("") { $0 + " " + $1 }
                let minColor = CIColor(string: minString)
                let modeString =  columns[3...5].reduce("") { $0 + " " + $1 }
                let modeColor = CIColor(string: modeString)
                let maxString =  columns[6...8].reduce("") { $0 + " " + $1 }
                let maxColor = CIColor(string: maxString)
                
                let colorChart = ColorChart(minColor: minColor, modeColor: modeColor, maxColor: maxColor)
                matrix.append(colorChart)
            }
            
        } catch {
        }
    }
    
    func getCurrentColorChart() -> (CIColor, CIColor, CIColor) {
        guard matrix.count > 0 else {
            return (CIColor.clear, CIColor.clear, CIColor.clear)
        }
        
        let colorChart = matrix[current]
        return (colorChart.minColor, colorChart.modeColor, colorChart.maxColor)
    }
    
    func getCurrentColorChart() -> (Color, Color, Color) {
        let minColor: CIColor
        let modeColor: CIColor
        let maxColor: CIColor
        
        (minColor, modeColor, maxColor) = getCurrentColorChart()
        
        return (Color(minColor), Color(modeColor), Color(maxColor))
    }
    
    func getNextColorChart() -> (CIColor, CIColor, CIColor) {
        current += 1
        if current >= matrix.count {
            current = 0
        }
        
        return getCurrentColorChart()
    }
    
    func getNextColorChart() -> (Color, Color, Color) {
        let minColor: CIColor
        let modeColor: CIColor
        let maxColor: CIColor
        
        (minColor, modeColor, maxColor) = getNextColorChart()
        
        return (Color(minColor), Color(modeColor), Color(maxColor))
    }
}
