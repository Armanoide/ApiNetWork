
//
//  ApiNetWork.swift
//  ApiNetWork
//
//  Created by Norbert Billa on 26/10/2014.
//  Copyright (c) 2014 norbert. All rights reserved.
//

import Foundation
import SystemConfiguration
import UIKit

/**
Request Method HTTP/1.1

- POST
- GET
- DELETE
- PUT
*/
public enum ApiNetWorkMethodRequest : String {
    case POST                   = "POST"
    case GET                    = "GET"
    case DELETE                 = "DELETE"
    case PUT                    = "PUT"
    case HEAD                   = "HEAD"
    case PATCH                  = "PATCH"
}


private enum ApiNetWorkTypeRequest {
    case NORMAL
    case DOWNLOAD
}

public class ApiNetWorkResponse {
    
    public private (set) var status_code               : Int = -1
    public private (set) var errors                    : NSError?
    public private (set) var header                    : String!
    public private (set) var URL                       : String!
    public private (set) var mime_type                 : String!
    
    public private (set) var expectLengthDownloading   : Int64!
    public private (set) var totalLengthDownloaded     : Int64!
    
    private var responseString                  : String!
    private var data                            : NSData!
    
    
    init(data: NSData?, errors: NSError?, expectLengthDownloading: Int64, totalLengthDownloaded: Int64) {
        self.data                       = data
        self.errors                     = errors
        self.expectLengthDownloading    = expectLengthDownloading
        self.totalLengthDownloaded      = totalLengthDownloaded
    }
    
    init(data: NSData?, errors: NSError?, response :NSURLResponse?) {
        var jsonReturn : NSMutableDictionary!
        
        self.data = data
        
        if response != nil {
            self.status_code        = (response! as! NSHTTPURLResponse).statusCode
            if let __rs             = NSString(data: data!, encoding: NSUTF8StringEncoding) {
                self.responseString = __rs as! String
            } else {
                assert(true, "unkown encode, please use launchRequestDownloading method")
            }
            self.mime_type          = (response! as! NSHTTPURLResponse).MIMEType
            self.URL                = (response! as! NSHTTPURLResponse).URL!.absoluteString
        }
        
        if responseString == nil && data != nil {
            responseString = NSString(data: data!, encoding: NSASCIIStringEncoding) as! String
        }
        
    }
    
    private func parseJSON(inputData : NSData, originData :String) -> NSDictionary? {
        var errorJson  : NSError?
        
        var json : NSDictionary?
        
        json = NSJSONSerialization.JSONObjectWithData(inputData, options: NSJSONReadingOptions.MutableContainers, error: &errorJson) as? NSDictionary
        
        return json
    }
    
    public func didFailNotConnectedToInternet() -> Bool    { return self.errors?.code == NSURLErrorNotConnectedToInternet  }
    public func getResponseString() -> String?             { return self.responseString }
    public func getResponseData() -> NSData?               { return self.data }
    public func getResponseDictionary() -> NSDictionary?   { if self.data == nil { return nil } else { return self.parseJSON(data!, originData: responseString! as String) } }
    
}

class ApiNetWorkConnection : NSObject, NSURLConnectionDataDelegate {
    
    private  var errorRequest                           : NSError?
    private  var connection                             : NSURLConnection!
    private  var writeFile                              : Bool  = false
    
    
    private var totalDataDownloaded                     : NSMutableData!
    private var expectLengthDownloading                 : Int64 = 0
    private var totalLengthDownloaded                   : Int64 = 0
    
    
    private var pathFileDownload                        : String               = ""
    
    private var response                                : NSURLResponse!
    private var typeRequest                             : ApiNetWorkTypeRequest = .NORMAL
    private var fh                                      : NSFileHandle!
    private var completion                              : ((response : ApiNetWorkResponse)-> Void)!
    private var didReceived                             : ((response : ApiNetWorkResponse)-> Void)?
    private var didFinished                             : ((response : ApiNetWorkResponse)-> Void)!
    
    
    init(request : NSURLRequest, completion : ((response :ApiNetWorkResponse)-> Void)) {
        super.init()
        self.typeRequest    = .NORMAL
        self.completion     = completion
        self.connection     = NSURLConnection(request: request, delegate: self, startImmediately: false)
        self.connection.start()
        self.setNetworkActivityIndicatorVisible(visibility: true)
    }
    
    init(request : NSURLRequest, pathFileDownload : String,
        didReceived : ((response : ApiNetWorkResponse)-> Void)?,
        didFinished : ((response : ApiNetWorkResponse)-> Void)) {
            super.init()
            self.typeRequest        = .DOWNLOAD
            self.didFinished        = didFinished
            self.didReceived        = didReceived
            self.writeFile          = pathFileDownload == "" ? false : true
            self.pathFileDownload   = pathFileDownload
            self.connection         = NSURLConnection(request: request, delegate: self, startImmediately: false)
            self.connection.start()
    }
    
    ////////////////////////////////////////////////////////////////
    ///////////////   STATUS INDICATOR ACTIVITY   //////////////////
    ////////////////////////////////////////////////////////////////
    
    private struct ActivityManager {  static var NumberOfCallsToSetVisible : Int32 = 0 }
    
    private func setNetworkActivityIndicatorVisible(visibility setVisible : Bool) -> Void {
        let newValue = OSAtomicAdd32((setVisible ? +1 : -1), &ActivityManager.NumberOfCallsToSetVisible)
        assert(newValue >= 0, "Network Activity Indicator was asked to hide more often than shown")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = setVisible
    }
    
    
    ////////////////////////////////////////////////////////////////
    ////////////////////////   RESPONSE   //////////////////////////
    ////////////////////////////////////////////////////////////////
    
    func prepareResponseRequest(#data: NSData?, errors: NSError?, response :NSURLResponse?) -> ApiNetWorkResponse {
        self.setNetworkActivityIndicatorVisible(visibility: false)
        return ApiNetWorkResponse(data: data, errors: errors, response: response)
    }
    
    
    ////////////////////////////////////////////////////////////////
    //////////////////      SEEK & FILE      ///////////////////////
    ////////////////////////////////////////////////////////////////
    
    
    func stopDownloading() -> Void {
        if self.connection != nil { self.connection.cancel() }
    }
    
    
    ////////////////////////////////////////////////////////////////
    //////////////////      SEEK & FILE      ///////////////////////
    ////////////////////////////////////////////////////////////////
    
    
    func clear()                                        { totalDataDownloaded  = nil }
    
    private func seekFileHandle(response : NSURLResponse){
        
        if self.writeFile == false {
            return
        }
        
        let rh : NSHTTPURLResponse  = response as! NSHTTPURLResponse
        self.fh                     = NSFileHandle(forWritingAtPath: self.pathFileDownload as String)
        
        assert(!(fh == nil) , "[ApiNetWork % Dowloading ] : Cannot Write at path \(self.pathFileDownload) ~~~")
        switch rh.statusCode {
        case 206:
            
            let range : NSString  = (rh.allHeaderFields as NSDictionary).valueForKey("Content-Range") as! NSString
            var error : NSError?
            var regex : NSRegularExpression!
            
            
            // Check to see if the server returned a valid byte-range
            regex = NSRegularExpression(pattern: "bytes (\\d+)-\\d+/\\d+", options: NSRegularExpressionOptions.CaseInsensitive, error: &error)
            
            if (error != nil) {
                self.fh.truncateFileAtOffset(0)
                break;
            }
            
            // If the regex didn't match the number of bytes, start the download from the beginning
            var match : NSTextCheckingResult = regex.firstMatchInString(range as String, options: NSMatchingOptions.Anchored, range: NSMakeRange(0, range.length))!
            
            if (match.numberOfRanges < 2) {
                self.fh.truncateFileAtOffset(0)
                break
            }
            
            // Extract the byte offset the server reported to us, and truncate our
            // file if it is starting us at "0".  Otherwise, seek our file to the
            // appropriate offset.
            let byteStr : NSString  = range.substringWithRange(match.rangeAtIndex(1))
            
            let bytes : UInt64 =  UInt64(byteStr.longLongValue)
            
            if bytes < 0 {
                self.fh.truncateFileAtOffset(0)
                break
            } else {
                fh.seekToFileOffset(bytes)
            }
            break
        default:
            
            if self.writeFile == false {
                break
            }
            
            fh.truncateFileAtOffset(0)
            break
        }
        
    }
    
    ////////////////////////////////////////////////////////////////
    ///////////////////      CONNECTION      ///////////////////////
    ////////////////////////////////////////////////////////////////
    
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        self.errorRequest           = error
        self.connection             = connection
        
        println("ApiNetWork fail : - \(error.localizedDescription)")
        
        switch self.typeRequest {
        case .DOWNLOAD:
            self.didFinished(response : ApiNetWorkResponse(data: nil, errors: error, expectLengthDownloading: 0, totalLengthDownloaded: 0))
            break
        case .NORMAL:
            self.completion(response: self.prepareResponseRequest(data: nil, errors: error, response: self.response))
        default:break
        }
    }
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        
        self.response = response
        self.totalLengthDownloaded      = 0
        self.totalDataDownloaded        = NSMutableData()
        self.connection                 = connection
        self.expectLengthDownloading    = response.expectedContentLength
        
        
        switch self.typeRequest {
        case .DOWNLOAD:
            self.seekFileHandle(response)
            break
        case .NORMAL: break
        }
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        
        self.connection                 = connection
        self.totalDataDownloaded.appendData(data)
        self.totalLengthDownloaded      += data.length
        
        switch self.typeRequest {
        case .NORMAL: break
            
        case .DOWNLOAD:
            if self.writeFile == true {
                
                self.fh.writeData(data)
                self.fh.synchronizeFile()
            }
            break
        }
        dispatch_async(dispatch_get_main_queue(),{
            
            self.didReceived?(
                response                : ApiNetWorkResponse(
                    data                    : data,
                    errors                  : self.errorRequest,
                    expectLengthDownloading : self.expectLengthDownloading,
                    totalLengthDownloaded   : self.totalLengthDownloaded))
            
        })
    }
    
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        
        
        switch self.typeRequest {
        case .DOWNLOAD:
            if self.writeFile == true {
                self.fh.closeFile()
                self.fh = nil
            }
            dispatch_async(dispatch_get_main_queue(),{
                self.didFinished(
                    response                : ApiNetWorkResponse(data: self.totalDataDownloaded,
                        errors                  : self.errorRequest,
                        expectLengthDownloading : self.expectLengthDownloading,
                        totalLengthDownloaded   : self.totalLengthDownloaded))
            })
            break
        case .NORMAL:
            dispatch_async(dispatch_get_main_queue(),{
                self.completion(response: self.prepareResponseRequest(data: self.totalDataDownloaded, errors: self.errorRequest, response: self.response))
            })
            break
        }
        
        
    }
    
}

/// Ascy Manager NetWork V2.0
public class ApiNetWork {
    
    
    
    // API PARAMS
    private(set)    var url                             : NSURL!
    private         var agent                           : String!
    private         var json : NSDictionary!
    private         var method                          : ApiNetWorkMethodRequest = .GET
    private         var cached                          : Bool = false
    private         var parameter                       : NSDictionary!
    private         var pathFileDownload                : String               = ""
    private         var connection                      : ApiNetWorkConnection!
    private         var timeout                         : NSTimeInterval = 45
    
    
    public init (){}
    public init (stringURL: String) {
        if self.isConnectedToNetwork()
        { self.url = NSURL(string: stringURL) }
    }
    
    class public func launchRequest(url : String, completion: (response : ApiNetWorkResponse) -> Void) -> ApiNetWork {
        
        let n = ApiNetWork(stringURL: url)
        n.launchRequest(completion)
        return n
    }
    
    class public func launchRequestDownloading(url : String,
        didReceived: ((response : ApiNetWorkResponse) -> Void)?,
        didFinished: (response : ApiNetWorkResponse) -> Void) -> ApiNetWork {
            
            let n = ApiNetWork(stringURL: url)
            n.launchRequestDownloading(didReceived: didReceived, didFinished: didFinished)
            return n
    }
    
    class public func URLencode(url: String) -> String {
        
        var output      : String = ""
        let sourceLen   = count(url)
        for c in url.unicodeScalars {
            
            switch c {
            case " ":
                output.append(Character("+"))
                break
            case ".", "-", "_", "~" ,
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v",
            "w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P",
            "Q","R","S","T","U","V","W","X","Z","Y",
            "0","1","2","3","4","5","6","7","8","9":
                output.append(c)
            default:
                output +=   NSString(format: "%%%002X", c.value) as String
                break
                
            }
        }
        return output
    }
    
    
    /**
    Set a user-agent of the request
    
    :param: agent-> the new user-agent
    
    :returns: Void
    */
    public func setUserAgent(agent : String) -> Void           { self.agent = agent }
    public func setJsonDictionnary(json : NSDictionary)        { self.json = json }
    public func setMethod(method : ApiNetWorkMethodRequest)    { self.method = method }
    public func setPathFileDownload(path: String)              { self.pathFileDownload = path }
    public func setCached(cached: Bool)                        { self.cached = cached }
    /**
    timeout-> (NSTimeInterval) max sencond during a connection attempt to send the request
    */
    public func setTimeout(timeout: NSTimeInterval)            { self.timeout = timeout }
    
    
    /**
    :see: Original post - http://www.chrisdanielson.com/2009/07/22/iphone-network-connectivity-test-example/
    */
    private func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0)).takeRetainedValue()
        }
        
        var flags: SCNetworkReachabilityFlags = 0
        if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == 0 {
            return false
        }
        
        let isReachable = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return (isReachable && !needsConnection) ? true : false
    }
    
    /**
    Check if network can be reached
    
    :returns: Bool true if network is available
    */
    public func connected() -> Bool {
        
        let net     = self.isConnectedToNetwork()
        //let reach   = Reachability.isHostReachability(host: self.url.absoluteString!)
        
        //println("net = \(net) et le reach =\(reach)")
        
        return net //&& reach
    }
    
    
    
    /**
    Add parameter to the request. The function can be you only with method
    launchRequest and launchRequestDownloading
    
    :param: key-> the of the parameter
    
    :param: value-> the value of the paramter
    
    :returns: Void
    */
    public func addParameterWithKey(key: String, value: String) -> Void {
        var p : NSMutableDictionary?
        if self.parameter == nil { p = NSMutableDictionary() }
        else { p = NSMutableDictionary(dictionary: self.parameter!) }
        p?.setValue(ApiNetWork.URLencode(value) , forKey: ApiNetWork.URLencode(key))
        self.parameter = p
    }
    
    
    
    /**
    the function will immediately lanuch in a therad request. Response will be
    send to the main thread
    
    :param: request-> (NSURLRequest)
    
    :param: completion-> ((NSDictionary?)-> Void))
    
    :returns: Void
    */
    public func launchRequestWithNSURL(request : NSURLRequest,
        completion : ((response :ApiNetWorkResponse)-> Void)) -> Void {
            
            if self.connected() {
                self.connection = ApiNetWorkConnection(request: request, completion: completion)
            } else {
                let errorNet = NSError(domain: self.url.absoluteString!, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey :"Cannot connect to the internet. Service may not be available."])
                completion(response: ApiNetWorkResponse(data: nil, errors: errorNet, response: nil))
            }
    }
    
    
    public func prepareRequest() -> NSMutableURLRequest {
        
        var error : NSError?
        
        self.url = self.url == nil ? NSURL(string: "") : self.url
        let request : NSMutableURLRequest = NSMutableURLRequest(URL: self.url)
        
        if self.json != nil {
            if let requestData : NSData = NSJSONSerialization.dataWithJSONObject(self.json, options: nil, error: &error) {
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.setValue(NSString(format:"%lu", requestData.length) as String, forHTTPHeaderField:"Content-Length")
                request.HTTPBody = requestData
                println(request.HTTPBody)
            }
            else { println("\(error?.localizedDescription)") }
        }
        
        request.cachePolicy = self.cached == true
            ? NSURLRequestCachePolicy.ReloadRevalidatingCacheData
            : NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        request.timeoutInterval = self.timeout
        request.HTTPMethod = self.method.rawValue
        if self.parameter != nil {
            for p in parameter!.allKeys {
                let value   : String?   = parameter?.objectForKey(p) as! String?
                let key     : String    = p as! String
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if self.agent != nil { request.setValue(self.agent, forHTTPHeaderField: "User-Agent") }
        return request
    }
    
    /**
    the function will immediately lanuch in a therad request. Response will be
    send to the main thread
    
    :param: cache-> (Bool) determine if the request will save and check in the cache before
    
    :param: completion-> ((response : ApiNetWorkResponse)-> Void))
    
    :returns: Void
    */
    public func launchRequest(completion : ((response : ApiNetWorkResponse)-> Void)) -> Void {
        
        if self.connected() {
            let request = self.prepareRequest()
            self.launchRequestWithNSURL(request, completion: completion)
        } else {
            let errorNet = NSError(domain: self.url.absoluteString ?? "", code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey :"Cannot connect to the internet. Service may not be available."])
            completion(response: ApiNetWorkResponse(data: nil, errors: errorNet, response: nil))
            
        }
    }
    
    /**
    the function will immediately lanuch in a therad request. Response will be
    send to the main thread
    
    :param: cache-> (Bool) determine if the request will save and check in the cache before
    
    :param: method -> (MethodRequest)
    
    :param: completion->  (data :NSData?, totalLengthDownloading: Int64, currentLengthDownloaded: Int64, error :Bool)-> Void)
    
    :returns: Void
    */
    
    public func launchRequestDownloading(
        #didReceived : ((response : ApiNetWorkResponse)-> Void)?,
        didFinished : ((response : ApiNetWorkResponse)-> Void))
        -> Void {
            
            var error                                           : NSError?
            var downloadedBytes                                 : UInt64 = 0
            var range                                           : UInt64!
            var seekDownload                                    : UInt64 = 0
            var writeFile                                       : Bool = self.pathFileDownload == "" ? false : true
            
            
            let fm : NSFileManager = NSFileManager.defaultManager()
            if fm.fileExistsAtPath(self.pathFileDownload) {
                let fileDico : NSDictionary! = fm.attributesOfItemAtPath(self.pathFileDownload, error: &error)!
                if error != nil && fileDico != nil {
                    downloadedBytes = fileDico.fileSize()
                    seekDownload = downloadedBytes
                }
            }
            else if writeFile == true
            { fm.createFileAtPath(self.pathFileDownload, contents: nil, attributes: nil) }
            
            if  self.url == nil {
                didFinished(response : ApiNetWorkResponse(data: nil, errors: error, expectLengthDownloading: 0, totalLengthDownloaded: 0))
                return
            }
            let request : NSMutableURLRequest = NSMutableURLRequest(URL: self.url)
            request.setValue("", forHTTPHeaderField: "Accept-Encoding")
            request.cachePolicy = self.cached == true
                ? NSURLRequestCachePolicy.ReloadRevalidatingCacheData
                : NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
            request.timeoutInterval = self.timeout
            request.HTTPMethod = self.method.rawValue
            if self.parameter != nil {
                for p in parameter!.allKeys {
                    let value   : String?   = parameter?.objectForKey(p) as! String?
                    let key     : String    = p as! String
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            if (downloadedBytes > 0) {
                let requestRange = NSString(format: "bytes=%d-", downloadedBytes)
                request.setValue(requestRange as String, forHTTPHeaderField: "Range")
            } else if range != nil {
                let requestRange = NSString(format: "bytes=%d-", range)
                request.setValue(requestRange as String, forHTTPHeaderField: "Range")
            }
            
            
            if self.agent != nil { request.setValue(self.agent, forHTTPHeaderField: "User-Agent") }
            self.connection = ApiNetWorkConnection(request: request, pathFileDownload: self.pathFileDownload, didReceived: didReceived, didFinished: didFinished)
    }
    
    /**
    the function stop the downloading if the function "launch" as been alredy call
    
    :returns: Void
    */
    public func stopDownloading() -> Void {
        self.connection?.stopDownloading()
    }
    
    public func clearDownload() -> Void {
        self.connection.clear()
    }
}
