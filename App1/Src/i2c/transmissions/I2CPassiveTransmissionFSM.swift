
import SwiftUI



enum I2CMasterTransmissionFSMState {
    
    case waitingStart
    case started

    static var initialState: I2CMasterTransmissionFSMState { .waitingStart }
}


enum I2CMasterTransmissionResultEnum {

    case success
    case addressNack
}


class I2CPassiveTransmissionFSM {
    
    
    private(set) var currentState: I2CMasterTransmissionFSMState = .waitingStart
    private(set) var result: I2CMasterTransmissionResultEnum = .success

    var startFSM = I2CStartFSM()
    var stopFSM = I2CStopFSM()
    var bitFSM = I2CBitFSM()


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM, onDone: () -> (), onAborted: () -> ()) {

        while true {

            var nextState = currentState

            func done() {
                onDone()
                nextState = .initialState
            }
            
            func abort() {
                onAborted()
                nextState = .initialState
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
                    },
                    onError: {
                        bitError = true
                    }
                )
                stopFSM.update(x: x, updatedBusFSM: updatedBusFSM,
                    onSuccess: {
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
}