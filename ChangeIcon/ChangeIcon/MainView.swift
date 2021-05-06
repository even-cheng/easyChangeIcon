//
//  ViewController.swift
//  ChangeIcon
//
//  Created by 程旭文 on 2021/4/30.
//

import Cocoa

class MainView: NSView {

    @IBOutlet weak var statusField: NSTextField!
    @IBOutlet weak var resetButton: NSButton!
    @IBOutlet weak var replaceIconView: NSButton!
    @IBOutlet weak var sourceIconView: NSButton!
    @IBOutlet weak var changeImage: NSImageView!
    
    private var fileTypes: [String] = ["png","appiconset","xcassets"]
    private var fileTypeIsOk = false
    private var replaceIcon: NSImage?
    private var originalIcon: NSImage?
    private var iconsetPath: String?

    //MARK: Functions
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        if #available(OSX 10.13, *) {
            registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.URL])
        } else {
            // Fallback on earlier versions
        }
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if #available(OSX 10.13, *) {
            registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.URL])
        } else {
            // Fallback on earlier versions
        }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.wantsLayer = true
        self.layer!.backgroundColor = NSColor(red:0.3, green:0.3, blue:0.3, alpha:1.00).cgColor

        self.changeImage.wantsLayer = true
        self.changeImage.layer!.backgroundColor = NSColor(red:0.9, green:0.9, blue:0.9, alpha:1.00).cgColor
        self.changeImage.layer!.cornerRadius = 3;
        self.changeImage.layer!.masksToBounds = true
    }
    
    private func fileDropped(_ filename: String){
        let extensionPathUrl = URL(fileURLWithPath: filename)
        switch(extensionPathUrl.pathExtension.lowercased()){
        case "png":
            statusField.stringValue = "已选择替换文件";
            guard let replaceImage = NSImage(contentsOfFile: filename) else {
                statusField.stringValue = "替换文件不存在";
                return
            }
            replaceIcon = replaceImage
            replaceIconView.image = replaceImage
            break

        case "appiconset":
            iconsetPath = filename;
            statusField.stringValue = "已选择待替换文件";
            let originalImage = checkOriginalIcon(iconsetPath!);
            originalIcon = originalImage
            sourceIconView.image = originalImage
            break
            
        case "xcassets":
            iconsetPath = filename + "/AppIcon.appiconset"
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: iconsetPath!) else {
                statusField.stringValue = "未发现路径下的AppIcon.appiconset文件";
                return
            }
            statusField.stringValue = "已选择待替换文件";
            let originalImage = checkOriginalIcon(iconsetPath!)
            originalIcon = originalImage
            if (originalImage != nil) {
                sourceIconView.image = originalImage
            } else {
                sourceIconView.title = "未设置图标"
            }
            break

        default: break
        
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if checkExtension(sender) == true {
            self.fileTypeIsOk = true
            return .copy
        } else {
            self.fileTypeIsOk = false
            return NSDragOperation()
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if self.fileTypeIsOk {
            return .copy
        } else {
            return NSDragOperation()
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let board = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray {
            if let filePath = board[0] as? String {
                fileDropped(filePath)
                return true
            }
        }
        return false
    }
    
    private func checkOriginalIcon(_ iconsetPath: String) -> NSImage? {
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: iconsetPath) else {
            return nil
        }
        let files = try! fileManager.subpathsOfDirectory(atPath: iconsetPath)
        var jsonPath: String?
        for file in files {
            if file == "Contents.json" {
                jsonPath = iconsetPath + "/" + file
                break
            }
        }
        guard jsonPath != nil else {
            statusField.stringValue = "配置文件不存在";
            return nil
        }
        
        let jsonData = try! Data(contentsOf: URL(fileURLWithPath: jsonPath!))
        let jsonDic:[String:AnyObject] = try! JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as! [String : AnyObject]
        let icons = jsonDic["images"] as! [[String: String]]
        
        var maxSize: Float = 0
        var icon: NSImage?
        icons.forEach { (obj: [String : String]) in
            
            let scale_str = obj["scale"]
            let size_str = obj["size"]
            var fileName = obj["filename"]
            let scale = scale_str!.replacingOccurrences(of: "x", with: "")
            let size = size_str!.components(separatedBy: "x").first
            let iconWidth = Float(size!)! * Float(scale)!
            if fileName == nil {
                fileName = "icon" + size_str! + "@" + scale_str!
            }
            let savedPath = iconsetPath + "/" + fileName!
            if iconWidth > maxSize {
                maxSize = iconWidth
                icon = NSImage(contentsOfFile: savedPath)
            }
        }
        
        return icon
    }
    
    private func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        if let board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let path = board[0] as? String {
            let extensionPathUrl = URL(fileURLWithPath: path)
                return self.fileTypes.contains(extensionPathUrl.pathExtension.lowercased())
            }
        
        return false
    }
    
    
    @IBAction func startReplace(_ sender: Any) {
        if replaceIcon == nil {
            statusField.stringValue = "替换icon文件不存在";
            return
        }
        
        replace(icon: replaceIcon!, reset: false)
    }
    
    @IBAction func reset(_ sender: Any) {
        if originalIcon == nil {
            statusField.stringValue = "重置失败,原始文件不存在";
            return
        }
        
        replace(icon: originalIcon!, reset: true)
    }
    
    private func replace(icon: NSImage,reset: Bool) {
        
        if iconsetPath == nil {
            statusField.stringValue = "未发现原路径下的AppIcon.appiconset文件";
            return
        }
        
        statusField.stringValue = "开始替换";
        resetButton.isEnabled = false

        let fileManager = FileManager.default
        let files = try! fileManager.subpathsOfDirectory(atPath: iconsetPath!)
        var jsonPath: String?
        for file in files {
            if file == "Contents.json" {
                jsonPath = iconsetPath! + "/" + file
                break
            }
        }
        guard jsonPath != nil else {
            statusField.stringValue = "配置文件不存在";
            return
        }
        
        let jsonData = try! Data(contentsOf: URL(fileURLWithPath: jsonPath!))
        var jsonDic:[String:AnyObject] = try! JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as! [String : AnyObject]
        let icons = jsonDic["images"] as! [[String: String]]
        var newIcons:[[String : Any]] = []
        var maxSize: Float = 0
        
        for var iconDic in icons {
            
            let scale_str = iconDic["scale"]
            let size_str = iconDic["size"]
            var fileName = iconDic["filename"]
            let scale = scale_str!.replacingOccurrences(of: "x", with: "")
            let size = size_str!.components(separatedBy: "x").first
            let iconWidth = Float(size!)! * Float(scale)!
            if fileName == nil {
                fileName = "icon" + size_str! + "@" + scale_str! + ".png"
                iconDic["filename"] = fileName!
            }
            let savedPath = iconsetPath! + "/" + fileName!
            if iconWidth > maxSize {
                maxSize = iconWidth
                originalIcon = NSImage(contentsOfFile: savedPath)
            }
            let res = writeImage(icon, size:CGSize(width: CGFloat(iconWidth), height: CGFloat(iconWidth)), toPath: URL(fileURLWithPath: savedPath))
            if res {
                newIcons.append(iconDic)
            }
        }

        jsonDic["images"] = newIcons as AnyObject
        
        var error: NSError?
        let os = OutputStream(toFileAtPath: jsonPath!,
                              append: false)
        os?.open()
        JSONSerialization.writeJSONObject(jsonDic,
                                          to: os!,
                                          options: JSONSerialization.WritingOptions.prettyPrinted,
                                          error: &error)
        os?.close()
        
        if reset {
            
            if error != nil {
                statusField.stringValue = "恢复失败" + error!.userInfo.description;
            } else {
                statusField.stringValue = "恢复完成";
            }
        
        } else {
            
            if error != nil {
                statusField.stringValue = "替换失败" + error!.userInfo.description;
            } else {
                statusField.stringValue = "替换完成";
            }
        }
        
        resetButton.isEnabled = true
    }

    private func writeImage(_ image: NSImage, size:CGSize, toPath: URL) -> Bool{
        
        let rep = NSBitmapImageRep.init(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: NSColorSpaceName.calibratedRGB, bitmapFormat: NSBitmapImageRep.Format.alphaFirst, bytesPerRow: 0, bitsPerPixel: 0)
        rep?.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext.init(bitmapImageRep: rep!)
        image.draw(in: NSMakeRect(0, 0, size.width, size.height))
        NSGraphicsContext.restoreGraphicsState()
       
        let imageProps: NSDictionary = NSDictionary.init(dictionary: [NSBitmapImageRep.PropertyKey.compressionFactor:false])
        let imageData = rep!.representation(using: NSBitmapImageRep.FileType.png, properties: imageProps as! [NSBitmapImageRep.PropertyKey : Any])
        if (try? (imageData!.write(to: toPath), options: Data.WritingOptions.atomic)) != nil {
            return true
        }

        return false
    }
}

