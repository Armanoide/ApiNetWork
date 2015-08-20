ApiNetWork
==========

# Manage Async NetWork for Swift
Note: Build on Xcode 6, swift 1.2

## Install

To use this vendor add files ApiNetwork.swift  to your Project.
All method are asynchronous.

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

### Download and register in path

    let a  = ApiNetwork(stringURL: "your-url")
    a.setPathFileDownload("path-to-downlaod-file")
    a.launchRequestDownloading(didReceived: nil) { (response) -> Void in
            
    }

### Resume Download

you can resume a download simple by re-launch the request. It's only work if you use setPathFileDownload 

### stop downloading

call method stopDownloading() to stop


### Method Request
  by default, method is set to .GET but can change to .GET .POST .DELETE .PUT .PATCH .HEAD

    let a = ApiNetwork(stringURL: "your-url")
    a.setMethod(.POST)
    a.launchRequest { (response) -> Void in
        // DO YOU WANT            
    }


## Response 
for each request, the response will return a ApiNetworkResponse class. 

### Result Request

use this method to get your result of request

    func getResponseString() 
    func getResponseData() 
    func getResponseDictionary() 


### Options ApiNetworkResponse

    status_code
    errors                    
    header                    
    URL                       
    mime_type                 
    expectLengthDownloading   
    totalLengthDownloaded     



## Still need help?

Ask me on hangout, [+BillaNorbert](https://plus.google.com/+BillaNorbert/)
