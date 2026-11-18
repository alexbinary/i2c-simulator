
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
    
    
    var currentBusState: I2CBusFSMState = .idle_HH
    var isIdle: Bool { currentBusState == .idle_HH }
    
    var currentTransmissionState: I2CTransmissionFSMState = .initialState
    var transmissionsResult: I2CTransmissionResultEnum = .success

    var startFSM = I2CStartFSM()
    var stopFSM = I2CStopFSM()
    var bitFSM = I2CBitFSM()
    
    var transmittingAddress = false
    var transmittingAck = false

    var lastReadBit: Bit? = nil
    var lastReadByte: UInt8? = nil
    
    var readBytes: [UInt8] = []
    var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    
    func reset(levelSCL: LineLevel, levelSDA: LineLevel) {
        
        switch (levelSDA, levelSCL) {
        case (.high, .high): currentBusState = .idle_HH
        case (.high, .low): currentBusState = .idle_HL
        case (.low, .high): currentBusState = .idle_LH
        case (.low, .low): currentBusState = .idle_LL
        }
        
        currentTransmissionState = .initialState
        transmissionsResult = .success
        
        startFSM.reset()
        stopFSM.reset()
        bitFSM.reset()
        
        transmittingAddress = true
        transmittingAck = false
        
        lastReadBit = nil
        lastReadByte = nil
        
        readBytes = []
        currentByteReadBits = []
        
        currentByteIndex = 0
    }


    func update(
        
        after event: I2CBusEvent,
        
        onBitClocked: (Bit, Bool, Bool, Int, Int, Bool, UInt8?) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
        
    ) {
        
        switch event {
            
        case .lineChange(let changedLine):
            
            update(
                afterLineChange: changedLine,
                onBitClocked: onBitClocked, onDone: onDone, onAborted: onAborted
            )
            
        case .timeStep(let step):
            
            update(
                afterTimeStep: step,
                onBitClocked: onBitClocked, onDone: onDone, onAborted: onAborted
            )
        }
        
        update_stabilize(
            onBitClocked: onBitClocked, onDone: onDone, onAborted: onAborted
        )
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
        
        let changedLine: I2CBusLineEnum = .SDA
        
        switch currentBusState {
            
        case .idle_HH:
            
            currentBusState = .started_LH
            
        case .idle_HL:
            
            currentBusState = .idle_LL
            
        case .idle_LH:
            
            currentBusState = .idle_HH
            
        case .idle_LL:
            
            currentBusState = .idle_HL
            
        case .started_LH:
            
            currentBusState = .idle_HH
            
        case .transmitting_HH:
            
            currentBusState = .started_LH
            
        case .transmitting_HL:
            
            currentBusState = .transmitting_LL
            
        case .transmitting_LH:
            
            currentBusState = .idle_HH
            
        case .transmitting_LL:
            
            currentBusState = .transmitting_HL
        }
        
        
        func stop() {
            let bytes = readBytes
            reset(levelSCL: lineLevels.SCL, levelSDA: lineLevels.SDA)
            onDone(bytes)
        }
        
        func abort() {
            reset(levelSCL: lineLevels.SCL, levelSDA: lineLevels.SDA)
            onAborted()
        }
        
        switch currentTransmissionState {
        case .waitingStart:
            
            startFSM.update(
                afterLineChange: changedLine, updatedBusState: currentBusState,
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
                afterLineChange: changedLine, updatedBusState: currentBusState, updatedLineLevels: lineLevels,
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
                afterLineChange: changedLine, updatedBusState: currentBusState,
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
        
        let changedLine: I2CBusLineEnum = .SCL
        
        switch currentBusState {
            
        case .idle_HH:
            
            currentBusState = .idle_HL
            
        case .idle_HL:
            
            currentBusState = .idle_HH
            
        case .idle_LH:
            
            currentBusState = .idle_LL
            
        case .idle_LL:
            
            currentBusState = .idle_LH
            
        case .started_LH:
            
            currentBusState = .transmitting_LL
            
        case .transmitting_HH:
            
            currentBusState = .transmitting_HL
            
        case .transmitting_HL:
            
            currentBusState = .transmitting_HH
            
        case .transmitting_LH:
            
            currentBusState = .transmitting_LL
            
        case .transmitting_LL:
            
            currentBusState = .transmitting_LH
        }
        
        
        func stop() {
            let bytes = readBytes
            reset(levelSCL: lineLevels.SCL, levelSDA: lineLevels.SDA)
            onDone(bytes)
        }
        
        func abort() {
            reset(levelSCL: lineLevels.SCL, levelSDA: lineLevels.SDA)
            onAborted()
        }
        
        switch currentTransmissionState {
        case .waitingStart:
            
            startFSM.update(
                afterLineChange: changedLine, updatedBusState: currentBusState,
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
                afterLineChange: changedLine, updatedBusState: currentBusState, updatedLineLevels: lineLevels,
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
                afterLineChange: changedLine, updatedBusState: currentBusState,
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
    
    
    func update(
        
        afterTimeStep xStep: CGFloat,
        
        onBitClocked: (Bit, Bool, Bool, Int, Int, Bool, UInt8?) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
        
    ) {
        
        switch currentTransmissionState {
        case .waitingStart:
            break
        case .started:
            break
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
    
    
    var lineLevels: (SDA: LineLevel, SCL: LineLevel) {
        
        switch currentBusState {
        case .idle_HH: return (SDA: .high, SCL: .high)
        case .idle_HL: return (SDA: .high, SCL: .low)
        case .idle_LH: return (SDA: .low, SCL: .high)
        case .idle_LL: return (SDA: .low, SCL: .low)
        case .started_LH: return (SDA: .low, SCL: .high)
        case .transmitting_HH: return (SDA: .high, SCL: .high)
        case .transmitting_HL: return (SDA: .high, SCL: .low)
        case .transmitting_LH: return (SDA: .low, SCL: .high)
        case .transmitting_LL: return (SDA: .low, SCL: .low)
        }
    }
}
