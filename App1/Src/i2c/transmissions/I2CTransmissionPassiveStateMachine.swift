
import SwiftUI



class I2CTransmissionPassiveStateMachine {
    
    
    enum State {
        
        case waitingIdle
        case waitingSDADrop
        case bitClockLow
        case bitClockHigh
    }
    
    
    enum Step {
        
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
    }
    
    
    var currentTransmissionState: State = .waitingIdle
    var currentTransmissionStep: Step = .transmittingAddressByte
    
    var currentLineLevels: I2CBusLineLevels = .init(SCL: .high, SDA: .high)
    
    var lastReadBit: Bit? = nil
    var lastReadByte: UInt8? = nil
    
    var readAddressByte: UInt8? = nil
    var readDataBytes: [UInt8] = []
    var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    
    func reset(lineLevels: I2CBusLineLevels) {
        
        currentTransmissionState = .waitingIdle
        currentTransmissionStep = .transmittingAddressByte
        
        currentLineLevels = lineLevels
        
        lastReadBit = nil
        lastReadByte = nil
        
        readAddressByte = nil
        readDataBytes = []
        currentByteReadBits = []
        
        currentByteIndex = 0
    }
    
    
    func reset() {
        
        reset(lineLevels: currentLineLevels)
    }
    
    
    func update(
        
        afterLineChange changedLine: I2CBusLineEnum,
        
        onReadAddressByte: (Byte) -> (),
        onReadAddressAck: (Ack) -> (),
        onReadDataByte: (Byte) -> (),
        onReadDataAck: (Ack) -> (),
        onReadBit: (Bit) -> (),
        onDone: ([UInt8]) -> (),
        onAborted: () -> ()
    
    ) {
        
        currentLineLevels = currentLineLevels.updated(afterLineChange: changedLine)
        
        switch currentTransmissionState {
        case .waitingIdle:
            
            if currentLineLevels.match(SCL: .high, SDA: .high) {
                currentTransmissionState = .waitingSDADrop
            }
            
        case .waitingSDADrop:
            
            if currentLineLevels.match(SCL: .high, SDA: .low) {
                currentTransmissionState = .bitClockLow
            } else {
                currentTransmissionState = .waitingIdle
            }
            
        case .bitClockLow:
            
            if currentLineLevels.SCL == .high {
                currentTransmissionState = .bitClockHigh
            }
            
        case .bitClockHigh:
            
            if currentLineLevels.SCL == .low {
                
                let bit = lastReadBit!
                currentTransmissionState = .bitClockLow
                updateTransmissionStep(
                    onReadAddressByte: onReadAddressByte,
                    onReadAddressAck: onReadAddressAck,
                    onReadDataByte: onReadDataByte,
                    onReadDataAck: onReadDataAck
                )
                onReadBit(bit)
            
            } else if changedLine == .SDA && currentLineLevels.SDA == .high {
                    
                let bytes = readDataBytes
                reset()
                onDone(bytes)
                
            } else {
                
                lastReadBit = currentLineLevels.SDA.bit
            }
        }
    }
    
    
    private func updateTransmissionStep(
        
        onReadAddressByte: (Byte) -> (),
        onReadAddressAck: (Ack) -> (),
        onReadDataByte: (Byte) -> (),
        onReadDataAck: (Ack) -> (),
        
    ) {

        if currentTransmissionStep == .transmittingAddressAck || currentTransmissionStep == .transmittingDataAck {
            
            let ack = Ack(from: lastReadBit!)
            let step = currentTransmissionStep
            
            currentTransmissionStep = .transmittingDataByte
            
            if step == .transmittingAddressAck {
                onReadAddressAck(ack)
            }
            
            if step == .transmittingDataAck {
                currentByteIndex += 1
                onReadDataAck(ack)
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
                    onReadAddressByte(byte)
                    
                }
                if currentTransmissionStep == .transmittingDataByte {
                    readDataBytes.append(byte)
                    currentTransmissionStep = .transmittingDataAck
                    onReadDataByte(byte)
                }
            }
        }
    }
}
