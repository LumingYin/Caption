//
//  ViewController.swift
//  Caption
//
//  Created by Bright on 7/29/17.
//  Copyright © 2017 Bright. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate {

    @IBOutlet weak var resultTableView: NSTableView!
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var timeLabel: NSTextField!
    var player: AVPlayer?
    var videoURL: URL?
    @IBOutlet var transcribeTextView: NSTextView!
    
    var arrayForCaption: [CaptionLine] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        transcribeTextView.delegate = self
        transcribeTextView.isAutomaticSpellingCorrectionEnabled = false
        resultTableView.delegate = self
        resultTableView.dataSource = self
    }
    
    @IBAction func saveSRTToDisk(_ sender: Any) {
        saveSRT()
    }
    
    func saveSRT() {
        let text = generateSRTFromArray()
        
        guard let origonalVideoName = self.videoURL?.lastPathComponent else {
            return
        }
        let ogVN = (origonalVideoName as NSString).deletingPathExtension
        let newSubtitleName = "\(ogVN).srt"
        
        guard let newPath = self.videoURL?.deletingLastPathComponent().appendingPathComponent(newSubtitleName) else {
            return
        }
        
        do {
            try text.write(to: newPath, atomically: false, encoding: String.Encoding.utf8)
            _ = dialogOKCancel(question: "Saved successfully!", text: "Subtitle saved as \(newSubtitleName) under \(newPath.deletingLastPathComponent()).")
        }
        catch {
            _ = dialogOKCancel(question: "Saved failed!", text: "Save has failed.")
        }
    }
    
    func dialogOKCancel(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = NSAlertStyle.warning
        alert.addButton(withTitle: "OK")
//        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == NSAlertFirstButtonReturn
    }

    
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        
        // play 上一个结束了
        // pause 下一个开始？
        print("\(String(describing: replacementString))")
        
        if transcribeTextView.string == "" {
            player?.pause()
            if let last = arrayForCaption.last {
                last.endingTime = player?.currentTime()
            }
        } else {
            let breakDict = transcribeTextView.string?.components(separatedBy: "\n")
            if let lastLine = breakDict?.last {
                if lastLine == "" && replacementString != "" {
                    player?.pause()
                    if let last = arrayForCaption.last {
                        last.endingTime = player?.currentTime()
                    }
                }
            }
        }
        if (replacementString == "\n") {
            player?.play()
            if let last = arrayForCaption.last {
                let breakDict = transcribeTextView.string?.components(separatedBy: "\n")
                if let lastLine = breakDict?.last {
                    last.caption = lastLine
                }
            }

            let new = CaptionLine.init(caption: "", startingTime: player?.currentTime(), endingTime: nil)
            arrayForCaption.append(new)
            
            self.resultTableView.reloadData()
        }
        return true
    }
    
    
    
    func generateSRTFromArray() -> String {
        var srtString = ""
        for i in 0..<arrayForCaption.count {
            srtString = srtString + "\(i+1)\n\(arrayForCaption[i])\n\n"
        }
        print(srtString)
        return srtString
    }
    
    
    func textDidChange(_ notification: Notification) {
    }

    override var representedObject: Any? {
        didSet {
        }
    }

    @IBAction func openFile(_ sender: Any) {
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose a video file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = true;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = false;
        dialog.allowedFileTypes        = ["mov", "mp4", "m4v", "ts", "mpg", "mpeg", "hevc"];
        
        if (dialog.runModal() == NSModalResponseOK) {
            if let result = dialog.url {
                saveSRT()
                arrayForCaption = []
                playVideo(result)
            }
        } else {
            return
        }
    }

    func playVideo(_ videoURL: URL) {
        self.videoURL = videoURL
        player = AVPlayer(url: videoURL)
        playerView.player = player
        player?.play()
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { (timer) in
            let cap = CaptionLine(caption: "", startingTime: self.player?.currentTime(), endingTime: nil)
            self.arrayForCaption.append(cap)
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return arrayForCaption.count
    }
    

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.make(withIdentifier: "tableCell", owner: self) as? NSTableCellView
        let correspondingCaption = arrayForCaption[row]
        if tableColumn?.title == "Start Time" {
            cell?.textField?.stringValue = "\(correspondingCaption.startingTimeString)"
        } else if tableColumn?.title == "End Time" {
            cell?.textField?.stringValue = "\(correspondingCaption.endingTimeString)"
        } else {
            if let cap = correspondingCaption.caption {
                cell?.textField?.stringValue = cap
            } else {
                cell?.textField?.stringValue = ""
            }
        }
        return cell
    }
    
    @IBAction func queryTime(_ sender: Any) {
        let time = player?.currentTime().value
        let second = player?.currentTime().seconds
        let scale = player?.currentTime().timescale
        self.timeLabel.stringValue = "\(time ?? kCMTimeZero.value), \(second ?? 0.0), \(scale ?? CMTimeScale(kCMTimeMaxTimescale))"
    }
}

class CaptionLine: CustomStringConvertible {
    var caption: String?
    var startingTime: CMTime?
    var endingTime: CMTime?
    
    init(caption: String?, startingTime: CMTime?, endingTime: CMTime?) {
        self.caption = caption
        self.startingTime = startingTime
        self.endingTime = endingTime
    }
    
    var startingTimeString: String {
        guard let start = startingTime else {
            return ""
        }
        let st = CMTimeGetSeconds(start)
        return secondFloatToString(float: st)
    }
    
    var endingTimeString: String {
        guard let end = endingTime else {
            return ""
        }
        let en = CMTimeGetSeconds(end)
        return secondFloatToString(float: en)
    }
    
    
    var description: String {
        guard let cap = caption, let start = startingTime, let end = endingTime else {
            return ""
        }
        
        let st = CMTimeGetSeconds(start)
        let en = CMTimeGetSeconds(end)
        
        let stringStart = secondFloatToString(float: st)
        let stringEnd = secondFloatToString(float: en)
        
        return "\(stringStart) --> \(stringEnd)\n\(cap)"
    }
    
    func secondFloatToString(float: Float64) -> String {
        var second = float
        
        var hours: Int = 0
        var minutes: Int = 0
        var seconds: Int = 0
        var milliseconds: Int = 0
        
        hours = Int(second / Float64(3600))
        second = second - Float64(hours * 3600)
        
        minutes = Int(second / Float64(60))
        second = second - Float64(minutes * 60)
        
        seconds = Int(second)
        second = second - Float64(seconds)
        
        milliseconds = Int(second * 1000)
        
        let string = NSString(format:"%.2d:%.2d:%.2d,%.3d", hours, minutes, seconds, milliseconds)
        return string as String
    }
    
    
}

class CaptionWindowController: NSWindowController, NSWindowDelegate {
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.titleVisibility = .hidden
        self.window?.delegate = self
    }
    
}