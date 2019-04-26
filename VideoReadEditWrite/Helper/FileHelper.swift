//
//  FileHelper.swift
//  VideoReadEditWrite
//
//  Created by Sergei on 4/24/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import UIKit

class FileHelper: NSObject {

    class func documentDirectory() -> String {
        if let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentUrl.absoluteString
        }
        return ""
    }
    
    class func newMediaFilePath(extension: String) -> String {
        let name = "output."+`extension`
        return documentDirectory() + name
    }
}
