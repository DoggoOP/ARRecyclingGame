//
//  LoginViewController.swift
//  Whare are my keys v2
//
//  Created by Ethan Kong on 18/5/2022.
//

import UIKit

class LoginViewController: UIViewController {

    @IBAction func findBtn(_ sender: Any) {
        performSegue(withIdentifier: "Find", sender: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
