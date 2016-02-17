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


public class Main {
    
    private(set) lazy var engineURL: String = {return Process.arguments[1]}()
    private(set) lazy var user: String = {return Process.arguments[2]}()
    private(set) lazy var passwd: String = {return Process.arguments[3]}()
    private(set) lazy var filename: String = {return Process.arguments[4]}()
    
    public static func run() {
        let mainInst = Main();

        let rpm = RPMAPISession(hostURL: mainInst.engineURL)
        
        switch numArgs {
            
        case 4:
            
            rpm.login(user: mainInst.user, passwd: mainInst.passwd,
                handler: {
                    (success, jsonObject) in
                    
                    if success {
                        print ("login successfully")
                        rpm.logout();
                    }
                }
            )
            rpm.awaitCompletion()
            
        case 5:

            rpm.login(user: mainInst.user, passwd: mainInst.passwd,
                handler: {
                    (success, jsonObject) in
                    
                    if success {

                        let request = rpm.createUploadFileRequest(filePath: mainInst.filename, persistent: true)
                        rpm.sendRequest(request!,
                            successHandler: {(jsonObject) -> Void in
                                print("file uploaded successfully: \(jsonObject)")
                                
                                rpm.logout()
                            },
                            failHandler:  {(error, response) -> Void in
                                print("Upload failed")
                                print("original response: \(response)")
                                
                                rpm.logout()
                        })

                    }
                    
            })
            rpm.awaitCompletion()
            
        default:
            
            print ("Usage \(progname!): host_url user password [filename]")
            
        }
        
    }
}


Main.run()