
import SwiftUI



class I2CMasterController: I2CController {
    
    enum TransmissionControlState {
        case start_waitingBeforeReleasingSDA
        case start_releasingSDA
        case start_waitingBeforeReleasingSCL
        case start_releasingSCL
        case start_waitingBeforePullingSDA
        case start_pullingSDA
        case start_waitingAfterPullingSDA
        case bitSetup_waitingBeforePullingSCL
        case bitSetup_pullingSCL
        case bitSetup_waitingBeforeAssertingSDA
        case bitSetup_assertingSDA
        case bitSetup_waitingBeforeReleasingSCL
        case bitSetup_releasingSCL
        case bitClock_waitingBeforePullingSCL
        case bitClock_pullingSCL
        case bitClock_waitingAfterPullingSCL
        case stop_waitingBeforeReleasingSCL
        case stop_releasingSCL
        case stop_waitingBeforeReleasingSDA
        case stop_releasingSDA
        case stop_waitingAfterReleasingSDA
    }
    
    enum TransmissionState {
        case waitingStart
        case started
        case bitClockLow
        case bitClockHigh
    }
    
    enum TransmissionStep {
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
    }
    
    enum TransmissionResult {
        case success(readBytes: [Byte])
        case addressNack
        case error
    }
    
    var currentTransmissionControlState: TransmissionControlState = .start_waitingBeforeReleasingSDA
    var currentTransmissionState: TransmissionState = .waitingStart
    var currentTransmissionStep: TransmissionStep = .transmittingAddressByte
    var currentTransmissionResult: TransmissionResult?
    
    var currentLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)

    let xWaitBeforeStartSDARelease: CGFloat = 10
    let xWaitBeforeStartSCLRelease: CGFloat = 10
    let xWaitBeforeStartSDAPull: CGFloat = 10
    let xWaitAfterStartSDAPull: CGFloat = 10
    let xWaitBeforeBitSetupSCLPull: CGFloat = 10
    let xWaitBeforeBitSetupSDAAssert: CGFloat = 10
    let xWaitBeforeBitSetupSCLRelease: CGFloat = 10
    let xWaitBeforeBitClockSCLPull: CGFloat = 10
    let xWaitAfterBitClockSCLPull: CGFloat = 10
    let xWaitBeforeStopSCLRelease: CGFloat = 10
    let xWaitBeforeStopSDARelease: CGFloat = 10
    let xWaitAfterStopSDARelease: CGFloat = 100
    
    var nextStartSDAReleaseMinX: CGFloat = 0
    var nextStartSCLReleaseMinX: CGFloat = 0
    var nextStartSDAPullMinX: CGFloat = 0
    var nextStartEndMinX: CGFloat = 0
    var nextBitSetupSCLPullMinX: CGFloat = 0
    var nextBitSetupSDAAssertMinX: CGFloat = 0
    var nextBitSetupSCLReleaseMinX: CGFloat = 0
    var nextBitClockSCLPullMinX: CGFloat = 0
    var nextBitClockEndMinX: CGFloat = 0
    var nextStopSCLReleaseMinX: CGFloat = 0
    var nextStopSDAReleaseMinX: CGFloat = 0
    var nextStopEndMinX: CGFloat = 0
    
    var scheduledTransmissions: [(x: CGFloat, transmission: I2CTransmission)] = []
    var activeTransmission: I2CTransmission? = nil
    var addressAcked: Bool = false
    
    var sendingStop = false
    var holdingBus = false
    var writingBit = false
    var nextBitToWrite: Bit?
    
    var lastReadBit: Bit? = nil
    var lastReadByte: UInt8? = nil
    
    var readAddressByte: UInt8? = nil
    var readDataBytes: [UInt8] = []
    var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    let onReadSuccess: (([UInt8])->())?
    
    
    init(onReadSuccess: (([UInt8])->())?) {
        
        self.onReadSuccess = onReadSuccess
    }
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append((x: x, transmission: transmission))
    }
    
    
    override func initState(x: CGFloat) {
    
    }
    
    
    override func updateBusControl(x: CGFloat) {

        if activeTransmission == nil {
            
            if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first, entry.x <= x {
                
                scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
                activeTransmission = entry.transmission
                
                resetTransmissionState(x: x)
            }
        }
        
        if activeTransmission != nil {
            
            updateTransmissionDriveState(afterTimeChanged: x)
            
            let previousLineLevels = currentLineLevels
            currentLineLevels = bus.currentLineLevels
            
            if currentLineLevels.SCL != previousLineLevels.SCL {
                updateTransmissionDriveState(afterLineChanged: .SCL, at: x)
                updateTransmissionState(afterLineChanged: .SCL)
            }
            if currentLineLevels.SDA != previousLineLevels.SDA {
                updateTransmissionDriveState(afterLineChanged: .SDA, at: x)
                updateTransmissionState(afterLineChanged: .SDA)
            }
            
            if currentTransmissionState == .bitClockHigh {
                lastReadBit = currentLineLevels.SDA.bit
            }
        
            stabilizeTransmissionDriveState(x: x)
            updateControls()
        }
    }
    
    
    func onReadAddressByte(byte: Byte) {
    }
    
    
    func onReadAddressAck(ack: Ack) {
        switch ack {
        case .ack:
            addressAcked = true
        case .nack:
            sendingStop = true
        }
    }
    
    
    func onReadDataByte(byte: Byte) {
    }
    
    
    func onReadDataAck(ack: Ack) {
        if ack == .nack {
            sendingStop = true
        }
    }
    
    
    func onReadBit(bit: Bit) {
        prepareNextBit()
        if nextBitToWrite == nil {
            sendingStop = true
        }
    }
    
    
    func onDone(readBytes: [Byte]) {
        let readSuccess = self.activeTransmission!.mode == .read && addressAcked
        clearActiveTransmission()
        if readSuccess {
            onReadSuccess?(readBytes)
        }
    }
    

    func onAborted() {
        clearActiveTransmission()
    }
    
    
    func clearActiveTransmission() {
        
        self.activeTransmission = nil
    }
    
    
    func resetTransmissionState(x: CGFloat) {
        
        initTransmissionDriveState()
        
        currentTransmissionStep = .transmittingAddressByte
        currentTransmissionResult = nil
        
        sendingStop = false
        holdingBus = false
        
        nextStartSDAReleaseMinX = x + xWaitBeforeStartSDARelease
        nextStartSCLReleaseMinX = x + xWaitBeforeStartSCLRelease
        nextStartSDAPullMinX = x + xWaitBeforeStartSDAPull
        
        prepareNextBit()
    }
    
    
    func transmissionError() {
        
        clearActiveTransmission()
    }
    
    
    func initTransmissionDriveState() {
        
        switch bus.currentLineLevels {
        case (SCL: .high, SDA: .high):
            currentTransmissionControlState = .start_waitingBeforePullingSDA
        case (SCL: .high, SDA: .low):
            currentTransmissionControlState = .start_waitingBeforeReleasingSDA
        case (SCL: .low, SDA: .high):
            currentTransmissionControlState = .start_waitingBeforeReleasingSCL
        case (SCL: .low, SDA: .low):
            currentTransmissionControlState = .start_waitingBeforeReleasingSDA
        }
    }
    
    
    func updateTransmissionDriveState(afterTimeChanged x: CGFloat) {
        
        switch currentTransmissionControlState {
            
        case .start_waitingBeforeReleasingSDA:
            
            if x >= nextStartSDAReleaseMinX {
                currentTransmissionControlState = .start_releasingSDA
            }
            
        case .start_releasingSDA:
            break
            
        case .start_waitingBeforeReleasingSCL:
            
            if x >= nextStartSCLReleaseMinX {
                currentTransmissionControlState = .start_releasingSCL
            }
            
        case .start_releasingSCL:
            break
            
        case .start_waitingBeforePullingSDA:
            
            if x >= nextStartSDAPullMinX {
                currentTransmissionControlState = .start_pullingSDA
            }
            
        case .start_pullingSDA:
            break
            
        case .start_waitingAfterPullingSDA:
            
            if x >= nextStartEndMinX {
                currentTransmissionControlState = .bitSetup_waitingBeforePullingSCL
            }
            
        case .bitSetup_waitingBeforePullingSCL:
            
            if x >= nextBitSetupSCLPullMinX {
                currentTransmissionControlState = .bitSetup_pullingSCL
            }
            
        case .bitSetup_pullingSCL:
            break
            
        case .bitSetup_waitingBeforeAssertingSDA:
            
            if x >= nextBitSetupSDAAssertMinX {
                currentTransmissionControlState = .bitSetup_assertingSDA
            }
            
        case .bitSetup_assertingSDA:
            break
            
        case .bitSetup_waitingBeforeReleasingSCL:
            
            if x >= nextBitSetupSCLReleaseMinX {
                currentTransmissionControlState = .bitSetup_releasingSCL
            }
            
        case .bitSetup_releasingSCL:
            break
            
        case .bitClock_waitingBeforePullingSCL:
            
            if x >= nextBitClockSCLPullMinX {
                currentTransmissionControlState = .bitClock_pullingSCL
            }
            
        case .bitClock_pullingSCL:
            break
            
        case .bitClock_waitingAfterPullingSCL:
            
            if x >= nextBitClockEndMinX {
                currentTransmissionControlState = .bitSetup_waitingBeforeAssertingSDA
                if writingBit
            }
            
        case .stop_waitingBeforeReleasingSCL:
            
            if x >= nextStopSCLReleaseMinX {
                currentTransmissionControlState = .stop_releasingSCL
            }
            
        case .stop_releasingSCL:
            break
            
        case .stop_waitingBeforeReleasingSDA:
            
            if x >= nextStopSDAReleaseMinX {
                currentTransmissionControlState = .stop_releasingSDA
            }
            
        case .stop_releasingSDA:
            break
            
        case .stop_waitingAfterReleasingSDA:
            
            if x >= nextStopEndMinX {
                initTransmissionDriveState()
            }
        }
    }
    
    
    func updateTransmissionDriveState(afterLineChanged changedLine: I2CBusLine.Identity, at x: CGFloat) {
        
        switch currentTransmissionControlState {
        
        case .start_waitingBeforeReleasingSDA:
            transmissionError()
            
        case .start_releasingSDA:
            
            if changedLine == .SDA {
                currentTransmissionControlState = .start_waitingBeforeReleasingSCL
                nextStartSCLReleaseMinX = x + xWaitBeforeStartSCLRelease
            } else {
                transmissionError()
            }
        
        case .start_waitingBeforeReleasingSCL:
            transmissionError()
            
        case .start_releasingSCL:
            
            if changedLine == .SCL {
                currentTransmissionControlState = .start_waitingBeforePullingSDA
                nextStartSDAPullMinX = x + xWaitBeforeStartSDAPull
            } else {
                transmissionError()
            }
            
        case .start_waitingBeforePullingSDA:
            transmissionError()
            
        case .start_pullingSDA:
            
            if changedLine == .SDA {
                currentTransmissionControlState = .start_waitingAfterPullingSDA
                nextStartEndMinX = x + xWaitAfterStartSDAPull
                nextBitSetupSCLPullMinX = x + xWaitBeforeBitSetupSCLPull
            } else {
                transmissionError()
            }
            
        case .start_waitingAfterPullingSDA:
            transmissionError()
            
        case .bitSetup_waitingBeforePullingSCL:
            transmissionError()
            
        case .bitSetup_pullingSCL:
            
            if changedLine == .SCL {
                if writingBit {
                    currentTransmissionControlState = .bitSetup_assertingSDA
                    nextBitSetupSDAAssertMinX = x + xWaitBeforeBitSetupSDAAssert
                } else {
                    currentTransmissionControlState = .bitSetup_waitingBeforeReleasingSCL
                    nextBitSetupSCLReleaseMinX = x + xWaitBeforeBitSetupSCLRelease
                }
            } else {
                transmissionError()
            }
            
        case .bitSetup_waitingBeforeAssertingSDA:
            transmissionError()
            
        case .bitSetup_assertingSDA:
            if changedLine == .SCL {
                transmissionError()
            }
            
        case .bitSetup_waitingBeforeReleasingSCL:
            if changedLine == .SCL {
                transmissionError()
            }
            
        case .bitSetup_releasingSCL:
            
            if changedLine == .SCL {
                currentTransmissionControlState = .bitClock_waitingBeforePullingSCL
                nextBitClockSCLPullMinX = x + xWaitBeforeBitClockSCLPull
            } else {
                transmissionError()
            }
                
        case .bitClock_waitingBeforePullingSCL:
            if writingBit || changedLine == .SCL {
                transmissionError()
            }
            
        case .bitClock_pullingSCL:
            
            if changedLine == .SCL {
                currentTransmissionControlState = .bitClock_waitingAfterPullingSCL
                nextBitClockEndMinX = x + xWaitAfterBitClockSCLPull
            } else {
                transmissionError()
            }
            
        case .bitClock_waitingAfterPullingSCL:
            if writingBit || changedLine == .SCL {
                transmissionError()
            }
            
        case .stop_waitingBeforeReleasingSCL:
            transmissionError()
            
        case .stop_releasingSCL:
            
            if changedLine == .SCL {
                currentTransmissionControlState = .stop_waitingBeforeReleasingSDA
                nextStopSDAReleaseMinX = x + xWaitBeforeStopSDARelease
            }
            
        case .stop_waitingBeforeReleasingSDA:
            break
            
        case .stop_releasingSDA:
            
            if changedLine == .SDA {
                currentTransmissionControlState = .stop_waitingAfterReleasingSDA
                nextStopEndMinX = x + xWaitAfterStopSDARelease
            }
            
        case .stop_waitingAfterReleasingSDA:
            break
        }
    }
    
    
    func stabilizeTransmissionDriveState(x: CGFloat) {
        
        while true {
            
            let previousState = currentTransmissionControlState
            
            switch currentTransmissionControlState {
                
            case .start_waitingBeforeReleasingSDA:
                break
                
            case .start_releasingSDA:
                break
                
            case .start_waitingBeforeReleasingSCL:
                break
                
            case .start_releasingSCL:
                break
                
            case .start_waitingBeforePullingSDA:
                break
                
            case .start_pullingSDA:
                break
                
            case .start_waitingAfterPullingSDA:
                break
                
            case .bitSetup_waitingBeforePullingSCL:
                break
                
            case .bitSetup_pullingSCL:
                break
                
            case .bitSetup_waitingBeforeAssertingSDA:
                break
                
            case .bitSetup_assertingSDA:
                
                if (nextBitToWrite == .zero && bus.lineSDA.isLow) || (nextBitToWrite == .one && bus.lineSDA.isHigh) {
                    currentTransmissionControlState = .bitSetup_waitingBeforeReleasingSCL
                    nextBitSetupSCLReleaseMinX = x + xWaitBeforeBitSetupSCLRelease
                }
                
            case .bitSetup_waitingBeforeReleasingSCL:
                break
                
            case .bitSetup_releasingSCL:
                break
                
            case .bitClock_waitingBeforePullingSCL:
                break
                
            case .bitClock_pullingSCL:
                break
                
            case .bitClock_waitingAfterPullingSCL:
                break
                
            case .stop_waitingBeforeReleasingSCL:
                break
                
            case .stop_releasingSCL:
                break
                
            case .stop_waitingBeforeReleasingSDA:
                break
                
            case .stop_releasingSDA:
                break
                
            case .stop_waitingAfterReleasingSDA:
                break
            }
            
            if currentTransmissionControlState != previousState {
                continue
            } else {
                break
            }
        }
    }
    
    
    func updateControls() {
        
        switch currentTransmissionControlState {
            
        case .start_waitingBeforeReleasingSDA:
            break
            
        case .start_releasingSDA:
            self.pullingSDA = false
            
        case .start_waitingBeforeReleasingSCL:
            break
            
        case .start_releasingSCL:
            self.pullingSCL = false
            
        case .start_waitingBeforePullingSDA:
            break
            
        case .start_pullingSDA:
            self.pullingSDA = true
            
        case .start_waitingAfterPullingSDA:
            break
            
        case .bitSetup_waitingBeforePullingSCL:
            break
            
        case .bitSetup_pullingSCL:
            self.pullingSCL = true
            
        case .bitSetup_waitingBeforeAssertingSDA:
            break
            
        case .bitSetup_assertingSDA:
            self.pullingSDA = (writingBit && nextBitToWrite == .zero)
            
        case .bitSetup_waitingBeforeReleasingSCL:
            break
            
        case .bitSetup_releasingSCL:
            self.pullingSCL = false
            
        case .bitClock_waitingBeforePullingSCL:
            break
            
        case .bitClock_pullingSCL:
            self.pullingSCL = true
            
        case .bitClock_waitingAfterPullingSCL:
            break
            
        case .stop_waitingBeforeReleasingSCL:
            break
            
        case .stop_releasingSCL:
            self.pullingSCL = false
        
        case .stop_waitingBeforeReleasingSDA:
            break
            
        case .stop_releasingSDA:
            self.pullingSDA = false
            
        case .stop_waitingAfterReleasingSDA:
            break
        }
    }
    
    
    func updateTransmissionState(afterLineChanged changedLine: I2CBusLine.Identity) {
        
        switch currentTransmissionState {
        case .waitingStart:
            
            if changedLine == .SDA && currentLineLevels == (SCL: .high, SDA: .low) {
                currentTransmissionState = .started
            }
            
        case .started:
            
            if changedLine == .SCL {
                currentTransmissionState = .bitClockLow
            }
            
        case .bitClockLow:
            
            if changedLine == .SCL {
                currentTransmissionState = .bitClockHigh
            }
            
        case .bitClockHigh:
            
            if changedLine == .SCL {
                
                let bit = lastReadBit!
                currentTransmissionState = .bitClockLow
                updateTransmissionStep()
                onReadBit(bit: bit)
                
            } else if changedLine == .SDA && currentLineLevels.SDA == .high {
                
                let bytes = readDataBytes
                onDone(readBytes: bytes)
            }
        }
    }
    
    
    private func updateTransmissionStep() {
        
        if currentTransmissionStep == .transmittingAddressAck || currentTransmissionStep == .transmittingDataAck {
            
            let ack = Ack(from: lastReadBit!)
            let step = currentTransmissionStep
            
            currentTransmissionStep = .transmittingDataByte
            
            if step == .transmittingAddressAck {
                onReadAddressAck(ack: ack)
            }
            
            if step == .transmittingDataAck {
                currentByteIndex += 1
                onReadDataAck(ack: ack)
            }
        }
        
        if currentTransmissionStep == .transmittingAddressByte || currentTransmissionStep == .transmittingDataByte {
            
            currentByteReadBits.append(lastReadBit!)
            if currentByteReadBits.count == 8 {
                
                let byte = Byte(from: currentByteReadBits)
                currentByteReadBits = []
                lastReadByte = byte
                
                if currentTransmissionStep == .transmittingAddressByte {
                    readAddressByte = byte
                    currentTransmissionStep = .transmittingAddressAck
                    onReadAddressByte(byte: byte)
                    
                }
                if currentTransmissionStep == .transmittingDataByte {
                    readDataBytes.append(byte)
                    currentTransmissionStep = .transmittingDataAck
                    onReadDataByte(byte: byte)
                }
            }
        }
    }


    private func prepareNextBit() {

        writingBit = false
        
        switch currentTransmissionStep {
        
        case .transmittingAddressByte:
            
            writingBit = true
            nextBitToWrite = nextAddressBitToWrite
        
        case .transmittingAddressAck:
            break
            
        case .transmittingDataByte:
            
            if activeTransmission!.mode == .write {
                writingBit = true
                nextBitToWrite = nextDataBitToWrite
            }
        
        case .transmittingDataAck:
        
            if activeTransmission!.mode == .read {
                writingBit = true
                let ack = currentByteIndex < activeTransmission!.numBytes-1
                nextBitToWrite = ack ? .zero : .one
            }
        }
    }


    var nextAddressBitToWrite: Bit {

        let byte = activeTransmission!.addressRW
        return byte.bit(atIndex: currentByteBitIndex)
    }


    var nextDataBitToWrite: Bit? {

        if currentByteIndex < activeTransmission!.bytes.count {
            let byte = activeTransmission!.bytes[currentByteIndex]
            return byte.bit(atIndex: currentByteBitIndex)
        } else {
            return nil
        }
    }
}
