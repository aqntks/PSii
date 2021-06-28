
import AVFoundation
import Foundation
import UIKit

class CameraController: NSObject {
    var videoCaptureCompletionBlock: (([Float32]?, CameraControllerError?) -> Void)?
    private var captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var sessionQueue = DispatchQueue(label: "session")
    private var bufferQueue = DispatchQueue(label: "buffer")

    // 프리뷰 레이어에 카메라 세션 연결
    func configPreviewLayer(_ previewView: CameraPreviewView) {
        previewView.previewLayer.session = captureSession
        previewView.previewLayer.connection?.videoOrientation = .portrait
        previewView.previewLayer.videoGravity = .resizeAspectFill
    }
    
    // 카메라 세션 시작 시
    func startSession() {
        func reportError(error: CameraControllerError) {
            DispatchQueue.main.async {
                if let callback = self.videoCaptureCompletionBlock {
                    callback(nil, error)
                }
            }
        }
        
        // 카메라 세션 작동 이미지 버퍼 세션 큐에 순차적으로 집어 넣으며 출력 / 비동기
        sessionQueue.async {
            do {
                self.captureSession.sessionPreset = .high
                self.captureSession.beginConfiguration()
                try self.configCameraInput()
                try self.configCameraOutput()
                self.captureSession.commitConfiguration()
                self.prepare {
                    if $0, !self.captureSession.isRunning {
                        self.addListeners()
                        self.captureSession.startRunning()
                    } else {
                        reportError(error: .cameraAccessDenied)
                    }
                }
            } catch {
                reportError(error: .cameraConfigError)
            }
        }
    }

    // 카메라 세션 종료
    func stopSession() {
        removeListeners()
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }

    
    private func prepare(_ completionHandler: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) {
                completionHandler($0)
            }
            return
        }
        completionHandler(status == .authorized)
    }

    private func configCameraInput() throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraControllerError.cameraConfigError
        }
        let input = try AVCaptureDeviceInput(device: camera)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraControllerError.invalidInput
        }
    }

    private func configCameraOutput() throws {
        videoOutput.setSampleBufferDelegate(self, queue: bufferQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): kCMPixelFormat_32BGRA]
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            throw CameraControllerError.invalidOutput
        }
    }

    private func addListeners() {
        guard let callback = videoCaptureCompletionBlock else {
            return
        }
        let center = NotificationCenter.default
        let mainQueue = OperationQueue.main
        center.addObserver(forName: .AVCaptureSessionRuntimeError, object: nil, queue: mainQueue) { _ in
            callback(nil, .sessionError)
        }
    }

    private func removeListeners() {
        NotificationCenter.default.removeObserver(self)
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    // 이미지 저장 테스트 코드
//    func convert(cmage: CIImage) -> UIImage {
//         let context = CIContext(options: nil)
//         let cgImage = context.createCGImage(cmage, from: cmage.extent)!
//         let image = UIImage(cgImage: cgImage)
//         return image
//    }
    
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        
        // 이미지 저장 테스트 코드
        //#############################################################################
//        let ciimage = CIImage(cvPixelBuffer: pixelBuffer)
//        let image = self.convert(cmage: ciimage)
//        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        //#############################################################################
        
        // input 이미지 normalized 변환 (딥러닝 검출 할 수 있는 형태로 변환)
        guard let normalizedBuffer = pixelBuffer.normalized(PrePostProcessor.inputWidth, PrePostProcessor.inputHeight) else {
            return
        }
        
        if let callback = videoCaptureCompletionBlock {
            callback(normalizedBuffer, nil)
        }
    }
}

extension CameraController {
    enum CameraControllerError: Swift.Error {
        case cameraAccessDenied
        case cameraConfigError
        case invalidInput
        case invalidOutput
        case sessionError
        case unknown
    }
}
