
import SwiftUI



class I2CController: SimulationEntity {
    
    
    let id = UUID()
    var bus: I2CBus!
    
    
    /* Public registers */
    
    var txFifo = Fifo(size: 256, pushWhenFullBehavior: .forcePush)
    var rxFifo = Fifo(size: 256, pushWhenFullBehavior: .forcePush)
    
    enum Result { case success, addressNack, dataNack, timeout }
    var result: Result = .success
    
    var address: Byte = 0x00
    var rw: ReadWrite = .writeToSlave
    var num_bytes: Int = 0
    
    var started = 0
    
    var stretching_enabled = 0
    var stretching_ongoing = 0
    var stretching_timeout: Int = 2000
    
    
    /* Internal state */
    
    var pullingSDA = false
    var pullingSCL = false
    
    var currentX: CGFloat = 0
    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)
    
    var transmissionOngoing = false
    var bitClockHighActive = false
    
    var lastLineChangeX: CGFloat = 0
    var lastIdleReachedX: CGFloat = 0
    var lastBitClockHighStartX: CGFloat = 0
    var lastBitClockLowStartX: CGFloat = 0
    
    let xDelayBetweenLineChange: CGFloat = 10
    let xBitClockHighDuration: CGFloat = 30
    let xBitClockLowDuration: CGFloat = 30
    
    var numTransmittedBits = 0
    
    
    func reset(x: CGFloat) {
        
        currentX = x
        
        transmissionOngoing = false
        numTransmittedBits = 0
        
        pullingSDA = false
        pullingSCL = false
    }
    
    
    func update(x: CGFloat) {
        
        currentX = x
        
        updateLineLevels()
        updateBusControls()
        applyBusControls()
    }
    
    
    func updateLineLevels() {
        
        if bus.currentLineLevels != lastKnownLineLevels {
            
            if let symbol = detectedSymbol(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                switch symbol {
                    
                case .start:
                    lastBitClockHighStartX = currentX
                    transmissionStarted()
                    
                case .stop:
                    transmissionStopped()
                    
                case .clockFall:
                    if transmissionOngoing {
                        lastBitClockLowStartX = currentX
                        clockHighPhaseEnded()
                        bitClockHighActive = false
                        clockLowPhaseStarted()
                    }
                    
                case .clockRise:
                    if transmissionOngoing {
                        lastBitClockHighStartX = currentX
                        clockLowPhaseEnded()
                        bitClockHighActive = true
                        clockHighPhaseStarted()
                    }
                }
            }
            
            lastKnownLineLevels = bus.currentLineLevels
            lastLineChangeX = currentX
            
            if bus.currentLineLevels == (SCL: .high, SDA: .high) {
                lastIdleReachedX = currentX
            }
        }
    }
    
    
    func updateBusControls() {
        
    }
    
    
    func applyBusControls() {
        
        if pullingSDA { pullSDA() } else { releaseSDA() }
        if pullingSCL { pullSCL() } else { releaseSCL() }
    }
    
    
    func transmissionStarted() {
    
        transmissionOngoing = true
        bitClockHighActive = false
        numTransmittedBits = 0
    }
    
    
    func clockLowPhaseStarted() {
        
        stretchingPhaseStarted()
    }
    
    
    func clockLowPhaseEnded() {
        
    }
    
    
    func clockHighPhaseStarted() {
        
    }
    
    
    func clockHighPhaseEnded() {
        
        if bitClockHighActive {
            bitClockPhaseEnded()
        }
    }
    
    
    func stretchingPhaseStarted() {
        
        bitSetupPhaseStarted()
    }
    
    
    func bitSetupPhaseStarted() {
        
    }
    
    
    func bitClockPhaseEnded() {
        
        numTransmittedBits += 1
    }
    
    
    func transmissionStopped() {
        
        transmissionOngoing = false
    }
    
    
    func waited(_ duration: CGFloat, relativeTo ref: CGFloat) -> Bool {

        return (currentX - ref) >= duration
    }
    
    
    func waitedDelayBetweenLineChanges() -> Bool {
        
        return waited(xDelayBetweenLineChange, relativeTo: lastLineChangeX)
    }

    
    func connect(to bus: I2CBus) {
        
        self.bus = bus
    }
    
    func pull(_ line: I2CBusLine.Identity) {
        
        bus.line(line).addPuller(self)
    }
        
    func release(_ line: I2CBusLine.Identity) {
        
        bus.line(line).removePuller(self)
    }
    
    func pullSDA() {
        
        pull(.SDA)
    }
    
    func pullSCL() {
        
        pull(.SCL)
    }
    
    func releaseSDA() {
        
        release(.SDA)
    }
    
    func releaseSCL() {
        
        release(.SCL)
    }
    
    
    func detectedSymbol(analysingTransitionFrom lineLevelsBefore: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel), to lineLevelsAfter: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel)) -> I2CBusSymbol? {
        
        if lineLevelsBefore == (SCL: .high, SDA: .high) && lineLevelsAfter == (SCL: .high, SDA: .low) {
            return .start
        }
        
        if lineLevelsBefore == (SCL: .high, SDA: .low) && lineLevelsAfter == (SCL: .high, SDA: .high) {
            return .stop
        }
        
        if lineLevelsBefore.SCL == .high && lineLevelsAfter.SCL == .low {
            return .clockFall
        }
        
        if lineLevelsBefore.SCL == .low && lineLevelsAfter.SCL == .high {
            return .clockRise
        }
        
        return nil
    }
}
