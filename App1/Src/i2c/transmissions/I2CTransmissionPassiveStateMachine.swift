
import SwiftUI



class I2CTransmissionPassiveStateMachine {
    
    
    enum MicroState {
        
        case waitingStart
        case started
    }
    
    
    enum MacroState {
        
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
    }
    
    
    enum Result {
        
        case success
        case addressNack
    }
    
    
    var currentMicroState: MicroState = .waitingStart
    var currentMacroState: MacroState = .transmittingAddressByte
    var transmissionsResult: Result = .success
    
    var currentLineLevels: I2CBusLineLevels = .init(SCL: .high, SDA: .high)

    var startFSM = I2CStartFSM()
    var stopFSM = I2CStopFSM()
    var bitFSM = I2CBitFSM()
    
    var lastReadBit: Bit? = nil
    var lastReadByte: UInt8? = nil
    
    var readDataBytes: [UInt8] = []
    var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    
    func reset(lineLevels: I2CBusLineLevels) {
        
        currentMicroState = .waitingStart
        currentMacroState = .transmittingAddressByte
        transmissionsResult = .success
        
        currentLineLevels = lineLevels
        
        startFSM.reset(lineLevels: lineLevels)
        stopFSM.reset(lineLevels: lineLevels)
        bitFSM.reset(lineLevels: lineLevels)
        
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
        case .waitingStart:
            
            startFSM.update(
                afterLineChange: changedLine,
                onStart: {
                    currentMicroState = .started
                }
            )
            
        case .started:
            
            bitFSM.update(
                afterLineChange: changedLine,
                onBitClocked: { bit in
                    let macroState = currentMacroState
                    let byteIndex = currentByteIndex
                    updateMacroState(bit)
                    onBitClocked(bit, macroState, byteIndex)
                }
            )
            
            stopFSM.update(
                afterLineChange: changedLine,
                onStop: {
                    let bytes = readDataBytes
                    reset()
                    onDone(bytes)
                }
            )
        }
    }
    
    
    private func updateMacroState(_ bit: Bit) {

        lastReadBit = bit
        
        if currentMacroState == .transmittingAddressAck || currentMacroState == .transmittingDataAck {
            currentMacroState = .transmittingDataByte
            
            if currentMacroState == .transmittingDataAck {
                currentByteIndex += 1
            }
        }
        
        if currentMacroState == .transmittingAddressByte || currentMacroState == .transmittingDataByte {

            currentByteReadBits.append(bit)
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
