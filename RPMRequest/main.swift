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

if numArgs != 4
{
    print ("Usage \(progname!): filename")
    
    let loginReq =  PVRequest.Operation("Login",
        PVRequestParam.Collection(
            params: [
                PVRequestParam.Element(attr: "User", value: "Admin"),
                PVRequestParam.Element(attr: "Password", value: "psa")
            ]
        ))
    
    let rpm = RPMAPISession(hostURL: "http://goliath.pvelocity.com")
    
    for i in 0..<1
    {
        let task = rpm.sendRequest(loginReq)
    }
    
    rpm.awaitCompletion()
}
else
{
    let filename = Process.arguments[1]
    let fileManager = NSFileManager.defaultManager()
    
    let curPath = NSURL.fileURLWithPath(fileManager.currentDirectoryPath)
    let filePath = curPath.URLByAppendingPathComponent(filename)
}
