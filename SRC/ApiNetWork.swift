
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
enum ApiNetWorkMethodRequest : String {
    case POST                   = "POST"
    case GET                    = "GET"
    case DELETE                 = "DELETE"
    case PUT                    = "PUT"
    case HEAD                   = "HEAD"
    case PATCH                  = "PATCH"
}

/**
Output Response

- NSDictionary
- NSData
- String
*/
enum ApiNetWorkResponseType {
    case NSDictionary
    case String
    case NSData
}

class ApiNetWorkResponse {
    
    private (set) var status_code               : Int = -1
    private (set) var errors                    : NSError!
    private (set) var header                    : String!
    private (set) var URL                       : String!
    private (set) var mime_type                 : String!
    
    private (set) var expectLengthDownloading   : Int64!
    private (set) var totalLengthDownloaded     : Int64!
    
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
    
    func didFailNotConnectedToInternet() -> Bool    { return self.errors.code == NSURLErrorNotConnectedToInternet  }
    func getResponseString() -> String?             { return self.responseString }
    func getResponseData() -> NSData?               { return self.data }
    func getResponseDictionary() -> NSDictionary?   { return self.parseJSON(data!, originData: responseString! as String) }
    
}

/// Ascy Manager NetWork V2.0
class ApiNetWork : NSObject, NSURLConnectionDataDelegate {
    
    
    private struct ActivityManager {  static var NumberOfCallsToSetVisible : Int32 = 0 }
    
    /**
    The func launchRequest and launchRequestWithNSURL return a description
    of the Request in JSON. KeyResult is the key to acces to each information
    of the Request
    
    - CODE_RESPONSE     : satut code of Request ex: 404,200, 201
    - CONNECTION_ERROR  : error description of the request
    - RESPONSE          : response of the request depends of the ResponseOutput
    - HRADER            : header of the request
    - MIME_TYPE         : myme type of the request ex:application/json
    - URL               : response url request
    */
    enum KeyResult : String {
        case CODE_RESPONSE          = "status code"
        case CONNECTION_ERROR       = "errors"
        case RESPONSE               = "result response"
        case HRADER                 = "header response"
        case MIME_TYPE              = "myme type"
        case URL                    = "url"
    }
    
    enum TypeRequest {
        case NORMAL
        case DOWNLOAD
    }
    
    
    // API PARAMS
    private(set) internal var url                       : NSURL!
    private(set) internal var agent                     : String!
    private(set) internal var parameter                 : NSDictionary!
    private(set) internal var objectJsonRequest         : NSDictionary!
    private(set) internal var errorRequest              : NSError?
    private(set) internal var connectionDownloading     : NSURLConnection!
    private(set) internal var pathFile                  : NSString!
    private(set) internal var writeFile                 : Bool  = false
    private(set) internal var method                    : ApiNetWorkMethodRequest = .GET
    
    
    private  var totalDataDownloaded                    : NSMutableData!
    private  var expectLengthDownloading                : Int64 = 0
    private  var totalLengthDownloaded                  : Int64 = 0
    
    private var cached                                  : Bool = false
    
    private var pathFileDownload : String               = ""
    
    private var response                                : NSURLResponse!
    private var typeRequest                             : TypeRequest = .NORMAL
    private var fh                                      : NSFileHandle!
    private var seekDownload                            : UInt64 = 0
    private var completion                              : ((response : ApiNetWorkResponse)-> Void)!
    private var didReceived                             : ((response : ApiNetWorkResponse)-> Void)?
    var json : NSDictionary!
    
    /**
    timeout-> (NSTimeInterval) max sencond during a connection attempt to send the request
    */
    var range                                           : UInt64!
    
    /**
    timeout-> (NSTimeInterval) max sencond during a connection attempt to send the request
    */
    var timeout                                         : NSTimeInterval = 45
    
    
    private var didFinished : ((response : ApiNetWorkResponse)-> Void)!
    
    override init (){ super.init() }
    init (stringURL: String) {
        super.init()
        if self.isConnectedToNetwork()
        { self.url = NSURL(string: stringURL) }
    }
    
    
    class func launchRequest(url : String, completion: (response : ApiNetWorkResponse) -> Void) -> ApiNetWork {
        
        let n = ApiNetWork(stringURL: url)
        n.launchRequest(completion)
        return n
    }

    class func launchRequestDownloading(url : String,
        didReceived: ((response : ApiNetWorkResponse) -> Void)?,
        didFinished: (response : ApiNetWorkResponse) -> Void) -> ApiNetWork {
        
        let n = ApiNetWork(stringURL: url)
        n.launchRequestDownloading(didReceived: didReceived, didFinished: didFinished)
        return n
    }

    
    
    func setMethod(method : ApiNetWorkMethodRequest)    { self.method = method }
    func setPathFileDownload(path: String)              { self.pathFileDownload = path ; self.writeFile = true }
    func setCached(cached: Bool)                        { self.cached = cached }
    
    func clear()                                        { totalDataDownloaded  = nil }
    
    private func seekFileHandle(response : NSURLResponse){
        
        if self.writeFile == false {
            return
        }
        
        let rh : NSHTTPURLResponse  = response as! NSHTTPURLResponse
        self.fh                     = NSFileHandle(forWritingAtPath: self.pathFile as String)
        
        assert(!(fh == nil) , "[ApiNetWork % Dowloading ] : Cannot Write at path \(self.pathFile)")
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
            break;
        default:
            
            if self.writeFile == false {
                break
            }
            
            fh.truncateFileAtOffset(0)
            break
        }
        
    }
    
    
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
    func connected() -> Bool {
        
        let net     = self.isConnectedToNetwork()
        //let reach   = Reachability.isHostReachability(host: self.url.absoluteString!)
        
        //println("net = \(net) et le reach =\(reach)")
        
        return net //&& reach
    }
    
    
    /**
    Set a user-agent of the request
    
    :param: agent-> the new user-agent
    
    :returns: Void
    */
    func changeUserAgent(agent : String) -> Void { self.agent = agent }
    
    private func setNetworkActivityIndicatorVisible(visibility setVisible : Bool) -> Void {
        let newValue = OSAtomicAdd32((setVisible ? +1 : -1), &ActivityManager.NumberOfCallsToSetVisible)
        assert(newValue >= 0, "Network Activity Indicator was asked to hide more often than shown")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = setVisible
    }
    
    /**
    Add parameter to the request. The function can be you only with method
    launchRequest and launchRequestDownloading
    
    :param: key-> the of the parameter
    
    :param: value-> the value of the paramter
    
    :returns: Void
    */
    func addParameterWithKey(key: String, value: String) -> Void {
        var p : NSMutableDictionary?
        if parameter == nil { p = NSMutableDictionary() }
        else { p = NSMutableDictionary(dictionary: parameter!) }
        p?.setValue(value, forKey: key)
        parameter = p
    }
    
    func prepareResponseRequest(#data: NSData?, errors: NSError?, response :NSURLResponse?) -> ApiNetWorkResponse {
        self.setNetworkActivityIndicatorVisible(visibility: false)
        return ApiNetWorkResponse(data: data, errors: errors, response: response)
    }
    
    /**
    the function will immediately lanuch in a therad request. Response will be
    send to the main thread
    
    :param: request-> (NSURLRequest)
    
    :param: completion-> ((NSDictionary?)-> Void))
    
    :returns: Void
    */
    func launchRequestWithNSURL(request : NSURLRequest,
        completion : ((response :ApiNetWorkResponse)-> Void)) -> Void {
            
            
            
            if self.connected() {
                self.setNetworkActivityIndicatorVisible(visibility: true)
                self.completion = completion
                NSURLConnection(request: request, delegate: self, startImmediately: true)
            } else {
                let errorNet = NSError(domain: self.url.absoluteString!, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey :"Cannot connect to the internet. Service may not be available."])
                completion(response: ApiNetWorkResponse(data: nil, errors: errorNet, response: nil))
            }
    }
    
    
    func prepareRequest() -> NSMutableURLRequest {
        
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
    func launchRequest(completion : ((response : ApiNetWorkResponse)-> Void)) -> Void {
        
        if self.connected() {
            let request = self.prepareRequest()
            self.launchRequestWithNSURL(request, completion: completion)
        } else {
            let errorNet = NSError(domain: self.url.absoluteString!, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey :"Cannot connect to the internet. Service may not be available."])
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
    
    func launchRequestDownloading(
        #didReceived : ((response : ApiNetWorkResponse)-> Void)?,
        didFinished : ((response : ApiNetWorkResponse)-> Void))
        -> Void {
            
            self.typeRequest = TypeRequest.DOWNLOAD
            self.didFinished = didFinished
            
            var error : NSError?
            var downloadedBytes : UInt64 = 0
            
            let fm : NSFileManager = NSFileManager.defaultManager()
            if fm.fileExistsAtPath(self.pathFileDownload) {
                let fileDico : NSDictionary! = fm.attributesOfItemAtPath(self.pathFileDownload, error: &error)!
                if error != nil && fileDico != nil {
                    downloadedBytes = fileDico.fileSize()
                    self.seekDownload = downloadedBytes
                }
            }
            else if self.writeFile == true
            { fm.createFileAtPath(self.pathFileDownload, contents: nil, attributes: nil) }
            
            self.pathFile = self.pathFileDownload
            
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
            } else if self.range != nil {
                let requestRange = NSString(format: "bytes=%d-", self.range)
                request.setValue(requestRange as String, forHTTPHeaderField: "Range")
            }
            
            
            if self.agent != nil { request.setValue(self.agent, forHTTPHeaderField: "User-Agent") }
            self.didReceived = didReceived
            NSURLConnection(request: request, delegate: self, startImmediately: true)
    }
    
    internal func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        self.errorRequest       = error
        self.connectionDownloading  = connection
        self.didFinished(response : ApiNetWorkResponse(data: nil, errors: error, expectLengthDownloading: 0, totalLengthDownloaded: 0))
    }
    
    internal func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        
        self.response = response
        self.totalLengthDownloaded      = 0
        self.totalDataDownloaded        = NSMutableData()
        self.connectionDownloading      = connection
        self.expectLengthDownloading    = response.expectedContentLength
        
        
        switch self.typeRequest {
        case .DOWNLOAD:
            self.seekFileHandle(response)
            break
        case .NORMAL: break
        default:break
            
        }
    }
    
    internal func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        
        switch self.typeRequest {
        case .NORMAL: break
        case .DOWNLOAD:
            if self.writeFile == true {
                
                self.fh.writeData(data)
                self.fh.synchronizeFile()
            }
            break
        }
        
        self.connectionDownloading      = connection
        self.totalDataDownloaded.appendData(data)
        self.totalLengthDownloaded      += data.length
        self.didReceived?(
            response                : ApiNetWorkResponse(
                data                    : data,
                errors                  : self.errorRequest,
                expectLengthDownloading : self.expectLengthDownloading,
                totalLengthDownloaded   : self.totalLengthDownloaded))
    }
    
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        
        dispatch_async(dispatch_get_main_queue(),{
            
            switch self.typeRequest {
            case TypeRequest.DOWNLOAD:
                if self.writeFile == true {
                    self.fh.closeFile()
                    self.fh = nil
                }
                self.didFinished(
                    response                : ApiNetWorkResponse(data: self.totalDataDownloaded,
                        errors                  : self.errorRequest,
                        expectLengthDownloading : self.expectLengthDownloading,
                        totalLengthDownloaded   : self.totalLengthDownloaded))
                break
            case TypeRequest.NORMAL:
                self.completion(response: self.prepareResponseRequest(data: self.totalDataDownloaded, errors: self.errorRequest, response: self.response))
                break
            default:break
            }
            
        })
        
    }
    
    /**
    the function stop the downloading if the function "launch" as been alredy call
    
    :returns: Void
    */
    internal func stopDownloading() -> Void {
        if self.connectionDownloading != nil { self.connectionDownloading.cancel() }
    }
}
