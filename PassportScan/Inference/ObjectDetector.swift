
import UIKit

class ObjectDetector {
    lazy var module: InferenceModule = {
        if let filePath = Bundle.main.path(forResource: "passport_s.torchscript", ofType: "pt"), // 학습 Model Path
           let module = InferenceModule(fileAtPath: filePath) {
            return module
        } else {
            fatalError("Failed to load model!")
        }
    }()
    
    lazy var classes: [String] = {
        if let filePath = Bundle.main.path(forResource: "classes", ofType: "txt"), // class 파일 Path
            let classes = try? String(contentsOfFile: filePath) {
            return classes.components(separatedBy: .newlines)
        } else {
            fatalError("classes file was not found.")
        }
    }()
}
