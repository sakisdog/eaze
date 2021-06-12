//
//  TCPSerial.swift
//  Eaze
//
//  Created by sakis on 9/6/21.
//  Copyright © 2021 Hangar42. All rights reserved.
//

import Foundation
import UIKit

protocol TCPSerialDelegate: class {
    func tcpserialdatareceived(message: String)
    func tcpserialdatareceived(data: Data)
}

class TCPSerial: NSObject, StreamDelegate {
    weak var delegate: TCPSerialDelegate?

  var inputStream: InputStream!
  var outputStream: OutputStream!
  let maxReadLength = 4096
    var isConnected: Bool = false
    
    
    func setupNetworkCommunication() {

      var readStream: Unmanaged<CFReadStream>?
      var writeStream: Unmanaged<CFWriteStream>?

        //Stream.getStreamsToHost(withName: "192.168.1.8", port: 4279, inputStream: &inputStream, outputStream: &outputStream)
      CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,"192.168.1.1" as CFString,4279,&readStream,&writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        inputStream.delegate = self

        inputStream.schedule(in: .current, forMode: RunLoopMode.commonModes)
        outputStream.schedule(in: .current, forMode: RunLoopMode.commonModes)
        inputStream.open()
        outputStream.open()
        isConnected = true
        sendInitialMSPCodes()
    }
    
    func disconnect(){
        isConnected = false
        inputStream.close()
        outputStream.close()
    }
    func sendBytesToDevice(_ bytes: [UInt8]) {
        guard isConnected else { return }
        outputStream.write(UnsafePointer<UInt8>(bytes), maxLength: bytes.count)

        //let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        //connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeType)
    }
    
    private func readAvailableBytes(stream: InputStream) {
      //1
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)

      //2
      while stream.hasBytesAvailable {
        //3
        let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)

        //4
        if numberOfBytesRead < 0, let error = stream.streamError {
          print(error)
          break
        }
//        let stringbuffer = String(
//            bytesNoCopy: buffer,
//            length: numberOfBytesRead,
//            encoding: .utf8,
//            freeWhenDone: true)
        let databuffer : Data = Data(bytes:buffer,count: numberOfBytesRead)
        delegate?.tcpserialdatareceived(data: databuffer)
        //delegate?.tcpserialdatareceived(message: stringbuffer ?? "Nillllllll!!!")
      }
    }
    func sendInitialMSPCodes(){
        // send first MSP commands for the board info stuff
        msp.sendMSP([MSP_FC_VARIANT, MSP_FC_VERSION, MSP_BOARD_INFO, MSP_BUILD_INFO]) {
            log("Connected")
            log("Eaze v\(appVersion.stringValue), iOS \(UIDevice.current.systemVersion), Platform \(UIDevice.platform)")
            log("FC ID \(dataStorage.flightControllerIdentifier), v\(dataStorage.flightControllerVersion.stringValue), Build \(dataStorage.buildInfo)")
            log("FC API v\(dataStorage.apiVersion.stringValue), MSP v\(dataStorage.mspVersion)")
            log("Board ID \(dataStorage.boardIdentifier) v\(dataStorage.boardVersion)")
            
            // these only have to be sent once (boxnames is for the mode titles)
            msp.sendMSP([MSP_BOXNAMES, MSP_BOXIDS, MSP_STATUS])
            
            // the user will be happy to know
            MessageView.show("Connected")
            
            // proceed to tell the rest of the app about recent events
            notificationCenter.post(name: Notification.Name.Serial.didConnect, object: nil)
            
            // disable sleep
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        //print("Stream created")
        switch eventCode {
        case .hasBytesAvailable:
          //print("hasBytesAvailable received")
            readAvailableBytes(stream: aStream as! InputStream)
        case .endEncountered:
          print("endEncountered received")
        case .errorOccurred:
          print("error occurred")
        case .hasSpaceAvailable:
          print("has space available")
        default:
          print("some other event...")
        }
    }





}
