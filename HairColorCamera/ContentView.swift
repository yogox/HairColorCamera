//
//  ContentView.swift
//  HairColorCamera
//
//  Created by yogox on 2020/10/07.
//  Copyright © 2020 Yogox Galaxy. All rights reserved.
//

import SwiftUI
import AVFoundation


struct CALayerView: UIViewControllerRepresentable {
    var caLayer: AVCaptureVideoPreviewLayer
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CALayerView>) -> UIViewController {
        let viewController = UIViewController()
        
        let width = viewController.view.frame.width
        let height = viewController.view.frame.height
        let previewHeight = width * 4 / 3

        caLayer.videoGravity = .resizeAspect
        viewController.view.layer.addSublayer(caLayer)
        caLayer.frame = viewController.view.frame
        caLayer.position = CGPoint(x: width/2, y: previewHeight/2 + (height - previewHeight - 75)/3 )
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<CALayerView>) {
    }
}

enum Views {
    case transferPhoto
}

struct ContentView: View {
    @ObservedObject var segmentationCamera = SemanticSegmentationCamera()
    @ObservedObject var colorMatrix = ColorMatrix()
    @ObservedObject var colorChanger = ColorChanger()
    @State private var flipped = false
    @State private var angle: Double = 0
    @State private var selection: Views? = .none
    @State private var color = Color.clear
    @State private var showAlert = false
    @State private var buttonGuard = false
    @State private var inProgress = false

    func enableButtonWithPreview() {
        enableButton()
        self.segmentationCamera.restartSession()
    }

    func disableButtonWithPreview() {
        disableButton()
        self.segmentationCamera.stopSession()
    }
    
    func enableButton() {
        buttonGuard = false
    }

    func disableButton() {
        buttonGuard = true
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    ZStack() {
                        CALayerView(caLayer: self.segmentationCamera.previewLayer[.front]!)
                            .opacity(self.flipped ? 1.0 : 0.0)
                        CALayerView(caLayer: self.segmentationCamera.previewLayer[.back]!)
                            .opacity(self.flipped ? 0.0 : 1.0)
                    }
                    .modifier(FlipEffect(flipped: self.$flipped, angle: self.angle, axis: (x: 0, y: 1)))
                    
                    VStack {
                        
                        Spacer()
                        
                        Color.clear
                            .frame(width: geometry.size.width, height: geometry.size.width / 3 * 4)
                        
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                (_, color, _) = colorMatrix.getNextColorChart()
                            }) {
                                Rectangle()
                                    .fill(color)
                                    .frame(width: 40, height: 40)
                                    .onAppear() {
                                        (_, color, _) = colorMatrix.getCurrentColorChart()
                                    }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                disableButton()
                                
                                self.segmentationCamera.takePhoto()

                                DispatchQueue.global(qos: .userInitiated).async {
                                    inProgress = true

                                    // セマフォで撮影完了を待つ
                                    self.segmentationCamera.waitPhoto()
                                    
                                    let result = self.segmentationCamera.result
                                    if let photo = result.photo, let hairMatte = result.matte {
                                        self.colorChanger.setupPhoto(photo, hairMatte)
                                        
                                        let colorChart: (CIColor, CIColor, CIColor) = colorMatrix.getCurrentColorChart()
                                        self.colorChanger.setupColor(colorChart)
                                        
                                        // @Publishedなプロパティ(colorChanger.image)はメインスレッドで更新しないと怒られる
                                        DispatchQueue.main.async {
                                            self.colorChanger.makeImage()
                                            if self.colorChanger.image != nil {
                                                self.selection = .transferPhoto
                                            }
                                        }
                                    } else {
                                        // SemanticSegmentationできなかったら警告
                                        self.showAlert = true
                                    }
                                    
                                    inProgress = false
                                }
                                
                            }) {
                                
                                Image(systemName: "camera.circle.fill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 75, height: 75, alignment: .center)
                                    .foregroundColor(Color.white)
                            }
                            .disabled(buttonGuard)

                            Spacer()
                            
                            Button(action: {
                                self.segmentationCamera.switchCamera()
                                withAnimation(nil) {
                                    
                                    if self.angle >= 360 {
                                        self.angle = self.angle.truncatingRemainder(dividingBy: 360)
                                    }
                                }
                                withAnimation(Animation.easeIn(duration: 0.5)) {
                                    
                                    self.angle += 180
                                }
                            }) {
                                
                                Image(systemName: "camera.rotate")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40, alignment: .center)
                                    .foregroundColor(Color.white)
                            }
                            .disabled(buttonGuard)

                            Spacer()
                        }
                        NavigationLink(destination: TransferPhotoView(
                            segmentationCamera: self.segmentationCamera
                            , colorMatrix: self.colorMatrix
                            , colorChanger: self.colorChanger
                            , color: $color
                            , selection: self.$selection
                            , buttonGuard: self.$buttonGuard
                            ),
                                       tag: Views.transferPhoto,
                                       selection: self.$selection) {
                            
                            EmptyView()
                        }
                        
                        Spacer()
                        
                    }
                    .navigationBarTitle(/*@START_MENU_TOKEN@*/"Navigation Bar"/*@END_MENU_TOKEN@*/)
                    .navigationBarHidden(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Alert"),
                              message: Text("No object with segmentation"),
                              dismissButton: .default(Text("OK"), action: {
                                enableButtonWithPreview()
                              })
                        )
                    }

                    // 写真撮影中のプログレス表示
                    ProgressView("Caputring Now").opacity(self.inProgress ? 1.0 : 0.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .scaleEffect(1.5, anchor: .center)
                        .shadow(color: .secondary, radius: 2)

                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.black)

            }
        }
    }
}

struct FlipEffect: GeometryEffect {
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    
    @Binding var flipped: Bool
    var angle: Double
    let axis: (x: CGFloat, y: CGFloat)
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        DispatchQueue.main.async {
            self.flipped = self.angle >= 90 && self.angle < 270
        }
        
        let tweakedAngle = flipped ? -180 + angle : angle
        let a = CGFloat(Angle(degrees: tweakedAngle).radians)
        
        var transform3d = CATransform3DIdentity;
        transform3d.m34 = -1/max(size.width, size.height)
        
        transform3d = CATransform3DRotate(transform3d, a, axis.x, axis.y, 0)
        transform3d = CATransform3DTranslate(transform3d, -size.width/2.0, -size.height/2.0, 0)
        
        let affineTransform = ProjectionTransform(CGAffineTransform(
                                                    translationX: size.width/2.0,
                                                    y: size.height / 2.0))
        
        return ProjectionTransform(transform3d).concatenating(affineTransform)
    }
}

struct photoView: View {
    @ObservedObject var colorChanger: ColorChanger

    var body: some View {
        VStack {
            if self.colorChanger.image != nil {
                Image(uiImage: self.colorChanger.image!)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle()
                    .fill(Color.black)
            }
        }
    }
}

struct TransferPhotoView: View {
    @ObservedObject var segmentationCamera: SemanticSegmentationCamera
    @ObservedObject var colorMatrix: ColorMatrix
    @ObservedObject var colorChanger: ColorChanger
    @Binding var color: Color
    @Binding var selection: Views?
    @Binding var buttonGuard:Bool
    
    func enableButtonWithPreview() {
        enableButton()
        self.segmentationCamera.restartSession()
    }

    func disableButtonWithPreview() {
        disableButton()
        self.segmentationCamera.stopSession()
    }
    
    func enableButton() {
        buttonGuard = false
    }

    func disableButton() {
        buttonGuard = true
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            GeometryReader { geometry in
                photoView(colorChanger: self.colorChanger)
                    .frame(alignment: .center)
                    .background(Color.black)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    let colorChart: (minColor: CIColor, modeColor: CIColor, maxColor: CIColor) = colorMatrix.getNextColorChart()
                    color = Color(colorChart.modeColor)
                    self.colorChanger.setupColor(colorChart)
                    self.colorChanger.makeImage()
                }) {
                    Rectangle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                }
                
                Spacer()

                Spacer()

                Spacer()

                Spacer()

                Spacer()
            }
            
            Spacer()

            HStack {
                Button(action: {
                    enableButtonWithPreview()
                    self.selection = .none
                    self.colorChanger.clear()
                }) {
                    
                    Text("Back")
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .background(/*@START_MENU_TOKEN@*/Color.black/*@END_MENU_TOKEN@*/)
        .navigationBarTitle("Image")
        .navigationBarHidden(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
