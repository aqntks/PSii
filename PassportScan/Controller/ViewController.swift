

import UIKit
import AVFoundation

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate{

    override func viewDidLoad() {
        super.viewDidLoad()
        // 네비게이션 바 출력 여부
        navigationController?.isNavigationBarHidden = false
        // 스와이프 뒤로가기 동작 여부
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        
        // 라이센스 불러오기
        let filePath = Bundle.main.path(forResource: "Code1License", ofType: "lic")
        let license = try? String(contentsOfFile: filePath!).replace("\n", with: "")

        // 번들아이디 체크
        let bundle = Bundle(for: ViewController.self).bundleIdentifier

        //복호화
        let dec = AES128Util.decrypt(encoded: license!)

        print(AES128Util.encrypt(string: bundle!))

        // 현재는 print 문이지만 추후에 고객에 맞춰 따라 라이센스 처리 코드 작성
        if dec == bundle {print("성공")}
        else {print("실패")}
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
    }
}


