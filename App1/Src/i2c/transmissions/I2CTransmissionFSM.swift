
import SwiftUI



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
    
    
    private(set) var currentState: I2CTransmissionFSMState = .initialState
    private(set) var result: I2CTransmissionResultEnum = .success

    var startFSM = I2CStartFSM()
    var stopFSM = I2CStopFSM()
    var bitFSM = I2CBitFSM()
    
    private(set) var transmittingAddress = false
    private(set) var transmittingAck = false

    private(set) var lastReadBit: Bit? = nil
    private(set) var lastReadByte: UInt8? = nil
    
    private var readBytes: [UInt8] = []
    private var currentByteReadBits: [Bit] = []
    
    private(set) var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    init() {
        reset()
    }
    
    
    func reset() {
        
        currentState = .initialState
        result = .success
        
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


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM,
        onBitClocked: (Bit, Bool, Bool, Int, Int, Bool, UInt8?) -> (),
        onDone: ([UInt8]) -> (), onAborted: () -> ()
    ) {
        while true {

            var nextState = currentState
            var exit = false

            func stop() {
                let bytes = readBytes
                reset()
                onDone(bytes)
                exit = true
            }
            
            func abort() {
                reset()
                onAborted()
                exit = true
            }
            
            switch currentState {
            case .waitingStart:

                startFSM.update(x: x, updatedBusFSM: updatedBusFSM,
                    onSuccess: {
                        nextState = .started
                    }, onError: {
                        abort()
                    }
                )

            case .started:
                
                var bitError = false
                var stopError = false
            
                bitFSM.update(x: x, updatedBusFSM: updatedBusFSM,
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
                stopFSM.update(x: x, updatedBusFSM: updatedBusFSM,
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

            if nextState == currentState || exit {
                break
            } else {
                currentState = nextState
                continue
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
