
import SwiftUI



enum I2CTransmissionFSMState {
    
    case waitingStart
    case started

    static var initialState: I2CTransmissionFSMState { .waitingStart }
}


enum I2CTransmissionFSMMacroState {
    
    case transmittingAddress
    case transmittingAddressAck
    case transmittingByte
    case transmittingByteAck

    static var initialState: I2CTransmissionFSMMacroState { .transmittingAddress }
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
    
    private(set) var currentMacroState: I2CTransmissionFSMMacroState = .initialState

    private var readBytes: [UInt8] = []

    private(set) var lastReadBit: Bit? = nil
    private(set) var lastReadByte: UInt8? = nil
    
    private var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int { readBytes.count }
    var currentByteBitIndex: Int { currentByteReadBits.count }
    var currentByteComplete: Bool { currentByteReadBits.count == 8 }


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM, onClockedBit: () -> (), onStop: () -> (), onDone: () -> (), onAborted: () -> ()) {

        while true {

            var nextState = currentState

            func done() {
                onDone()
                nextState = .initialState
                _reset()
            }
            
            func abort() {
                onAborted()
                nextState = .initialState
                _reset()
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
                    onSuccess: {
                        let bit = bitFSM.readBit!
                        _onClockedBit(bit)
                        let previousMacroState
                        _updateMacroState()
                        onClockedBit(previousMacroState)
                    },
                    onError: {
                        bitError = true
                    }
                )
                stopFSM.update(x: x, updatedBusFSM: updatedBusFSM,
                    onSuccess: {
                        onStop()
                        done()
                    },
                    onError: {
                        stopError = true
                    }
                )
                
                if bitError && stopError {
                    abort()
                }
            }

            if nextState != currentState {
                currentState = nextState
                continue
            } else {
                break
            }
        }
    }


    private func _reset() {

        lastReadBit = nil
        lastReadByte = nil
        currentByteReadBits = []
    }


    private func _onClockedBit(_ bit: Bit) {

        lastReadBit = bit

        switch currentMacroState {
        case .transmittingAddress:
            currentByteReadBits.append(bit)
            if currentByteReadBits.count == 8 {
                let byte = byte(from: currentByteReadBits)
                currentByteReadBits = []
                lastReadByte = byte
            }
        case .transmittingAddressAck:
            break
        case .transmittingByte:
            currentByteReadBits.append(bit)
            if currentByteReadBits.count == 8 {
                let byte = byte(from: currentByteReadBits)
                currentByteReadBits = []
                lastReadByte = byte
                readBytes.append(byte)
            }
        case .transmittingByteAck:
            break
        }
    }


    private func _updateMacroState() {

        switch currentMacroState {
        case .transmittingAddress:
            if currentByteComplete {
                currentMacroState = .transmittingAddressAck
            }
        case .transmittingAddressAck:
            currentMacroState = .transmittingByte
            
        case .transmittingByte:
            if currentByteComplete {
                currentMacroState = .transmittingByteAck
            }
        case .transmittingByteAck:
            currentMacroState = .transmittingByte
        }
    }


    func byte(from bits:[Bit]) -> UInt8 {

        return bits
            .map { $0 == .zero ? 0 : 1 }
            .reduce(0, { byte, bit in (byte << 1) + bit })
    }
}
