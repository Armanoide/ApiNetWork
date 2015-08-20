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
        
        let n : ApiNetwork = ApiNetwork(stringURL: "http://dealerdemusique.fr/wp-content/uploads/2012/11/flume-700x422.jpeg")
        if n.connected() {
            
            n.launchRequestDownloading(didReceived: nil, didFinished: { (response) -> Void in
              
                if response.errors == nil {
                    if let data = response.getResponseData() {
                        self.imageView.image = UIImage(data: data)
                    }
                }
                
            })
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

