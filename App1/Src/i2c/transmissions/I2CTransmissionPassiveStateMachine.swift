
import SwiftUI



class I2CTransmissionPassiveStateMachine {
    
    
    enum State {
        
        case waitingStart
        case started
        case bitClockLow
        case bitClockHigh
        case stopped
    }
    
    
    enum Step {
        
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
    }
    
    
    var currentTransmissionState: State = .waitingStart
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
        
        currentTransmissionState = .waitingStart
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
        case .waitingStart:
            
            if changedLine == .SDA && currentLineLevels.match(SCL: .high, SDA: .low) {
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
                updateTransmissionStep(
                    onReadAddressByte: onReadAddressByte,
                    onReadAddressAck: onReadAddressAck,
                    onReadDataByte: onReadDataByte,
                    onReadDataAck: onReadDataAck
                )
                onReadBit(bit)
            
            } else if changedLine == .SDA && currentLineLevels.SDA == .high {
                    
                let bytes = readDataBytes
                currentTransmissionState = .stopped
                onDone(bytes)
                
            } else {
                
                lastReadBit = currentLineLevels.SDA.bit
            }
            
        case .stopped:
            break
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
