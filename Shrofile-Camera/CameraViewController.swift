//
//  CameraViewController.swift
//  Shrofile-Camera
//
//  Created by Arjun Kodur on 11/7/16.
//  Copyright © 2016 Arjun Kodur. All rights reserved.
//

import UIKit
import AVFoundation
import AWSS3
import AWSCore
import Photos
import AVKit


class CameraViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var recordButton: UIButton!
    
    @IBOutlet weak var recordingUploadingLabel: UILabel!
    
    var videoPreviewLayer = AVCaptureVideoPreviewLayer()
    var input: AVCaptureDeviceInput?
    var captureSession = AVCaptureSession()
    var sessionOutput = AVCaptureStillImageOutput()
    var movieOutput = AVCaptureMovieFileOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    var assetWriterInputAudio: AVAssetWriterInput?
    var assetWriterInputCamera: AVAssetWriterInput?
    
    var videoPlayerViewController = AVPlayerViewController()
    var playerView = AVPlayer()
    
    let bufferAudioQueue = DispatchQueue(label: "AudioQueue")
    let bufferVideoQueue = DispatchQueue(label: "VideoQueue")
    
    var username: String?
    var s3Url: URL?
    var fileUrl: URL?
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Get the device (Front or Back)
    func getDevice(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let devices: NSArray = AVCaptureDevice.devices() as NSArray
        for de in devices {
            let deviceConverted = de as! AVCaptureDevice
            if(deviceConverted.position == position){
                return deviceConverted
            }
        }
        return nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
        self.cameraView.layer.cornerRadius = 15.0
        self.recordButton.layer.cornerRadius = 5.0
        self.recordButton.setTitle("Record", for: .normal)
        self.recordingUploadingLabel.text = ""

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileUrl = documentsURL.appendingPathComponent("\(username).mov")
        
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        //Accessing front camera
        let frontCamera = getDevice(position: .front)
        
            do {
                self.input = try AVCaptureDeviceInput(device: frontCamera)
                
            } catch {
                print("Failed to setup input")
            }
        
        if(captureSession.canAddInput(input) == true){
            captureSession.addInput(input)
            
            let audioInputDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioInputDevice)
                
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                } else {
                    print("ERROR: Can't add audio input")
                }
            } catch let error {
                print("ERROR: Getting input device: \(error)")
            }
            
            sessionOutput.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
            if(captureSession.canAddOutput(sessionOutput) == true){
                captureSession.addOutput(sessionOutput)
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                videoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                cameraView.layer.addSublayer(videoPreviewLayer)
                videoPreviewLayer.frame = cameraView.bounds
                
                let assetWriter = try? AVAssetWriter(outputURL: fileUrl!, fileType: AVFileTypeMPEG4)
                
                guard let writer = assetWriter else {
                    return
                }
                
                let videoSettings = [
                    AVVideoCodecKey  : AVVideoCodecH264,
                    AVVideoWidthKey  : cameraView.frame.size.width,
                    AVVideoHeightKey : cameraView.frame.size.height,
                    AVVideoCompressionPropertiesKey : [
                        AVVideoAverageBitRateKey : 200000,
                        AVVideoProfileLevelKey : AVVideoProfileLevelH264Baseline41,
                        AVVideoMaxKeyFrameIntervalKey : 90,
                    ],
                    ] as [String : Any]
                
                assetWriterInputCamera = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
                assetWriterInputCamera!.expectsMediaDataInRealTime = true
                writer.add(assetWriterInputCamera!)
                
                let audioSettings = [
                    AVFormatIDKey : NSInteger(kAudioFormatMPEG4AAC),
                    AVNumberOfChannelsKey : 2,
                    AVSampleRateKey : NSNumber(value: 44100.0)
                ] as [String : Any]
                
                assetWriterInputAudio = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioSettings)
                assetWriterInputAudio!.expectsMediaDataInRealTime = true
                writer.add(assetWriterInputAudio!)
                
                
                bufferAudioQueue.sync {
                    audioOutput.setSampleBufferDelegate(self, queue: bufferAudioQueue)
                }
                captureSession.addOutput(audioOutput)
                
                
                bufferVideoQueue.sync {
                    videoOutput.setSampleBufferDelegate(self, queue: bufferVideoQueue)
                }
                captureSession.addOutput(videoOutput)

                captureSession.addOutput(movieOutput)
                captureSession.startRunning()
            }
            
        }
        
        
    }
    
    //Cropping and rendering the recorded video.
    func writeVideoToAssetsLibrary(videoUrl: URL) {
        
        let videoAsset = AVAsset(url: videoUrl)
        
        let clipVideoTrack = videoAsset.tracks(withMediaType: AVMediaTypeVideo).first! as AVAssetTrack
        
        let composition = AVMutableComposition()
        composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        
        let videoComposition = AVMutableVideoComposition()
        
        videoComposition.renderSize = CGSize(width: clipVideoTrack.naturalSize.height, height: clipVideoTrack.naturalSize.height)
        videoComposition.frameDuration = CMTimeMake(1, 30)
        
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(60, 30))
        
        let transform1: CGAffineTransform = CGAffineTransform(translationX: clipVideoTrack.naturalSize.height, y: -(clipVideoTrack.naturalSize.height/4))
        let transform2 = transform1.rotated(by: CGFloat(M_PI_2))
        let finalTransform = transform2
        
        
        transformer.setTransform(finalTransform, at: kCMTimeZero)
        
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileUrl = documentsURL.appendingPathComponent("\(username)cropped.mov")
        
        let exporter = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPresetHighestQuality)
        exporter!.videoComposition = videoComposition
        exporter!.outputURL = fileUrl
        exporter!.outputFileType = AVFileTypeQuickTimeMovie
        
        exporter!.exportAsynchronously(completionHandler: { () -> Void in
            DispatchQueue.main.async {
                self.handleExportCompletion(session: exporter!)
            }
        })
    }
    
    func handleExportCompletion(session: AVAssetExportSession) {
    
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum((session.outputURL?.path)!) {
            
            UISaveVideoAtPathToSavedPhotosAlbum((session.outputURL?.path
                )!, nil, nil, nil)
            
            uploadVideoToAWS(videoUrl: session.outputURL!)
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if recordButton.titleLabel?.text == "Record" {
            return
        }
        
        if let audio = self.assetWriterInputAudio, connection.audioChannels.count > 0 && audio.isReadyForMoreMediaData {
            
            bufferAudioQueue.async {
                audio.append(sampleBuffer)
            }
            return
        }
        
        if let camera = self.assetWriterInputCamera, camera.isReadyForMoreMediaData {
            bufferVideoQueue.async {
                camera.append(sampleBuffer)
            }
        }
    }


    @IBAction func recordButtontapped(_ sender: Any) {

        if recordButton.titleLabel?.text == "Record" {
            //Start Recording
            
            self.movieOutput.startRecording(toOutputFileURL: fileUrl as URL!, recordingDelegate: self)
           
            //Uploading is done
        }else if recordButton.titleLabel?.text == "Play video"{
            recordButton.setTitle("Record", for: .normal)
            playerView = AVPlayer(url: s3Url!)
            videoPlayerViewController.player = playerView
            self.present(videoPlayerViewController, animated: true){
                self.videoPlayerViewController.player?.play()
            }
            
        }
        else{
            
            //Perform Segue to preview VC
            self.recordingUploadingLabel.text = "Uploading..."
            self.recordButton.setTitle("", for: .normal)
            self.movieOutput.stopRecording()
            self.recordButton.isEnabled = false
            videoPreviewLayer.removeFromSuperlayer()
            
        }
        
    }
    
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        
        self.recordButton.setTitle("Stop", for: .normal)
        UIView.animate(withDuration: 1, delay: 0.5, options: [.repeat, .curveEaseOut, .autoreverse], animations: {
            self.recordingUploadingLabel.text = "Recording..."
        }, completion: nil)
        
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        
        
        if error == nil {
            
            //UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
            writeVideoToAssetsLibrary(videoUrl: outputFileURL)

        }
        
    }
    
    //Upload to AWS
    func uploadVideoToAWS(videoUrl: URL) {
        let myIdentityPoolId = "us-west-2:17e472e0-164d-4815-bba7-458a7a7cab87"
        
        let credentialsProvider:AWSCognitoCredentialsProvider = AWSCognitoCredentialsProvider(regionType:AWSRegionType.usWest2, identityPoolId: myIdentityPoolId)
        
        let configuration = AWSServiceConfiguration(region:AWSRegionType.usEast1, credentialsProvider:credentialsProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Set up AWS Transfer Manager Request
        let S3BucketName = "shrofilecamera"
        
        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest!.body = videoUrl
        uploadRequest!.key = username
        uploadRequest!.bucket = S3BucketName
        uploadRequest!.contentType = "video/quicktime"

        
        let transferManager = AWSS3TransferManager.default()
        transferManager?.upload(uploadRequest).continue({ (task) -> Any? in
            
            if let error = task.error{
                print("Upload failed with error:(\(error.localizedDescription))")
            }
            
            if let exception = task.exception{
                print("Upload failed with exception:\(exception)")
            }
            
            if task.result != nil{
                
                self.s3Url = NSURL(string: "https://s3.amazonaws.com/\(S3BucketName)/\(uploadRequest!.key!)")! as URL
                
                //AWS URL
                print("Uploaded to:\n\(self.s3Url!)")
                
                DispatchQueue.main.async {
                    self.recordingUploadingLabel.text = ""
                    self.recordButton.setTitle("Play video", for: .normal)
                    self.recordButton.isEnabled = true
                }
            }
            
            return nil
        })
    }


}
