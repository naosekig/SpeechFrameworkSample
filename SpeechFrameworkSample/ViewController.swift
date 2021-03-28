//
//  ViewController.swift
//  SpeechFrameworkSample
//
//  Created by NAOAKI SEKIGUCHI on 2021/03/28.
//

import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController {
    private let textView: UITextView = UITextView()
    private let startButton: UIButton = UIButton()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var avAudioFile: AVAudioFile!
    private var speechText: String = ""
    private var croppedFileInfos: [FileInfo] = []
    private var croppedFileCount: Int = 0
    private var currentIndex: Int = 0
    
    private struct FileInfo {
        var url: URL
        var startTime: Double
        var endTime: Double
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.backgroundColor = UIColor.white
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.black.cgColor
        self.view.addSubview(textView)
        
        startButton.setTitle("Start", for: .normal)
        startButton.setTitleColor(UIColor.black, for: .normal)
        startButton.addTarget(self, action: #selector(self.touchUpStartButton), for: .touchUpInside)
        self.view.addSubview(startButton)
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let width: CGFloat = self.view.frame.width
        let height: CGFloat = self.view.frame.height
        
        textView.frame = CGRect(x: 10, y: 80, width: width - 20, height: height - 200)
        startButton.frame = CGRect(x: width / 2 - 40, y: height - 100, width: 80, height: 80)
    }
    
    @objc private func touchUpStartButton() {
        textView.text = ""
        cropFile()
    }
    
    private func cropFile() {
        if let audioPath = Bundle.main.path(forResource:"sample" , ofType:"m4a") {
            let audioFileUrl = URL(fileURLWithPath : audioPath)
            do {
                self.avAudioFile = try AVAudioFile(forReading: audioFileUrl)
            }catch{
            }
            let recordTime = Double(self.avAudioFile.length) / self.avAudioFile.fileFormat.sampleRate
            let oneFileTime: Double = 60
            var startTime: Double = 0
            
            while startTime < recordTime {
                let fullPath = NSHomeDirectory() + "/Library/croppedFile_" + String(self.croppedFileInfos.count) + ".m4a"
                if FileManager.default.fileExists(atPath: fullPath) {
                    do {
                        try FileManager.default.removeItem(atPath: fullPath)
                    }catch let error {
                        print(error)
                    }
                }
                let url = URL(fileURLWithPath: fullPath)
                let endTime: Double = startTime + oneFileTime <= recordTime ? startTime + oneFileTime : recordTime
                self.croppedFileInfos.append(FileInfo(url: url, startTime: startTime, endTime: endTime))
                startTime += oneFileTime
            }
            
            for cropeedFileInfo in self.croppedFileInfos {
                self.exportAsynchronously(fileInfo: cropeedFileInfo)
            }
        }
    }

    private func exportAsynchronously(fileInfo: FileInfo) {
        let startCMTime = CMTimeMake(value: Int64(fileInfo.startTime), timescale: 1)
        let endCMTime = CMTimeMake(value: Int64(fileInfo.endTime), timescale: 1)
        let exportTimeRange = CMTimeRangeFromTimeToTime(start: startCMTime, end: endCMTime)
        let asset = AVAsset(url: self.avAudioFile.url)
        if let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) {
            exporter.outputFileType = .m4a
            exporter.timeRange = exportTimeRange
            exporter.outputURL = fileInfo.url
            exporter.exportAsynchronously(completionHandler: {
                    switch exporter.status {
                    case .completed:
                        self.croppedFileCount += 1
                        if self.croppedFileInfos.count == self.croppedFileCount {
                            DispatchQueue.main.async {
                                self.initalizeSpeechFramework()
                            }
                        }
                    case .failed, .cancelled:
                        if let error = exporter.error {
                            print(error)
                        }
                    default:
                        break
                    }
            })
        }
    }
    
    private func initalizeSpeechFramework() {
        self.recognitionRequest = SFSpeechURLRecognitionRequest(url: self.croppedFileInfos[self.currentIndex].url)
        let location = NSLocale.preferredLanguages
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: location[0]))!
        self.recognitionTask = self.speechRecognizer?.recognitionTask(with: self.recognitionRequest!, resultHandler: { (result: SFSpeechRecognitionResult?, error: Error?) -> Void in
            if let error = error {
                print(error)
            } else {
                if let result = result {
                    self.textView.text = self.speechText + result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finishOrRestartSpeechFramework()
                    }
                }
            }
        })
    }
    
    private func finishOrRestartSpeechFramework() {
        self.recognitionTask?.cancel()
        self.recognitionTask?.finish()
        self.speechText = self.textView.text
        self.currentIndex += 1
        if self.currentIndex < self.croppedFileInfos.count {
            self.initalizeSpeechFramework()
        }
    }
}

