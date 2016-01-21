//
//  main.swift
//  test
//
//  Created by Kang Lu on 2016-01-20.
//  Copyright © 2016 Kang Lu. All rights reserved.
//

import Foundation

let numArgs = Process.arguments.count
let progname = NSURL.fileURLWithPath(Process.arguments[0]).lastPathComponent

var done = false

func createRequest(urlString: String) -> NSURLRequest
{
    let url = NSURL(string: urlString)
    let request = NSMutableURLRequest(URL: url!)
    
    let requestOp = [
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>",
        "<PVRequest xmlns=\"http://pvelocity.com/rpm/pvrequest\">",
        "<Operation>",
        "<Name>Login</Name>",
        "<Params>",
        "<User>Admin</User>",
        "<Password>psa</Password>",
        "</Params>",
        "</Operation>",
        "</PVRequest>"
    ]
    
    let requestData = NSString(format: "dataformat=json&request=%@", (requestOp.joinWithSeparator("") as NSString).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)
    
    // Sample post
    request.HTTPMethod = "POST"
    request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-type");
    request.addValue("3.4", forHTTPHeaderField: "X-PVClient-Version")
    request.addValue("iOS", forHTTPHeaderField: "X-PVClient-Platform")
    request.setValue("", forHTTPHeaderField: "Cookie")
    
    request.HTTPBody = (requestData as NSString).dataUsingEncoding(NSUTF8StringEncoding)
    request.setValue(NSString(format: "%lu", request.HTTPBody!.length) as String, forHTTPHeaderField: "Content-Length")
    request.HTTPShouldHandleCookies = false
    
    return request
}

func sendRequest(urlString: String) -> NSURLSessionTask
{
    let sampleConfig = NSURLSessionConfiguration.ephemeralSessionConfiguration()
    let sampleSession = NSURLSession(configuration: sampleConfig, delegate: nil, delegateQueue: NSOperationQueue.mainQueue())
    
    let request = createRequest(urlString)
    let task = sampleSession.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
        
        if let _ = error {
            // handle error
        }
        else
        {
            if let d = data {
                let obj = try! NSJSONSerialization.JSONObjectWithData(d, options:NSJSONReadingOptions.AllowFragments)
                print(obj)
            }
        }
        
        done = true
        
    })
    
    task.resume()
    
    return task
}

if numArgs != 4
{
    print ("Usage \(progname!): filename")
    
    let task = sendRequest("http://goliath.pvelocity.com/PE/RPM")
    
    while(!done) {
        NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.01))
    }
}
else
{
    let filename = Process.arguments[1]
    let fileManager = NSFileManager.defaultManager()
    
    let curPath = NSURL.fileURLWithPath(fileManager.currentDirectoryPath)
    let filePath = curPath.URLByAppendingPathComponent(filename)
}
