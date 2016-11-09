//
//  LaunchViewController.swift
//  Shrofile-Camera
//
//  Created by Arjun Kodur on 11/7/16.
//  Copyright © 2016 Arjun Kodur. All rights reserved.
//

import UIKit

class LaunchViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var usernameTextField: UITextField!

    @IBOutlet weak var continueButton: UIButton!
    
    @IBOutlet weak var errorLabel: UILabel!
    
    let whitespace = NSCharacterSet.whitespaces
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        usernameTextField.delegate = self
        self.usernameTextField.addTarget(self, action: #selector(LaunchViewController.textFieldTapped), for: .touchDown)
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 35, height: 35))
        self.usernameTextField.leftView = paddingView
        self.usernameTextField.leftViewMode = UITextFieldViewMode.always
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = true
        usernameTextField.layer.cornerRadius = 6.0
        continueButton.layer.cornerRadius = 6.0
        errorLabel.text = ""
    }
    
    
    @IBAction func continueButtonTapped(_ sender: Any) {
        
        if usernameTextField.text == "" {
            errorLabel.text = "Sorry, you got to be having a name"

        } else if ((usernameTextField.text?.rangeOfCharacter(from: whitespace)) != nil) {
            errorLabel.text = "Please avoid Space in between your name"
        }else{
            performSegue(withIdentifier: "JumpToCameraView", sender: self)
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "JumpToCameraView" {
            
            let destinationVC = segue.destination as! CameraViewController
            destinationVC.username = usernameTextField.text
            
        }
    }
    
    func textFieldTapped(){
        self.errorLabel.text = ""
        
    }
    

}


