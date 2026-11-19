
import SwiftUI



class I2CTransmissionPassiveStateMachine {
    
    
    enum MicroState {
        
        case waitingIdle
        case waitingSDADrop
        case bitClockLow
        case bitClockHigh
    }
    
    
    enum MacroState {
        
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
    }
    
    
    var currentMicroState: MicroState = .waitingIdle
    var currentMacroState: MacroState = .transmittingAddressByte
    
    var stopPreConditionMet = false
    
    var currentLineLevels: I2CBusLineLevels = .init(SCL: .high, SDA: .high)
    
    var lastReadBit: Bit? = nil
    var lastReadByte: UInt8? = nil
    
    var readDataBytes: [UInt8] = []
    var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    
    func reset(lineLevels: I2CBusLineLevels) {
        
        currentMicroState = .waitingIdle
        currentMacroState = .transmittingAddressByte
        
        stopPreConditionMet = false
        
        currentLineLevels = lineLevels
        
        lastReadBit = nil
        lastReadByte = nil
        
        readDataBytes = []
        currentByteReadBits = []
        
        currentByteIndex = 0
    }
    
    
    func reset() {
        
        reset(lineLevels: currentLineLevels)
    }
    
    
    func update(
        
        afterLineChange changedLine: I2CBusLineEnum,
        
        onBitClocked: (Bit, MacroState, Int) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
    
    ) {
        
        currentLineLevels = currentLineLevels.updated(afterLineChange: changedLine)
        
        switch currentMicroState {
        case .waitingIdle:
            
            if currentLineLevels.match(SCL: .high, SDA: .high) {
                currentMicroState = .waitingSDADrop
            }
            
        case .waitingSDADrop:
            
            if currentLineLevels.match(SCL: .high, SDA: .low) {
                currentMicroState = .bitClockLow
            } else {
                currentMicroState = .waitingIdle
            }
            
        case .bitClockLow:
            
            if currentLineLevels.SCL == .high {
                currentMicroState = .bitClockHigh
            }
            
        case .bitClockHigh:
            
            if currentLineLevels.SCL == .low {
                
                let bit = lastReadBit!
                let macroState = currentMacroState
                let byteIndex = currentByteIndex
                currentMicroState = .bitClockLow
                updateMacroState()
                onBitClocked(bit, macroState, byteIndex)
            
            } else if changedLine == .SDA && currentLineLevels.SDA == .high {
                    
                let bytes = readDataBytes
                reset()
                onDone(bytes)
                
            } else {
                
                lastReadBit = currentLineLevels.SDA.bit
            }
        }
    }
    
    
    private func updateMacroState() {

        if currentMacroState == .transmittingAddressAck || currentMacroState == .transmittingDataAck {
            currentMacroState = .transmittingDataByte
            
            if currentMacroState == .transmittingDataAck {
                currentByteIndex += 1
            }
        }
        
        if currentMacroState == .transmittingAddressByte || currentMacroState == .transmittingDataByte {

            currentByteReadBits.append(lastReadBit!)
            if currentByteReadBits.count == 8 {
             
                let byte = Byte(from: currentByteReadBits)
                currentByteReadBits = []
                lastReadByte = byte

                if currentMacroState == .transmittingAddressByte {
                    currentMacroState = .transmittingAddressAck
                }
                if currentMacroState == .transmittingDataByte {
                    readDataBytes.append(byte)
                    currentMacroState = .transmittingDataAck
                }
            }
        }
    }
}
