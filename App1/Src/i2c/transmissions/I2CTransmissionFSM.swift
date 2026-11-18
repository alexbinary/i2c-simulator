
import SwiftUI



enum I2CBusFSMState {
    
    case idle_HH
    case idle_HL
    case idle_LH
    case idle_LL
    
    case started_LH
    
    case transmitting_HH
    case transmitting_HL
    case transmitting_LH
    case transmitting_LL
}


enum I2CTransmissionFSMState {
    
    case waitingStart
    case started

    static var initialState: I2CTransmissionFSMState { .waitingStart }
}


enum I2CTransmissionResultEnum {

    case success
    case addressNack
}


class I2CTransmissionFSM {
    
    
    var currentTransmissionState: I2CTransmissionFSMState = .initialState
    var transmissionsResult: I2CTransmissionResultEnum = .success

    var startFSM = I2CStartFSM()
    var stopFSM = I2CStopFSM()
    var bitFSM = I2CBitFSM()
    
    var currentLineLevels: (SDA: I2CLineLevel, SCL: I2CLineLevel) = (.high, .high)
    
    var transmittingAddress = false
    var transmittingAck = false

    var lastReadBit: Bit? = nil
    var lastReadByte: UInt8? = nil
    
    var readBytes: [UInt8] = []
    var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    
    func reset(levelSCL: I2CLineLevel, levelSDA: I2CLineLevel) {
        
        currentLineLevels = (SDA: levelSDA, SCL: levelSCL)
        
        currentTransmissionState = .initialState
        transmissionsResult = .success
        
        startFSM.reset(lineLevels: I2CBusLineLevels(SCL: levelSCL, SDA: levelSDA))
        stopFSM.reset(lineLevels: I2CBusLineLevels(SCL: levelSCL, SDA: levelSDA))
        bitFSM.reset(lineLevels: I2CBusLineLevels(SCL: levelSCL, SDA: levelSDA))
        
        transmittingAddress = true
        transmittingAck = false
        
        lastReadBit = nil
        lastReadByte = nil
        
        readBytes = []
        currentByteReadBits = []
        
        currentByteIndex = 0
    }
    
    
    func reset() {
        
        reset(levelSCL: currentLineLevels.SCL, levelSDA: currentLineLevels.SDA)
    }
    
    
    func update(
        
        afterLineChange changedLine: I2CBusLineEnum,
        
        onBitClocked: (Bit, Bool, Bool, Int, Int, Bool, UInt8?) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
    
    ) {
        
        switch changedLine {
        case .SDA:
            updateAfterSDAChanged(onBitClocked: onBitClocked, onDone: onDone, onAborted: onAborted)
        case .SCL:
            updateAfterSCLChanged(onBitClocked: onBitClocked, onDone: onDone, onAborted: onAborted)
        }
    }
    
    
    func updateAfterSDAChanged(
        
        onBitClocked: (Bit, Bool, Bool, Int, Int, Bool, UInt8?) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
        
    ) {
        
        currentLineLevels = (SDA: currentLineLevels.SDA.opposite, SCL: currentLineLevels.SCL)
        
        let changedLine: I2CBusLineEnum = .SDA
        
        func stop() {
            let bytes = readBytes
            reset()
            onDone(bytes)
        }
        
        func abort() {
            reset()
            onAborted()
        }
        
        switch currentTransmissionState {
        case .waitingStart:
            
            startFSM.update(
                afterLineChange: changedLine,
                onSuccess: {
                    currentTransmissionState = .started
                }, onError: {
                    abort()
                }
            )
            
        case .started:
            
            var bitError = false
            var stopError = false
            
            bitFSM.update(
                afterLineChange: changedLine,
                onSuccess: { bit in
                    
                    let transmittingAddress = transmittingAddress
                    let transmittingAck = transmittingAck
                    let byteIndex = currentByteIndex
                    let bitIndex = currentByteBitIndex
                    let byteComplete = currentByteReadBits.count == 8
                    
                    _updateMacroState(bit)
                    
                    onBitClocked(
                        bit,
                        transmittingAddress,
                        transmittingAck,
                        byteIndex,
                        bitIndex,
                        byteComplete,
                        lastReadByte
                    )
                },
                onError: {
                    bitError = true
                }
            )
            stopFSM.update(
                afterLineChange: changedLine,
                onSuccess: {
                    stop()
                },
                onError: {
                    stopError = true
                }
            )
            
            if bitError && stopError {
                abort()
            }
        }
    }
    
    
    func updateAfterSCLChanged(
        
        onBitClocked: (Bit, Bool, Bool, Int, Int, Bool, UInt8?) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
        
    ) {
        
        currentLineLevels = (SDA: currentLineLevels.SDA, SCL: currentLineLevels.SCL.opposite)
        
        let changedLine: I2CBusLineEnum = .SCL

        
        func stop() {
            let bytes = readBytes
            reset()
            onDone(bytes)
        }
        
        func abort() {
            reset()
            onAborted()
        }
        
        switch currentTransmissionState {
        case .waitingStart:
            
            startFSM.update(
                afterLineChange: changedLine,
                onSuccess: {
                    currentTransmissionState = .started
                }, onError: {
                    abort()
                }
            )
            
        case .started:
            
            var bitError = false
            var stopError = false
            
            bitFSM.update(
                afterLineChange: changedLine,
                onSuccess: { bit in
                    
                    let transmittingAddress = transmittingAddress
                    let transmittingAck = transmittingAck
                    let byteIndex = currentByteIndex
                    let bitIndex = currentByteBitIndex
                    let byteComplete = currentByteReadBits.count == 8
                    
                    _updateMacroState(bit)
                    
                    onBitClocked(
                        bit,
                        transmittingAddress,
                        transmittingAck,
                        byteIndex,
                        bitIndex,
                        byteComplete,
                        lastReadByte
                    )
                },
                onError: {
                    bitError = true
                }
            )
            stopFSM.update(
                afterLineChange: changedLine,
                onSuccess: {
                    stop()
                },
                onError: {
                    stopError = true
                }
            )
            
            if bitError && stopError {
                abort()
            }
        }
    }
    
    
    func update_stabilize(
        
        onBitClocked: (Bit, Bool, Bool, Int, Int, Bool, UInt8?) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
        
    ) {
        
        while true {
            
            let stateBefore = currentTransmissionState
            
            switch currentTransmissionState {
            case .waitingStart:
                break
            case .started:
                break
            }
            
            if currentTransmissionState != stateBefore {
                continue
            } else {
                break
            }
        }
    }
    

    private func _updateMacroState(_ bit: Bit) {

        lastReadBit = bit

        if transmittingAck {

            transmittingAck = false
            
            if transmittingAddress {
                transmittingAddress = false
            } else {
                currentByteIndex += 1
            }

        } else {

            currentByteReadBits.append(bit)
            
            if currentByteReadBits.count == 8 {
             
                let byte = byte(from: currentByteReadBits)
                currentByteReadBits = []
                lastReadByte = byte

                if !transmittingAddress {
                    readBytes.append(byte)
                }

                transmittingAck = true
            }
        }
    }


    func byte(from bits:[Bit]) -> UInt8 {

        return bits
            .map { $0 == .zero ? 0 : 1 }
            .reduce(0, { byte, bit in (byte << 1) + bit })
    }
}
