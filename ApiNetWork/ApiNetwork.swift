//
//  ApiNetwork.swift
//  ApiNetwork
//
//  Created by Norbert Billa on 26/10/2014.
//  Copyright (c) 2014 norbert. All rights reserved.
//

import Foundation
import UIKit

/// Ascy Manager NetWork V1.1
class ApiNetwork : NSObject, NSURLConnectionDataDelegate {
    
    
    private struct ActivityManager {  static var NumberOfCallsToSetVisible : Int32 = 0 }
    
    /**
    Output Response
    
    - NSDictionary
    - NSData
    - String
    */
    enum ResponseOutput {
        case NSDictionary
        case String
        case NSData
    }
    
    /**
    Request Method HTTP/1.1
    
    - POST
    - GET
    - DELETE
    - PUT
    */
    enum MethodRequest : String {
        case POST                   = "POST"
        case GET                    = "GET"
        case DELETE                 = "DELETE"
        case PUT                    = "PUT"
        case HEAD                   = "HEAD"
        case CONNECT                = "CONNECT"
    }
    
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
    
    
    // API PARAMS
    var ouput                                           : ResponseOutput = ResponseOutput.NSDictionary
    private(set) internal var url                       : NSURL!
    private(set) internal var agent                     : String!
    private(set) internal var parameter                 : NSDictionary!
    private(set) internal var objectJsonRequest         : NSDictionary!
    
    private(set) internal var totalDataDownloaded       : NSMutableData!
    private(set) internal var expectLengthDownloading   : Int64 = 0
    private(set) internal var totalLengthDownloaded     : Int64 = 0
    private(set) internal var errorDownloading          : NSError?
    
    var completionDownloading   : ((data :NSData?, totalLengthDownloading: Int64, currentLengthDownloaded: Int64, error: Bool)-> Void)?
    
    override init (){ super.init() }
    init (stringURL: String) {
        super.init()
        if Reachability.isConnectedToNetwork()
        { self.url = NSURL(string: stringURL) }
    }
    
    
    /**
    Check if network can be reached
    
    :returns: Bool true if network is available
    */
    func connected() -> Bool { return Reachability.isConnectedToNetwork() }
    
    
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
    
    
    func setJSONObject() {}
    
    private func parseJSON(inputData : NSData, originData :String) -> NSDictionary? {
        var errorJson  : NSError?
        
        var json : NSDictionary?
        
        json = NSJSONSerialization.JSONObjectWithData(inputData, options: NSJSONReadingOptions.MutableContainers, error: &errorJson) as? NSDictionary
        
        return json
    }
    
    private func getJsonResponse(#data: NSData?, errors: NSError?, response :NSURLResponse?) -> NSDictionary? {
        var jsonReturn : NSMutableDictionary!
        
        var statusCode      : NSInteger = -1
        var mymetype        : String?
        var responseString  : NSString?
        var urlResponse     : String?
        
        if response != nil {
            statusCode = (response! as NSHTTPURLResponse).statusCode
            responseString  = NSString(data: data!, encoding: NSUTF8StringEncoding)
            mymetype        = (response! as NSHTTPURLResponse).MIMEType
            urlResponse     = (response! as NSHTTPURLResponse).URL!.absoluteString
        }
        
        if responseString == nil {
            responseString = NSString(data: data!, encoding: NSASCIIStringEncoding)
        }
        
        if errors == nil
        {
            
            switch self.ouput {
            case ResponseOutput.NSDictionary:
                var obj : NSDictionary?  = self.parseJSON(data!, originData: responseString!)
                jsonReturn = NSMutableDictionary(object: obj!, forKey: KeyResult.RESPONSE.rawValue)
                break
            case ResponseOutput.String:
                jsonReturn = NSMutableDictionary(object: responseString == nil ? "" : responseString!, forKey: KeyResult.RESPONSE.rawValue)
                break
            case ResponseOutput.NSData:
                jsonReturn = NSMutableDictionary(object: data != nil ? data! : NSData(), forKey: KeyResult.RESPONSE.rawValue)
                break
            default: break
            }
            
        }
        
        jsonReturn = jsonReturn == nil ? NSMutableDictionary() : jsonReturn
        self.setNetworkActivityIndicatorVisible(visibility: false)
        jsonReturn.setObject(mymetype != nil ? mymetype! : "", forKey: KeyResult.MIME_TYPE.rawValue)
        jsonReturn.setObject(urlResponse != nil ? urlResponse! : "", forKey: KeyResult.URL.rawValue)
        jsonReturn.setObject(String(statusCode), forKey: KeyResult.CODE_RESPONSE.rawValue)
        jsonReturn.setObject(errors == nil ? "" : errors!.localizedDescription , forKey: KeyResult.CONNECTION_ERROR.rawValue)
        return jsonReturn
    }
    
    
    /**
    the function will immediately lanuch in a therad request. Response will be
    send to the main thread
    
    :param: request-> (NSURLRequest)
    
    :param: completion-> ((NSDictionary?)-> Void))
    
    :returns: Void
    */
    func launchRequestWithNSURL(request : NSURLRequest,
        completion : ((NSDictionary?)-> Void)) -> Void {
            
            var data : NSData?
            var response : NSURLResponse?
            var errors : NSError?
            
            
            self.setNetworkActivityIndicatorVisible(visibility: true)
            
            
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                
                data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &errors)
                
                if data != nil {
                    
                    dispatch_async(dispatch_get_main_queue(),{
                            completion(self.getJsonResponse(data : data?, errors: errors?, response: response?)!)
                    });
                    
                }
            }
    }
    
    
    /**
    the function will immediately lanuch in a therad request. Response will be
    send to the main thread
    
    :param: cache-> (Bool) determine if the request will save and check in the cache before
    
    :param: timeout-> (NSTimeInterval) max sencond during a connection attempt to send the request

    :param: method -> (MethodRequest)
    
    :param: completion-> ((NSDictionary?)-> Void))
    
    :returns: Void
    */
    func launchRequest(cache: Bool,
        timeout: NSTimeInterval ,
        method: MethodRequest,
        completion : ((NSDictionary?)-> Void)) -> Void {
            
            
            if  self.url == nil { completion(nil);return }
            let request : NSMutableURLRequest = NSMutableURLRequest(URL: self.url)
            request.cachePolicy = cache == true
                ? NSURLRequestCachePolicy.ReloadRevalidatingCacheData
                : NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
            request.timeoutInterval = timeout
            request.HTTPMethod = method.rawValue
            if self.parameter != nil {
                for p in parameter!.allKeys {
                    let value   : String?   = parameter?.objectForKey(p) as String?
                    let key     : String    = p as String
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            if self.agent != nil { request.setValue(self.agent, forHTTPHeaderField: "User-Agent") }
            self.launchRequestWithNSURL(request, completion: completion)
    }
    
    /**
    the function will immediately lanuch in a therad request. Response will be
    send to the main thread
    
    :param: cache-> (Bool) determine if the request will save and check in the cache before
    
    :param: timeout-> (NSTimeInterval) max sencond during a connection attempt to send the request
    
    :param: method -> (MethodRequest)
    
    :param: completion->  (data :NSData?, totalLengthDownloading: Int64, currentLengthDownloaded: Int64, error :Bool)-> Void)   
    
    :returns: Void
    */
    func launchRequestDownloading(cache: Bool,
        timeout: NSTimeInterval ,
        method: MethodRequest,
        completion : (data :NSData?, expectLengthDownloading: Int64, totalLengthDownloaded: Int64, error :Bool)-> Void)
        -> Void {
            
            
            if  self.url == nil {
                completion(data: nil, expectLengthDownloading: 0, totalLengthDownloaded: 0, error: true);return
            }
            let request : NSMutableURLRequest = NSMutableURLRequest(URL: self.url)
            request.setValue("", forHTTPHeaderField: "Accept-Encoding")
            request.cachePolicy = cache == true
                ? NSURLRequestCachePolicy.ReloadRevalidatingCacheData
                : NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
            request.timeoutInterval = timeout
            request.HTTPMethod = method.rawValue
            if self.parameter != nil {
                for p in parameter!.allKeys {
                    let value   : String?   = parameter?.objectForKey(p) as String?
                    let key     : String    = p as String
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            if self.agent != nil { request.setValue(self.agent, forHTTPHeaderField: "User-Agent") }
            self.completionDownloading = completion
            NSURLConnection(request: request, delegate: self, startImmediately: true)
    }
    
    
    
    
    
    internal func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        self.errorDownloading  = error
        self.completionDownloading!(data: nil, totalLengthDownloading: 0, currentLengthDownloaded: 0, error: true);
    }
    
    internal func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.expectLengthDownloading = response.expectedContentLength
        self.totalLengthDownloaded = 0
        self.totalDataDownloaded = NSMutableData()
    }
    
    internal func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.totalDataDownloaded.appendData(data)
        self.totalLengthDownloaded += data.length
        self.completionDownloading!(data: data, totalLengthDownloading: self.expectLengthDownloading, currentLengthDownloaded: self.totalLengthDownloaded, error: false)
    }
    
    
}
