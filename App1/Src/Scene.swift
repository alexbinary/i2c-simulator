
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: LineLevel = .high
    var transitions: [CGFloat] = []
}



class RenderScene {
    
    let lineSCL = RenderSceneLine()
    let lineSDA = RenderSceneLine()


    init() {
        
        self.run()
    }
    
    
    func run() {

        let bus = I2CBus()

        //
        
        bus.reset()
        
        lineSCL.initialLevel = bus.lineSCL.currentLevel
        lineSDA.initialLevel = bus.lineSDA.currentLevel
        
        //

        let master = I2CMasterController()
        let slave1 = I2CSlaveController(address: 0x2a, acceptWrites: true, acceptReads: false, maxWrites: 1)
        let slave2 = I2CSlaveController(address: 0x61, acceptWrites: false, acceptReads: true)
        let perturbator = I2CPerturbatorController()
        
        bus.connect(master)
        bus.connect(slave1)
        bus.connect(slave2)
        bus.connect(perturbator)
        
//        master.scheduleTransmission(at: 10, I2CTransmission(writeTo: 0x2b, bytes: [0x01, 0x02]))
//        
//        master.scheduleTransmission(at: 650, I2CTransmission(writeTo: 0x2a, bytes: [0x01, 0x02]))
//        master.scheduleTransmission(at: 1400, I2CTransmission(readFrom: 0x2a, bytes: 2))
//        
//        master.scheduleTransmission(at: 2000, I2CTransmission(writeTo: 0x61, bytes: [0x03, 0x04]))
        master.scheduleTransmission(at: 2400, I2CTransmission(readFrom: 0x61, bytes: 2))
        
        bus.simulate(from: 0, to: 5000)
        
        //
        
        lineSCL.transitions = bus.lineSCL.transitions
        lineSDA.transitions = bus.lineSDA.transitions
    }
}
