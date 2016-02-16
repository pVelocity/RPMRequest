//
//  RPMAPISession.swift
//  RPMRequest
//
//  Created by Kang Lu on 2016-01-22.
//  Copyright © 2016 Kang Lu. All rights reserved.
//

import Foundation

public enum PVRequestParam
{
    case Element(attr: String, value: String)
    indirect case NamedCollection(attr: String, params: [PVRequestParam])
    indirect case Collection(params: [PVRequestParam])
}

public enum PVRequest
{
    case Operation(String, PVRequestParam)
}

public class RPMAPISession
{
    var cookie: String?

    let hostURL: String
    
    let concurrentQueue : NSOperationQueue
    let urlSessionConfig : NSURLSessionConfiguration
    let urlSession : NSURLSession
    
    /// Must initialized with a valid host URL to the pVelocity engine
    ///
    public init(hostURL: String) {
        self.concurrentQueue = NSOperationQueue()
        self.concurrentQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount
        self.concurrentQueue.qualityOfService = NSQualityOfService.Background
        
        self.urlSessionConfig = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        self.urlSession = NSURLSession(configuration: self.urlSessionConfig, delegate: nil, delegateQueue: self.concurrentQueue)
        
        self.cookie = nil
        self.hostURL = hostURL + "/PE/RPM"
    }
    
    private func requestInXML (request request: PVRequest) -> String
    {
        
        let emitElem = {
            (attr: String, value: String) -> String in
            var collection = ""
            collection += "<\(attr)>"
            collection += value
            collection += "</\(attr)>"
            return collection
        }
        
        func expandParams (params params: PVRequestParam) -> String
        {
            let emitArray = {
                (elements: [PVRequestParam]) -> String in
                var collection = ""
                for elem in elements {
                    collection += expandParams(params: elem)
                }
                return collection
            }
            
            switch params
            {
            case .Element(let attr, let value):
                return emitElem(attr, value)
                
            case .Collection(let elements):
                return emitArray(elements)
                
            case.NamedCollection(let attr, let elements):
                return emitElem(attr, emitArray(elements))
            }
        }
        
        var xml: String = ""
        xml += "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xml += "<PVRequest xmlns=\"http://pvelocity.com/rpm/pvrequest\">"
        xml += "<Operation>"
        
        switch request
        {
        case .Operation(let name, let params):
            xml += emitElem("Name", name)
            xml += emitElem("Params", expandParams(params: params))
        }
        
        xml += "</Operation>"
        xml += "</PVRequest>"
        
        return (xml as NSString).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) as String!
    }
    
    private func createRequest(requestObj: PVRequest) -> NSURLRequest
    {
        let url = NSURL(string: self.hostURL)
        let request = NSMutableURLRequest(URL: url!)
        
        let requestData = NSString(format: "dataformat=json&request=%@", requestInXML(request: requestObj))
        
        // Sample post
        request.HTTPMethod = "POST"
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-type");
        request.addValue("3.4", forHTTPHeaderField: "X-PVClient-Version")
        request.addValue("iOS", forHTTPHeaderField: "X-PVClient-Platform")
        request.setValue(self.cookie ?? "", forHTTPHeaderField: "Cookie")
        
        request.HTTPBody = (requestData as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        request.setValue(NSString(format: "%lu", request.HTTPBody!.length) as String, forHTTPHeaderField: "Content-Length")
        request.HTTPShouldHandleCookies = false
        
        return request
    }
    
    public func sendRequest(pvRequestObj: PVRequest) -> NSURLSessionTask
    {
        let request = createRequest(pvRequestObj)
        let task = self.urlSession.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
            
            if let _ = error {
                // handle error
            }
            else
            {
                if let d = data {
                    do {
                        let obj = try NSJSONSerialization.JSONObjectWithData(d, options:NSJSONReadingOptions.AllowFragments)
                        self.cookie = (response as! NSHTTPURLResponse).allHeaderFields["Set-Cookie"] as? String
                        print(obj)
                        print(self.cookie)
                    }
                    catch let error as NSError {
                        print(error.localizedDescription)
                        print("original content:\n\(String(data: d, encoding: NSUTF8StringEncoding)!)")
                    }
                }
            }
        })
        
        task.resume()
        
        return task
    }
    
    public func login(user user: String, passwd: String) -> NSURLSessionTask
    {
        
        let loginReq =  PVRequest.Operation("Login",
            PVRequestParam.Collection(
                params: [
                    PVRequestParam.Element(attr: "User", value: user),
                    PVRequestParam.Element(attr: "Password", value: passwd)
                ]
            ))
        
        return rpm.sendRequest(loginReq)
    }
    
    public func awaitCompletion() -> Void
    {
        NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 2.0))
        
        print("waiting for queue to empty...")
        concurrentQueue.waitUntilAllOperationsAreFinished()
        
        print("sleeping again...")
    }
    
}