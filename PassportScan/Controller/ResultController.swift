
import Foundation
import UIKit

class ResultController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet weak var homeButton: UIBarButtonItem!
    
    @IBOutlet weak var passportText: UITextField!
    @IBOutlet weak var surnameText: UITextField!
    @IBOutlet weak var givennameText: UITextField!
    @IBOutlet weak var nationalityText: UITextField!
    @IBOutlet weak var sexLabel: UILabel!
    @IBOutlet weak var birthLabel: UILabel!
    @IBOutlet weak var expiryLabel: UILabel!
    
    var mrzResult: MRZResult!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.navigationBar.backItem?.backBarButtonItem?.accessibilityElementsHidden = true
        
        setResult()
    }
    
    // UI 필드에 결과 값 적용
    func setResult() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yy/MM/dd"
        
        passportText.text = mrzResult.documentNumber
        surnameText.text = mrzResult.surnames
        givennameText.text = mrzResult.givenNames
        nationalityText.text = mrzResult.nationalityCountryCode
        if mrzResult.sex == nil{ sexLabel.text = "null" }
        else { sexLabel.text = mrzResult.sex }
        birthLabel.text = dateFormatter.string(from: mrzResult.birthdate!)
        expiryLabel.text = dateFormatter.string(from: mrzResult.expiryDate!)
    }

    @IBAction func backHome(_ sender: Any) {
        self.navigationController?.isNavigationBarHidden = true
        self.navigationController?.popToRootViewController(animated: true)
    }
    
}

