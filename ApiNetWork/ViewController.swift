//
//  ViewController.swift
//  ApiNetWork
//
//  Created by norbert on 06/11/14.
//  Copyright (c) 2014 norbert billa. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
       

        
        ApiNetWork.launchRequestDownloading("http://dealerdemusique.fr/wp-content/uploads/2012/11/flume-700x422.jpeg", didReceived: nil)
            { (response) -> Void in
                if response.errors == nil {
                    if let data = response.getResponseData() {
                        self.imageView.image = UIImage(data: data)
                    }
                } else if response.didFailNotConnectedToInternet() == true {
                    println("not connection to internet")
                }
        }
        
        
    }
    
}

