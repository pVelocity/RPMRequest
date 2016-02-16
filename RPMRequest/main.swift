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
let engineURL = "http://goliath.pvelocity.com"

let rpm = RPMAPISession(hostURL: engineURL)

public class Main {

    private(set) lazy var user: String = {return Process.arguments[1]}()
    private(set) lazy var passwd: String = {return Process.arguments[2]}()
    private(set) lazy var filename: String = {return Process.arguments[3]}()
    
    public static func run() {
        
        let mainInst = Main();
        
        switch numArgs {
            
        case 3:
            
            rpm.login(user: mainInst.user, passwd: mainInst.passwd)
            rpm.awaitCompletion()

            
        case 4:

            rpm.login(user: mainInst.user, passwd: mainInst.passwd)
            
            let curPath = NSURL.fileURLWithPath(mainInst.filename)
            
            print ("Uploading file: \(curPath)")
            
            rpm.awaitCompletion()

            
        default:
            
            print ("Usage \(progname!): user password [filename]")
            
        }
        
    }
}


Main.run()