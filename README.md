ApiNetWork
==========

# Manage NetWork for Swift
Note: Build on Xcode 6 

## Intall

To use this vendor add files ApiNetwork and to your Project


## Basic
    let n : ApiNetwork = ApiNetwork(stringURL: "http://google.fr")
    if n.connected() {
     n.launchRequest(false, timeout: 10, method: ApiNetwork.MethodRequest.GET,
                        completion: {(result :NSDictionary?) -> Void in
                          
                    })
    } else { /* There is no network */}


## Parameter
 Parameter can be add with method addParameterWithKey
    let n : ApiNetwork = ApiNetwork(stringURL: "yourUrl")
    n.addParameterWithKey("user", "jack")
    n.addParameterWithKey("password", "test")


## Downloading

    let image : UIImage!
    let n : ApiNetwork = ApiNetwork(stringURL: "https://i1.sndcdn.com/artworks-000077403039-k956ck-large.jpg")
    if n.connected() {
     n.launchRequestDownloading(false, timeout: 30, method: ApiNetwork.MethodRequest.GET, 
     completion: { (data, totalLengthDownloading, currentLengthDownloaded, error) -> Void in
                          if !error {
                            image  = UIImage(data: n.totalDataDownloading)
                        }
                    })

    } else { /* There is no network */}

### Method Request
  for your method request can use .GET .POST .DELETE  .PUT

## Output Response with launchRequest, launchRequestWithNSURL 
By default the response output try to convert to NSDictionary. To change the output response type:

    let n : ApiNetwork = ApiNetwork(stringURL: "http://google.fr")
    n.ouput = ApiNetwork.ResponseOutput.NSData // FOR NSData
    n.ouput = ApiNetwork.ResponseOutput.String // FOR String
    n.ouput = ApiNetwork.ResponseOutput.NSDictionary // FOR NSDictionary


### HOW TO USE Response with launchRequest, launchRequestWithNSURL 
  
    let n : ApiNetwork = ApiNetwork(stringURL: "http://google.fr")
    n.ouput = ApiNetwork.ResponseOutput.String
    if n.connected() {
     n.launchRequest(false, timeout: 10, method: ApiNetwork.MethodRequest.GET,
                        completion: {(response :NSDictionary?) -> Void in
                           
                           if result != nil {
                              let s : String? =  response!.objectForKey(ApiNetwork.KeyResult.RESPONSE.rawValue) as? String
                              let statusCode : Int = response!.objectForKey(ApiNetwork.KeyResult.CODE_RESPONSE.rawValue) as Int
                              let err : String = response!.objectForKey(ApiNetwork.KeyResult.CONNECTION_ERROR) as? String 
                              
                              if err != nil { /*There is an error  */ }
                              if statusCode == 404 { /* Ressource URL not longer exist */  }
                              if s != nil { println(s)  }
                           }
                                                 
                    })
    } else { /* There is no network */}


## Still need help?

Ask me on hangout, [+BillaNorbert](https://plus.google.com/+BillaNorbert/)
