#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h> // includes CIKernelMetalLib.h

extern "C" { namespace coreimage {
#define BIN_NUM 21

    struct bin_t {
        int index;
        int count;
    };

    float4 minMaxModeLightness(sampler src) {
        float2 p0;
        float2 p;
        float4 color;
        float lightness;
        int index;
        int histogram[BIN_NUM] = {};
        int modeIndex;
        float minLightness, maxLightness, modeLightness;
        float4 lightnessInfo;
        
        maxLightness = 0.0;
        minLightness = 1.0;
        
        // 画像の各ピクセルの明度を計算して該当ビンをカウント
        for (int x = 0; x <= src.size().x; x++) {
            for (int y = 0; y <= src.size().y; y++) {
                p0 = float2(x, y);
                p = src.transform(p0);
                color = src.sample(p).rgba;
                
                if (color.a == 0.0) {
                    // 非髪領域（アルファ値0）は無視
                    continue;
                } else if ( color.a <= 0.05 && max3(color.r, color.g, color.b) <= 0.05 ) {
                    // 非髪領域（アルファ値0）と髪領域の中間に位置する領域（写真を切り取ると黒になる）がかなり多いので無視
                    continue;
                }
                
                // 明度を計算
                lightness = ( max3(color.r, color.g, color.b) + min3(color.r, color.g, color.b) ) / 2;
                // 明度から該当ビンのインデックスを計算
                index = int( floor( lightness * (BIN_NUM - 1) ) );
                histogram[index]++;
                
                if (lightness > maxLightness) {
                    maxLightness = lightness;
                }
                if (lightness < minLightness) {
                    minLightness = lightness;
                }
            }
        }
        
        // 最頻のビンを計算（カウントが同数の場合は便宜的にインデックスが小さい方）
        modeIndex = 0;
        for (int i = modeIndex + 1; i < BIN_NUM; i++) {
            if (histogram[modeIndex] < histogram[i]) {
                modeIndex = i;
            }
        }
        
        // 最頻値から明度を逆算
        modeLightness = float(modeIndex) / (BIN_NUM - 1);
        
        // 各明度で色を構成
        lightnessInfo = float4(minLightness, maxLightness, modeLightness, 1.0);
        return lightnessInfo;
    }
    
}}
