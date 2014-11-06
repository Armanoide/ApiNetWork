//
//  ApiNetwork.swift
//  muz
//
//  Created by Norbert Billa on 26/10/2014.
//  Copyright (c) 2014 norbert. All rights reserved.
//

import Foundation
import UIKit

class ApiNetwork : NSObject, NSURLConnectionDataDelegate {
    
    let DEGUG_MODE_NETWORK = true
    
    private struct ActivityManager {  static var NumberOfCallsToSetVisible : Int32 = 0 }
    
    // OUTPUT RESPNSE
    enum ResponseOutput {
        case NSDictionary
        case String
        case NSData
    }
    
    // METOHOD GET
    enum MethodRequest : String {
        case POST                   = "POST"
        case GET                    = "GET"
        case DELETE                 = "DELETE"
        case PUT                    = "PUT"
    }
    
    enum KeyResult : String {
        case CODE_RESPONSE          = "status code"
        case CONNECTION_ERROR       = "errors"
        case RESPONSE               = "result response"
        case HRADER                 = "header response"
        case MIME_TYPE              = "myme type"
        case URL                    = "url"
    }
    
    // JSON KEY
    
    
    // API PARAMS
    let url                     : NSURL!
    var ouput                   : ResponseOutput = ResponseOutput.NSDictionary
    var agent                   : String?
    var parameter               : NSDictionary?
    
    var completionDownloading   : ((NSData?)-> Void)?
    
    override init (){ super.init() }
    init (urlConnection: String) {
        super.init()
        if Reachability.isConnectedToNetwork()
        { self.url = NSURL(string: urlConnection) }
    }
    
    func connected() -> Bool { return Reachability.isConnectedToNetwork() }
    
    func changeUserAgent(agent : String) -> Void { self.agent = agent }
    
    private func setNetworkActivityIndicatorVisible(visibility setVisible : Bool) -> Void {
        let newValue = OSAtomicAdd32((setVisible ? +1 : -1), &ActivityManager.NumberOfCallsToSetVisible)
        assert(newValue >= 0, "Network Activity Indicator was asked to hide more often than shown")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = setVisible
    }
    
    func addParameterWithKey(key: String, value: String) {
        var p : NSMutableDictionary?
        if parameter == nil { p = NSMutableDictionary() }
        else { p = NSMutableDictionary(dictionary: parameter!) }
        p?.setValue(value, forKey: key)
        parameter = p
    }
    
    
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
            //println(responseString)
            
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
        else
        {
            #if DEGUG_MODE_NETWORK
                println(errors!.localizedDescription)
            #endif
        }
        jsonReturn = jsonReturn == nil ? NSMutableDictionary() : jsonReturn
        self.setNetworkActivityIndicatorVisible(visibility: false)
        jsonReturn.setObject(mymetype != nil ? mymetype! : "", forKey: KeyResult.MIME_TYPE.rawValue)
        jsonReturn.setObject(urlResponse != nil ? urlResponse! : "", forKey: KeyResult.URL.rawValue)
        jsonReturn.setObject(String(statusCode), forKey: KeyResult.CODE_RESPONSE.rawValue)
        jsonReturn.setObject(errors == nil ? "" : errors!.localizedDescription , forKey: KeyResult.CONNECTION_ERROR.rawValue)
        #if DEGUG_MODE_NETWORK
            println(jsonReturn)
        #endif
        return jsonReturn
    }
    
    
    func launchRequestWithNSUrl(request : NSURLRequest,
        completion : ((NSDictionary?)-> Void)) -> Void {
            
            var data : NSData?
            var response : NSURLResponse?
            var errors : NSError?
            
            
            self.setNetworkActivityIndicatorVisible(visibility: true)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                
                data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &errors)
                
                if data != nil {
                    NSOperationQueue.mainQueue().addOperationWithBlock
                        { completion(self.getJsonResponse(data : data?, errors: errors?, response: response?)!) }
                }
                
            }
            
    }
    
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
            self.launchRequestWithNSUrl(request, completion: completion)
    }
    
    
    func launchRequestDownloadingWithNSUrl(request : NSURLRequest,
        completion : ((NSData?)-> Void)) -> Void {
            
            var data        : NSData?
            var response    : NSURLResponse?
            var errors      : NSError?
            
            self.completionDownloading = completion
            NSURLConnection(request: request, delegate: self, startImmediately: true)
    }
    
    
    func launchRequestDownloading(cache: Bool,
        timeout: NSTimeInterval ,
        method: MethodRequest,
        completion : ((NSData?)-> Void)) -> Void {
            
            
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
            self.completionDownloading = completion
            NSURLConnection(request: request, delegate: self, startImmediately: true)
    }
    

    internal func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        println("some error")
    }
    
    internal func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        println("response")
    }
    
    internal func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        println("some data")
        self.completionDownloading!(data)
    }
    
    internal func connection(connection: NSURLConnection, didSendBodyData bytesWritten: Int, totalBytesWritten: Int, totalBytesExpectedToWrite: Int) {
        println(bytesWritten)
        println(totalBytesWritten)
        println(totalBytesExpectedToWrite)
    }
    
}
