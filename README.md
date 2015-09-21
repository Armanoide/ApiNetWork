ApiNetWork V2
==========

# Manage Async NetWork for Swift
Note: Build on Xcode 6, swift1.2, swift2
All method are asynchronous.

## Install

With CocoaPods:

use 2.X for swift 1.2
use 3.X for swift 2

    pod 'ApiNetWork'
Cocoapods requires iOS 8.0 or higher.
If you're supporting iOS 7, or if you prefer, you can just drop ApiNetWork.swift to your project.


## Basic
     
        ApiNetwork.launchRequest("http://www.google.fr", completion:
        { (response) -> Void in
            
        })
        
        or 
        
        let a  = ApiNetwork(stringURL: "your-url")
        a.launchRequest(didReceived: nil) { (response) -> Void in
            
        }

## Parameter
    
    //yourUrl?user=jack&password=test
     let n : ApiNetwork = ApiNetwork(stringURL: "yourUrl")
     n.addParameterWithKey("user", "jack")
     n.addParameterWithKey("password", "test")

## Downloading

### Launch a simple download

    let iv : UIImageView = UIImageView() 
    let a = ApiNetwork.launchRequestDownloading("your-url", didReceived: nil)
     { (response) -> Void in
            if response.errors == nil {
                if let data = response.getResponseData() {
                    iv.image = UIImage(data: data)
                }
            } else if response.didFailNotConnectedToInternet() == true {
                println("not connection to internet")
            }
    }

### Download and register in a path

    let a  = ApiNetwork(stringURL: "your-url")
    a.setPathFileDownload("path-to-downlaod-file")
    a.launchRequestDownloading(didReceived: nil) { (response) -> Void in
            
    }

### Resume Download

You can resume a download simple by re-launch the request. It's only work if you use setPathFileDownload 

### Stop downloading

Call method 
    stopDownloading() 


### Method Request
  By default, method is set to .GET but can change to .GET .POST .DELETE .PUT .PATCH .HEAD

    let a = ApiNetwork(stringURL: "your-url")
    a.setMethod(.POST)
    a.launchRequest { (response) -> Void in
        // DO YOU WANT            
    }


## Response 
For each request, the response will return a ApiNetworkResponse class. 

### Result Request
Use this method to get your result of request

     getResponseString() 
     getResponseData() 
     getResponseDictionary() 


### Options & Variable ApiNetworkResponse 

    status_code
    errors                    
    header                    
    URL                       
    mime_type                 
    expectLengthDownloading   
    totalLengthDownloaded     



## Still need help?

Ask me on hangout, [+BillaNorbert](https://plus.google.com/+BillaNorbert/)
