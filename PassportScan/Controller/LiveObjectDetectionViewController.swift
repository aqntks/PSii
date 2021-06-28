

import AVFoundation
import UIKit
import AudioToolbox

class LiveObjectDetectionViewController: ViewController {
    @IBOutlet weak var cameraView: CameraPreviewView!
    @IBOutlet weak var benchmarkLabel: UILabel!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    private let delayMs: Double = 1000
    private var prevTimestampMs: Double = 0.0
    private var cameraController = CameraController()
    private var imageViewLive =  UIImageView()
    @IBOutlet weak var guideView: UIImageView!
    
    private var inferencer = ObjectDetector()
    private var mrzResult: MRZResult!
    
    // Thread 침범 방지
    private var sendCheck: Bool = false
    
    // mrz 영역
    var mrzRegion: CGRect!
    
    struct Result {
        var resultText: String
        var score: Float
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = false
        
        cameraController.configPreviewLayer(cameraView)
        imageViewLive.frame = CGRect(x: 0, y: 0, width: cameraView.frame.size.width, height: cameraView.frame.size.height)
        cameraView.addSubview(imageViewLive)
        
        
        //MRZ 가이드 그리기
        setupMRZGuide()
        cameraController.videoCaptureCompletionBlock = { [weak self] buffer, error in
            //if self!.sendCheck { return }
            guard let strongSelf = self else { return }
            if error != nil {
                return
            }
            guard var pixelBuffer = buffer else { return }

            let currentTimestamp = CACurrentMediaTime()
            if (currentTimestamp - strongSelf.prevTimestampMs) * 1000 <= strongSelf.delayMs { return }
            strongSelf.prevTimestampMs = currentTimestamp
            
            guard let outputs = self?.inferencer.module.detect(image: &pixelBuffer) else { return }
           
//             let inferenceTime = CACurrentMediaTime() - startTime
            DispatchQueue.main.async {
                let ivScaleX : Double = Double(strongSelf.imageViewLive.frame.size.width / CGFloat(PrePostProcessor.inputWidth))
                let ivScaleY : Double = Double(strongSelf.imageViewLive.frame.size.height / CGFloat(PrePostProcessor.inputHeight))

                let startX = Double((strongSelf.imageViewLive.frame.size.width - CGFloat(ivScaleX) * CGFloat(PrePostProcessor.inputWidth))/2)
                let startY = Double((strongSelf.imageViewLive.frame.size.height -  CGFloat(ivScaleY) * CGFloat(PrePostProcessor.inputHeight))/2)

                let nmsPredictions = PrePostProcessor.outputsToNMSPredictions(outputs: outputs, imgScaleX: 1.0, imgScaleY: 1.0, ivScaleX: ivScaleX, ivScaleY: ivScaleY, startX: startX, startY: startY)
      
                PrePostProcessor.cleanDetection(imageView: strongSelf.imageViewLive)
                strongSelf.indicator.isHidden = true
                strongSelf.benchmarkLabel.isHidden = false
                //strongSelf.benchmarkLabel.text = String(format: "%.2fms", 1000*inferenceTime) // 추론 시간 측정
                strongSelf.benchmarkLabel.text = "complete"

                PrePostProcessor.showDetection(imageView: strongSelf.imageViewLive, nmsPredictions: nmsPredictions, classes: strongSelf.inferencer.classes)
                guard !(self?.createMRZ(predictions: nmsPredictions))! else { return }
            }
        }
    }
    
    // MRZ 생성
    private func createMRZ(predictions: [Prediction]) -> Bool{
        let result: Result = sortMRZ(predictions: predictions)
        if result.resultText.count == 0 { return false }
        guard let mrzResult: MRZResult = mrz(result: result.resultText, score: result.score) else { return false }
        if mrzValidation(mrzResult: mrzResult, resultText: result.resultText) {
            self.mrzResult = mrzResult
            if sendCheck == false {
                // 검출 시 효과음
                AudioServicesPlaySystemSound(1200)
                // 검출 시 진동
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                self.performSegue(withIdentifier: "showResult", sender: self)
                sendCheck = true
            }
            return true
        }
        return false
    }

    // Object Detection 결과 MRZ 형태로 정렬
    private func sortMRZ(predictions: [Prediction]) -> Result{
        var index: Int = 0
        var score: Float = 0
        var resultText: String = ""
        var firstLine: [Prediction]! = [Prediction]()
        var secondLine: [Prediction]! = [Prediction]()
        var result: Result = Result(resultText: "", score: 0)
        
        let sortPrediction = predictions.sorted{$0.rect.origin.y < $1.rect.origin.y}
        
        // 첫번째 줄 첫번째 글자 체크 (mrz 아닌 글자 검출 위해)
        var tempNum: Prediction? = nil
        if(predictions.count > 1){
            let temp = predictions.sorted{$0.rect.origin.x < $1.rect.origin.x}
            if temp[0].rect.origin.y > temp[1].rect.origin.y { tempNum = temp[1] }
            else { tempNum = temp[0] }
        }
                
        for cls in sortPrediction{
            // 첫번째 줄 위에 mrz 아닌 글자 있으면 검출 x
            if tempNum != nil && tempNum!.rect.origin.y - 20 > cls.rect.origin.y { continue }

            if cls.classIndex != 37 {
                if index < 44 {firstLine.append(cls)}
                else {secondLine.append(cls)}
                    
                index = index + 1
                score = score + cls.score
            }
        }
        if firstLine != nil && secondLine != nil && firstLine.count != 0 && secondLine.count != 0 {
            let resultY1 = firstLine.sorted{$0.rect.origin.x < $1.rect.origin.x}
            let resultY2 = secondLine.sorted{$0.rect.origin.x < $1.rect.origin.x}
            
            
//            let ratio = CGFloat(742.0/640.0)
//            print("가이드: (\(mrzRegion.minY*ratio), \(mrzRegion.maxY*ratio))")
//            print(" \(resultY1[0].rect.minY)")
//            print(" \(resultY2[0].rect.maxY)")
            // 가이드에서만 mrz 검출되게 하기 위한 코드
//            if cls.classIndex == 37 {
//                let ratio = ((view.bounds.maxY)/640)
//                let guideY = mrzRegion.minY*ratio
//                let mrzY = cls.rect.minY
//                print("가이드: (\(mrzRegion.minY*ratio), \(mrzRegion.maxY*ratio))")
//                print("MRZ : (\(cls.rect.minY), \(cls.rect.maxY))")
//                if mrzY < guideY {break}
//            }
            
            
            for i in 0...resultY1.count - 1{resultText.append((self.inferencer.classes[resultY1[i].classIndex]))}
            resultText = resultText + "\n"
            for i in 0...resultY2.count - 1{resultText.append((self.inferencer.classes[resultY2[i].classIndex]))}
        }
        
        resultText = resultText.replacingOccurrences(of: "sign", with: "<")
        resultText = resultText.replacingOccurrences(of: "mrz", with: "")
        
        result.resultText = resultText
        result.score = score
        
        return result
    }
    
    // MRZ 결과 추출
    private func mrz(result: String!, score: Float) -> MRZResult? {
        guard verificationDetectionResults(result: result, score: score) else { return nil }
        let mrzParser = MRZParser(ocrCorrection: true)
        if let string = result, let mrzLines = mrzLines(from: string) {
            return mrzParser.parse(mrzLines: mrzLines)
        }
        return nil
    }
    
    // MRZ 후처리
    private func mrzLines(from recognizedText: String) -> [String]? {
        let mrzString = recognizedText.replacingOccurrences(of: " ", with: "")
        var mrzLines = mrzString.components(separatedBy: "\n").filter({ !$0.isEmpty })
        // 앞 뒤 가비지 문자열 제거
        if !mrzLines.isEmpty {
            let averageLineLength = (mrzLines.reduce(0, { $0 + $1.count }) / mrzLines.count)
            mrzLines = mrzLines.filter({ $0.count >= averageLineLength })
        }
        
        return mrzLines.isEmpty ? nil : mrzLines
    }
    
    //검출 결과 검증
    private func verificationDetectionResults(result: String, score: Float) -> Bool{
        // 검출 조건 88개 이상 검출되야 넘어가게 함 정확도 90% 이상
        
//        print(result)
        
        guard (result.count) > 88 && score > 0.88 else { return false }
        return true
    }
    
    // MRZ 검증
    private func mrzValidation(mrzResult: MRZResult, resultText: String) -> Bool{
        if mrzResult.sex == "null" { return false }
        if mrzResult.nationalityCountryCode == "null" { return false }
        if mrzResult.birthdate == nil { return false }
        if mrzResult.expiryDate == nil { return false }
        // 첫번째 줄에 숫자 제거
        for i in 0...9 {
            if mrzResult.surnames.contains(String(i)) { return false }
            if mrzResult.givenNames.contains(String(i)) { return false }
            if mrzResult.nationalityCountryCode.contains(String(i)) { return false }
        }
    
        // mrz 체크비트 검사
        let documentNumberTemp = mrzResult.documentNumber
        let check: [Int] = [7, 3, 1]
        var index: Int = 0
        var sum: Int = 0
        for s in documentNumberTemp {
            if index > 2 {index = 0}
            // "<" 이면 0이라 계산 안함
            if s != "<"{
                if Int(s.unicodeScalars.first!.value) >= 65
                { sum = sum + (Int(s.unicodeScalars.first!.value) - 55) * check[index] }
                else
                { sum = sum + (Int(s.unicodeScalars.first!.value) - 48) * check[index] }
            }
            index = index + 1
        }
        if sum % 10 != Int(resultText.substring(54, to: 54)) { return false }
    
        return true
    }
    
    //여권 및 MRZ 가이드 그리기
    func setupMRZGuide() {
        //뒷배경 색깔 및 투명도
        let mrzFrameColor : UIColor = UIColor.red
        let maskLayerColor: UIColor = UIColor.white
        let maskLayerAlpha: CGFloat = 0.9

        
        ////////////// 영역 설정
        // 여권 가이드 박스 시작 X 좌표 = 전체 뷰 영역의 3% 위치
        let passportBoxLocationX = view.bounds.width * 0.03
        // 여권 가이드 박스 시작 Y 좌표 = 전체 뷰 영역의 30% 위치
        let passportBoxLocationY = guideView.frame.maxY
        // 여권 가이드 박스 가로 사이즈 = 전체 영역 94%
        let passportBoxWidthSize = view.bounds.width * 0.94
        // 여권 가이드 박스 세로 사이즈 = 전체 영역 40%
        let passportBoxheightSize = view.bounds.height * 0.40
        // MRZ 가이드 시작 Y 좌표 = 여권 가이드 박스 Y 좌표 끝나는 위치에서 뷰의 10% 만큼 올라간 위치
        let mazBoxLocationY = passportBoxLocationY + passportBoxheightSize - view.bounds.height * 0.1
        // MRZ 가이드 박스 세로 사이즈 = 전체 영역 10%
        let mrzBoxheightSize = view.bounds.height * 0.1
        
        let passportRect = CGRect(x: passportBoxLocationX,
                                y: passportBoxLocationY,
                                width: passportBoxWidthSize,
                                height: passportBoxheightSize)
        
        let mrzRect = CGRect(x: passportBoxLocationX,
                                y: mazBoxLocationY,
                                width: passportBoxWidthSize,
                                height: mrzBoxheightSize)
        
        let passportGuideRect = CGRect(x: (view.bounds.width - guideView.frame.width) / 2,
                                       y: guideView.frame.minY,
                                       width: guideView.frame.width,
                                       height: guideView.frame.height)
    
        // 여권 가이드 백그라운드 설정
        let backLayer = CALayer()
        backLayer.frame = view.bounds
        backLayer.backgroundColor = maskLayerColor.withAlphaComponent(maskLayerAlpha).cgColor
        
        // 여권 가이드 구역 설정
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(roundedRect: passportRect, cornerRadius: 10.0)
        path.append(UIBezierPath(rect: view.bounds))
        maskLayer.path = path.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        backLayer.mask = maskLayer
        self.cameraView.layer.addSublayer(backLayer)
        
        // 여권 가이드 이미지 등록
        let guideLayer = CALayer()
        guideLayer.frame = passportGuideRect
        guideLayer.contents = UIImage(named: "pp_guide.png")?.cgImage
        self.cameraView.layer.addSublayer(guideLayer)

        // MRZ 가이드 설정
        let mrzLineLayer = CAShapeLayer()
        mrzLineLayer.lineWidth = 2.0
        mrzLineLayer.strokeColor = mrzFrameColor.cgColor
        mrzLineLayer.path = UIBezierPath(roundedRect: mrzRect, cornerRadius: 10.0).cgPath
        mrzLineLayer.fillColor = nil
        self.cameraView.layer.addSublayer(mrzLineLayer)
        
        //MRZ 가이드 위치 저장
        mrzRegion = mrzRect
    }
    
    //결과 페이지에 값 전송
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.destination is ResultController{
            let newController = segue.destination as? ResultController
            newController?.mrzResult = self.mrzResult
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraController.startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraController.stopSession()
        
    }

    @IBAction func onBackClicked(_: Any) {
        navigationController?.popViewController(animated: true)
    }
}
