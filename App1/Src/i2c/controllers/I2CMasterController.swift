
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var transmissionFSM: I2CMasterTransmissionFSM?
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }


    private func printState() {

        print("")
        print("-- MASTER UPDATED STATE --")
        print("bus state: \(busFSM.currentState)")
        print("transmission state: \(transmissionFSM?.currentState)")
        print("transmittingAddressRWBit: \(transmissionFSM?.transmittingAddressRWBit)")
        print("transmission result: \(transmissionFSM?.result)")
        print("start state: \(transmissionFSM?.sendStartFSM.currentState)")
        print("stop state: \(transmissionFSM?.sendStopFSM.currentState)")
        print("bit write state: \(transmissionFSM?.bitWriteFSM.currentState)")
        print("bit read state: \(transmissionFSM?.bitReadFSM.currentState)")
    }
    
    
    override func _updateCompute(x: CGFloat) -> I2CControllerLineAction? {

        while true {

            if let transmissionFSM = transmissionFSM {

                transmissionFSM.update(x: x, updatedBusFSM: busFSM)
                printState()

                if transmissionFSM.currentState == .done || transmissionFSM.currentState == .aborted {

                    self.transmissionFSM = nil
                    printState()

                } else {

                    return currentAction(for: transmissionFSM)
                }

            } else {

                if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first, entry.x <= x {

                    scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
                    transmissionFSM = I2CMasterTransmissionFSM(transmission: entry.transmission)
                    printState()

                } else {

                    break
                }
            }
        }

        return nil
    }


    func currentAction(for transmissionFSM: I2CMasterTransmissionFSM) -> I2CControllerLineAction? {

        switch transmissionFSM.sendStartFSM.currentState {
        case .pullingSDA:
            return .pullSDA

        default:
            break
        }

        switch transmissionFSM.bitWriteFSM.currentState {
        case .pullingSCL, .clockingLow:
            return .pullSCL

        case .pullingSDA:
            return .pullSDA

        case .releasingSDA:
            return .releaseSDA

        case .clockingHigh:
            return .releaseSCL
            
        default:
            break
        }

        switch transmissionFSM.bitReadFSM.currentState {
        case .pullingSCL, .clockingLow:
            return .pullSCL

        case .clockingHigh:
            return .releaseSCL

        default:
            break
        }

        switch transmissionFSM.sendStopFSM.currentState {
        case .pullingSDA:
            return .pullSDA

        case .releasingSCL:
            return .releaseSCL

        case .releasingSDA:
            return .releaseSDA
            
        default:
            break
        }

        return nil
    }
}
