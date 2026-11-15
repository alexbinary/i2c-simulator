
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
        loadNextTransmission()
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

        if let transmissionFSM = transmissionFSM {

            transmissionFSM.update(x: x, updatedBusFSM: busFSM)
            printState()

            return transmissionFSM.currentAction
        }

        return nil
    }
    
    
    private func loadNextTransmission() {
        
        transmissionFSM = nil
        
        if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first {

            scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
            transmissionFSM = I2CMasterTransmissionFSM(transmission: entry.transmission, xStart: entry.x)
        }
    }
}
