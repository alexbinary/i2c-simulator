
import SwiftUI



class I2CController: SimulationEntity {
    
    
    let id = UUID()
    var bus: I2CBus!
    
    
    /* Public registers */
    
    var txFifo = Fifo(size: 256, pushWhenFullBehavior: .forcePush)
    var rxFifo = Fifo(size: 256, pushWhenFullBehavior: .forcePush)
    
    enum Result { case success, addressNack, dataNack, timeout, aborted }
    var result: Result = .success
    
    var address: Byte = 0x00
    var rw: ReadWrite = .writeToSlave
    var num_bytes: Int = 0
    
    var started = 0
    
    var stretching_enabled = 0
    var stretching_ongoing = 0
    var stretching_timeout: Int = 2000
    
    
    /* Configurations */
    
    let xDelayBetweenLineChange: CGFloat = 10
    let xBitClockHighDuration: CGFloat = 30
    let xBitClockLowDuration: CGFloat = 30
    
    
    /* Internal bus-related state */
    
    var pullingSDA = false
    var pullingSCL = false
    
    var currentX: CGFloat = 0
    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel)?
    
    var lastLineChangeX: CGFloat?
    var lastIdleReachedX: CGFloat?
    var lastStartX: CGFloat?
    var lastStopX: CGFloat?
    var lastBitClockStartX: CGFloat?
    var lastBitSetupStartX: CGFloat?
    
    
    /* Internal transmission-related state */
    
    var transmissionOngoing = false
    var detectedClockRiseSinceStart = false
    
    var numTransmittedBits = 0
    var numTransmittedBytes: Int { numTransmittedBits / 9 }
    
    
    func reset(x: CGFloat) {
        
        currentX = x
        
        resetAllTransmissionRelatedState()
        
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
        
        if lastKnownLineLevels == nil || bus.currentLineLevels != lastKnownLineLevels! {
            
            if let lastKnownLineLevels = lastKnownLineLevels {
                switch detectedSymbol(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                case .start: startCondition()
                case .stop: stopCondition()
                case .clockFall: clockFall()
                case .clockRise: clockRise()
                case .none: break
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
    
    
    func resetAllTransmissionRelatedState() {
        
        transmissionOngoing = false
        detectedClockRiseSinceStart = false
        numTransmittedBits = 0
    }
    
    
    func startCondition() {
        
        transmissionOngoing = true
        lastStartX = currentX
        
        transmissionStarted()
    }
    
    
    func stopCondition() {
        
        lastStopX = currentX
        
        transmissionStopped()
        resetAllTransmissionRelatedState()
    }
    
    
    func clockFall() {
        
        if transmissionOngoing {
            
            if detectedClockRiseSinceStart {
                bitClockEnded()
            }
            bitSetupStarted()
        }
    }
    
    
    func clockRise() {
        
        if transmissionOngoing {
            
            detectedClockRiseSinceStart = true
            
            bitSetupEnded()
            bitClockStarted()
        }
    }
    
    
    func transmissionStarted() {
        
    }
    
    
    func bitSetupStarted() {
        
        lastBitSetupStartX = currentX
    }
    
    
    func bitSetupEnded() {
        
    }
    
    
    func bitClockStarted() {
        
        lastBitClockStartX = currentX
    }
    
    
    func bitClockEnded() {
        
        numTransmittedBits += 1
    }
    
    
    func transmissionStopped() {
    
        resetAllTransmissionRelatedState()
    }
    
    
    func waited(_ duration: CGFloat, relativeTo ref: CGFloat?) -> Bool {

        if let ref = ref {
            return (currentX - ref) >= duration
        } else {
            return true
        }
    }
    
    
    func waitedDelayBetweenLineChanges() -> Bool {
        
        return waited(xDelayBetweenLineChange, relativeTo: lastLineChangeX)
    }
    
    
    func waitedClockLowDuration() -> Bool {
        
        waited(xBitClockLowDuration, relativeTo: lastBitSetupStartX)
    }
    
    
    func waitedClockHighDuration() -> Bool {
        
        waited(xBitClockHighDuration, relativeTo: lastBitClockStartX)
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
