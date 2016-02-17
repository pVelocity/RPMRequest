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
    case Empty
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
    var sessionId: String?
    
    var done: Bool = false

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
                
            case.Empty:
                return ""
            }
        }
        
        var xml: String = ""
        xml += "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xml += "<PVRequest xmlns=\"http://pvelocity.com/rpm/pvrequest\""
        if let curSess = self.sessionId {
            xml += " sessionId=\"\(curSess)\""
        }
        xml += ">"
        xml += "<Operation>"
        
        switch request
        {
        case .Operation(let name, let params):
            xml += emitElem("Name", name)
            switch params
            {
            case .Empty:
                break
            default:
                xml += emitElem("Params", expandParams(params: params))
            }
        }
        
        xml += "</Operation>"
        xml += "</PVRequest>"
        
        return (xml as NSString).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) as String!
    }
    
    private func setHeadersForRequest(request: NSMutableURLRequest, contentType: String, requestData: NSData?)
    {
        // Sample post
        request.HTTPMethod = "POST"
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.addValue("3.4", forHTTPHeaderField: "X-PVClient-Version")
        request.addValue("iOS", forHTTPHeaderField: "X-PVClient-Platform")
        request.setValue(self.cookie ?? "", forHTTPHeaderField: "Cookie")
        request.setValue(contentType, forHTTPHeaderField:"Content-type");
        
        request.HTTPBody = requestData
        request.setValue(NSString(format: "%lu", request.HTTPBody!.length) as String, forHTTPHeaderField: "Content-Length")
        request.HTTPShouldHandleCookies = false

    }
    
    private func createRequest(requestObj: PVRequest) -> NSURLRequest
    {
        let url = NSURL(string: self.hostURL)
        let request = NSMutableURLRequest(URL: url!)
        
        let requestData = NSString(format: "dataformat=json&request=%@", requestInXML(request: requestObj))

        self.setHeadersForRequest(request,
            contentType: "application/x-www-form-urlencoded",
            requestData: (requestData as NSString).dataUsingEncoding(NSUTF8StringEncoding))
        
        return request
    }
    
    public func createUploadFileRequest(filePath filePath: String, persistent: Bool = false) -> NSURLRequest?
    {
        var request: NSMutableURLRequest? = nil
        
        if let sessionId = self.sessionId
        {
            let url = NSURL(string: self.hostURL)
            request = NSMutableURLRequest(URL: url!)
            
            let curDate = NSDate()
            let epochTime = curDate.timeIntervalSince1970
            let boundaryDigest = "\(filePath)\(epochTime)".hmac(CryptoAlgorithm.SHA1, key: "\(epochTime)")
            let boundary = "------RPMAPISession\(boundaryDigest)"
            let contentType = "multipart/form-data; boundary=\(boundary)"
            
            let postbody = NSMutableData()
            
            let addField = {
                (field: String, value: String) -> Void in
                
                postbody.appendData("--\(boundary)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
                postbody.appendData("Content-Disposition: form-data; name=\"\(field)\"\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!);
                postbody.appendData(value.dataUsingEncoding(NSUTF8StringEncoding)!)
                postbody.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            }
            
            let addFile = {
                (field: String, filename: String) -> Void in
                
                postbody.appendData("--\(boundary)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
                postbody.appendData("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!);
                postbody.appendData("Content-Type: application/octet-stream\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
                
                postbody.appendData(NSData(contentsOfFile: filePath)!)
                
                postbody.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            }
            
            addField("SessionId", sessionId)
            addField("Operation", "UploadFile")
            addField("dataformat", "json")
            addField("Persistent", persistent ? "true" : "false")
            addFile("file", filePath)
            
            // Ending the multipart
            postbody.appendData("\r\n--\(boundary)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!);
            
            self.setHeadersForRequest(request!,
                contentType: contentType,
                requestData: postbody)
            
        }
        
        return request
    }
    
    private func statusInResponse(pvResponseJSON: AnyObject) -> AnyObject?
    {
        var status: AnyObject? = nil
        if let resp = pvResponseJSON["PVResponse"] {
            status = resp!["PVStatus"]
        }
        return status
    }
    
    private func codeInResponse(pvResponseJSON: AnyObject) -> String?
    {
        var codeStr: String? = nil
        if let status = self.statusInResponse(pvResponseJSON) {
            if let code = status["Code"] {
                codeStr = code!["text"] as? String
            }
        }
        return codeStr
    }

    private func sessionIdInResponse(pvResponseJSON: AnyObject) -> String?
    {
        var str: String? = nil
        if let status = self.statusInResponse(pvResponseJSON) {
            if let code = status["SessionId"] {
                str = code!["text"] as? String
            }
        }
        return str
    }
    
    private func isResponseOK(pvResponseJSON: AnyObject) -> Bool
    {
        var result: Bool! = false
        
        if let code = codeInResponse(pvResponseJSON) {
            if code.isEqual("RPM_PE_STATUS_OK") {
                result = true;
            }
        }
        return result
    }
    
    public func sendRequest(request: NSURLRequest, successHandler: ((jsonObj: AnyObject?) -> Void)? = nil, failHandler: ((error: NSError, responseStr: String?) -> Void)? = nil) -> NSURLSessionTask
    {
        self.done = false
        
        let task = self.urlSession.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
            
            if let _ = error {
                // handle error
            }
            else
            {
                if let d = data {
                    do {
                        let obj = try NSJSONSerialization.JSONObjectWithData(d, options:NSJSONReadingOptions.AllowFragments)
                        if self.isResponseOK(obj)
                        {
                            if let curCookie = (response as! NSHTTPURLResponse).allHeaderFields["Set-Cookie"] as? String
                            {
                                self.cookie = curCookie
                            }
                            self.sessionId = self.sessionIdInResponse(obj)
                            
                            if let success = successHandler {
                                success(jsonObj: obj);
                            }
                        }
                        else {
                            throw NSError(domain: "com.pvelocity.rpm", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Status is not okay."])
                        }
                    }
                    catch let error as NSError {
                        
                        let origContent = String(data: d, encoding: NSUTF8StringEncoding)
                        if let fail = failHandler {
                            fail(error: error, responseStr: origContent)
                        }
                        else {
                            print(error.localizedDescription)
                            print("original content:\n\(origContent!)")
                        }
                    }
                }
            }
        })
        
        task.resume()
        
        return task
    }
    
    public func login(user user: String, passwd: String, handler: ((success: Bool, jsonObject: AnyObject?) -> Void)? = nil) -> NSURLSessionTask
    {
        
        let loginReq =  PVRequest.Operation("Login",
            PVRequestParam.Collection(
                params: [
                    PVRequestParam.Element(attr: "User", value: user),
                    PVRequestParam.Element(attr: "Password", value: passwd)
                ]
            ))
        
        return self.sendRequest(self.createRequest(loginReq),
            successHandler: {
                (jsonObject) -> Void in
                
                if let complete = handler {
                    complete(success: true, jsonObject: jsonObject)
                }
                else {
                    print("login successful with: cookie[\(self.cookie)] and sessionId[\(self.sessionId)]")
                }
            },
            failHandler:  {
                (error, response) -> Void in
                
                if let complete = handler {
                    complete(success: false, jsonObject: nil)
                }
                else {
                    print("Logout failed")
                    print("original response: \(response)")
                }
            }
        )
    }
    
    public func logout() -> NSURLSessionTask
    {
        let logoutReq = PVRequest.Operation("Logout", PVRequestParam.Empty)
        let task = self.sendRequest(self.createRequest(logoutReq),
            successHandler: {(jsonObject) -> Void in
                self.sessionId = nil
                self.cookie = nil
                self.done = true
                print("logout successful.")
            },
            failHandler:  {(error, response) -> Void in
                print("Logout failed")
                print("original response: \(response)")
            })
        return task
    }
    
    public func awaitCompletion() -> Void
    {
        while (!self.done)
        {
            NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.25))
            concurrentQueue.waitUntilAllOperationsAreFinished()
        }
    }
    
}