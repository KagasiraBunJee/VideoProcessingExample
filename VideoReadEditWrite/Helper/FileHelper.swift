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
    
    class func filtersPath() -> String {
        return documentDirectory() + "filters"
    }
    
    class func validateDirectory(path: String, createIfNotExists: Bool) -> Bool {
        var exists: Bool = false
        let path = URL(string: path)!.relativePath
        
        var isDir: ObjCBool = true
        exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        
        if createIfNotExists && !exists {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                exists = true
            } catch let error {
                debugPrint("create dir error: ", error)
            }
        }
        
        return exists
    }
    
    class func createFile(at path: String, content: Data?) -> Bool {
        try? FileManager.default.removeItem(atPath: path)
        return FileManager.default.createFile(atPath: path, contents: content, attributes: nil)
    }
}
