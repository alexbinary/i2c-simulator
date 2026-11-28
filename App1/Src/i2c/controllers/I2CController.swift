
import SwiftUI



class I2CController: SimulationEntity, I2CBusConnectable {
    
    
    let id = UUID()
    let name: String
    
    var bus: I2CBus!
    
    var markers: [SimulationMarker] = []
    
    
    init(name: String) {
        self.name = name
    }
    
    
    /* Public registers */
    
    var txFifo = Fifo(size: 256, pushWhenFullBehavior: .forcePush)
    var rxFifo = Fifo(size: 256, pushWhenFullBehavior: .forcePush)
    
    var address: Byte = 0x00
    var rw: ReadWrite = .writeToSlave
    var num_bytes: Int = 0
    
    enum Result { case success, addressNack, dataNack, timeout, aborted }
    var result: Result = .success
    
    var started = 0
    var start_timeout: CGFloat = 100
    
    var stretching_enabled = 0
    var stretching_ongoing = 0
    var stretching_timeout: Int = 200
    
    var hold_bus = 0
    var hold_timeout = 200
    
    var slave_addresses: [Byte] = []
    var slave_last_address_index: Int = 0
    
    var slave_spy_mode = 0
    var slave_spy_mode_stretching_enabled = 0
    
    
    /* Configurations */
    
    let xDelayBetweenLineChanges: CGFloat = 10
    
    let xWaitBeforeEngagingStart: CGFloat = 30
    let xWaitBeforeEngagingStop: CGFloat = 30
    
    let xWaitAfterStart: CGFloat = 30
    
    let xBitSetupDuration: CGFloat = 30
    let xBitClockDuration: CGFloat = 30
    
    
    /* Internal generic state */
    
    var started_previousValue = 0
    var started_risingEdgeDetected = 0
    var stretching_enabled_previousValue = 0
    var stretching_enabled_fallingEdgeDetected = 0
    
    var currentX: CGFloat = 0
    var lastStartRequestX: CGFloat?
    var lastStretchingStartX: CGFloat?
    var lastStretchingTerminationPhaseStartX: CGFloat?
    
    
    /* Internal bus-related state */
    
    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel)?
    
    var lastLineChangeX: CGFloat?
    var lastIdleReachedX: CGFloat?
    var lastStartDetectedX: CGFloat?
    var lastStopDetectedX: CGFloat?
    var lastBitSetupStartX: CGFloat?
    var lastBitClockStartX: CGFloat?
    var lastBitClockEndX: CGFloat?
    var lastHoldStartedX: CGFloat?
    
    var pullingSCL = false
    var pullingSDA = false
    
    var generatingStart = false
    var generatingClock = false
    var generatingStop = false
    
    var holdingClock = false
    var holdingClockTerminationPhase = false
    var holdingBus = false
    
    var currentBitToTransmit: Bit?
    var lastReadBit: Bit?
    
    
    /* Internal transmission-related state */
    
    var betweenStartAndStop = false
    var detectedClockRiseSinceStart = false
    
    var numTransmittedBits = 0
    var numTransmittedBytes: Int { numTransmittedBits / 9 }
    
    
    /* Reset */
    
    
    func resetAllGenericState() {
        
        lastStartRequestX = nil
        lastStretchingStartX = nil
        lastStretchingTerminationPhaseStartX = nil
    }
    
    
    func resetAllBusRelatedState() {
        
        lastKnownLineLevels = nil
        
        lastLineChangeX = nil
        lastIdleReachedX = nil
        lastStartDetectedX = nil
        lastStopDetectedX = nil
        lastBitSetupStartX = nil
        lastBitClockStartX = nil
        lastBitClockEndX = nil
        lastHoldStartedX = nil
        
        pullingSDA = false
        pullingSCL = false
        
        generatingStart = false
        generatingClock = false
        generatingStop = false
        
        holdingClock = false
        holdingClockTerminationPhase = false
        holdingBus = false
        
        currentBitToTransmit = nil
        lastReadBit = nil
    }
    
    
    func resetAllTransmissionRelatedState() {
        
        betweenStartAndStop = false
        detectedClockRiseSinceStart = false
        numTransmittedBits = 0
    }
    
    
    /* Bus connect */
    
    
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
    
    func detectedSymbol(analysingTransitionFrom before: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel), to after: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel)) -> I2CBusSymbol? {
        
        if before == (SCL: .high, SDA: .high) && after == (SCL: .high, SDA: .low) {
            return .start
        }
        
        if before == (SCL: .high, SDA: .low) && after == (SCL: .high, SDA: .high) {
            return .stop
        }
        
        if before.SCL == .high && after.SCL == .low {
            return .clockFall
        }
        
        if before.SCL == .low && after.SCL == .high {
            return .clockRise
        }
        
        return nil
    }
    
    
    /* Simulation */
    
    
    func reset(x: CGFloat) {
        
        currentX = x
        
        resetAllGenericState()
        resetAllBusRelatedState()
        resetAllTransmissionRelatedState()
        
        txFifo.clear()
        rxFifo.clear()
    }
    
    
    func update(x: CGFloat) {
        
        currentX = x
        
        readLineLevels()
        readExternalControlSignals()
        updateInternalControlSignals()
        updateBusControls()
        applyBusControls()
    }
    
    
    /* Line levels events */
    
    
    func readLineLevels() {
        
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
    
    
    func startCondition() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- detected (RE)START")
        
        generatingStart = false
        betweenStartAndStop = true
        detectedClockRiseSinceStart = false
        numTransmittedBits = 0
        result = .aborted
        generatingClock = started == 1
        started = 1
        lastStartDetectedX = currentX
    }
    
    
    func stopCondition() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- detected STOP")
        
        generatingStop = false
        generatingClock = false
        betweenStartAndStop = false
        num_bytes = numTransmittedBytes
        started = 0
        lastStopDetectedX = currentX
    }
    
    
    func clockFall() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- detected CLOCK FALL")
        
        if betweenStartAndStop {
            
            if detectedClockRiseSinceStart {
                bitClockEnd()
            }
            
            bitSetupStart()
        }
    }
    
    
    func clockRise() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- detected CLOCK RISE")
        
        if betweenStartAndStop {
            
            detectedClockRiseSinceStart = true
            
            bitClockStart()
        }
    }
    
    
    func bitSetupStart() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- bit setup starting - bit \(numTransmittedBits)")
        
        trySetupNextBit(allowStretching: true)
        lastBitSetupStartX = currentX
    }
    
    
    func trySetupNextBit(allowStretching: Bool) {
        
        switch evaluateNextBit() {
        case .ok:
            
            print("")
            print("\(name) \(currentX) - I2CController -- bit success")
            
            assertBit()
            
        case .end:
            
            print("")
            print("\(name) \(currentX) - I2CController -- bit end")
            
            endTransmission()
        
        case .stretch:
            
            print("")
            print("\(name) \(currentX) - I2CController -- bit stretch")
            
            allowStretching ? enterStretching() : endTransmission()
        }
    }
    
    
    enum EvaluateNextBitResult { case ok, end, stretch }
    func evaluateNextBit() -> EvaluateNextBitResult {
        
        return .ok
    }
    
    
    func bitClockStart() {
        
        lastBitClockStartX = currentX
    }
    
    
    func bitClockEnd() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- bit clock end")
        
        sampleBit()
        numTransmittedBits += 1
        
        print("")
        print("\(name) \(currentX) - I2CController -- numTransmittedBits: \(numTransmittedBits)")
        
        lastBitClockEndX = currentX
    }
    
    
    func sampleBit() {
        
        lastReadBit = bus.lineSDA.currentLevel.bit
        
        print("")
        print("\(name) \(currentX) - I2CController -- bit sampled: \(lastReadBit!)")
    }
    
    
    func assertBit() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- asserting bit: \(currentBitToTransmit?.description ?? "-")")
        
        pullingSDA = currentBitToTransmit == .zero
    }
    
    
    func endTransmission() {
        
        if stretching_ongoing == 1 {
            exitStretching()
        }
        generatingClock = false
        if hold_bus == 1 {
            enterHold()
            num_bytes = numTransmittedBytes
            started = 0
        } else {
            generatingStop = true
        }
    }
    
    
    /* Control signals events */
    
    
    func readExternalControlSignals() {
        
        started_risingEdgeDetected = 0
        if started != started_previousValue {
            if started == 1 {
                started_risingEdgeDetected = 1
            }
            started_previousValue = started
        }
        
        stretching_enabled_fallingEdgeDetected = 0
        if stretching_enabled != stretching_enabled_previousValue {
            if stretching_enabled == 0 {
                stretching_enabled_fallingEdgeDetected = 1
            }
            stretching_enabled_previousValue = stretching_enabled
        }
    }
    

    func updateInternalControlSignals() {
        
        if (!betweenStartAndStop || holdingBus) && started_risingEdgeDetected == 1 {
            startRequested()
        }
        
        if (!betweenStartAndStop || holdingBus) && generatingStart && started == 0 {
            startAborted()
        }
        
        if (!betweenStartAndStop || holdingBus) && generatingStart && waitedStartTimeout() {
            startTimeout()
        }
        
        if betweenStartAndStop && holdingClock && !holdingClockTerminationPhase && !txFifo.isEmpty {
            dataAvailable()
        }
        
        if betweenStartAndStop && holdingClock && !holdingClockTerminationPhase && stretching_enabled == 0 {
            stretchingDisabled()
        }
        
        if betweenStartAndStop && holdingClock && !holdingClockTerminationPhase && waitedStretchingTimeout() {
            stretchingTimeout()
        }
        
        if betweenStartAndStop && holdingClock && holdingClockTerminationPhase && waited(after: lastStretchingTerminationPhaseStartX, xBitSetupDuration) {
            exitStretching()
        }
        
        if betweenStartAndStop && holdingBus && hold_bus == 0 {
            holdDisabled()
            
        }
        if betweenStartAndStop && holdingBus && waitedHoldTimeout() {
            holdTimeout()
        }
    }
    
    
    func startRequested() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- start requested by user")
        
        holdingBus = false
        generatingStart = true
        lastStartRequestX = currentX
    }
    
    
    func startTimeout() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- start timeout")
        
        generatingStart = false
        releaseBus()
        result = .timeout
        num_bytes = 0
        started = 0
    }
    
    
    func startAborted() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- start aborted by user")
        
        generatingStart = false
        releaseBus()
        result = .aborted
        num_bytes = 0
        started = 0
    }
    
    
    func enterStretching() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- stretching starting")
        
        holdingClock = true
        generatingClock = false
        lastStretchingStartX = currentX
        stretching_ongoing = 1
    }
    
    
    func enterStretchingTerminationPhase() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- stretching entering termination phase")
        
        lastStretchingTerminationPhaseStartX = currentX
        holdingClockTerminationPhase = true
        
        trySetupNextBit(allowStretching: false)
    }
    
    
    func exitStretching() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- stretching ending")
        
        holdingClock = false
        holdingClockTerminationPhase = false
        generatingClock = true
        stretching_ongoing = 0
    }
    
    
    func dataAvailable() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- data available")
        
        _ = txFifo.pop()
        
        enterStretchingTerminationPhase()
    }
    
    
    func stretchingDisabled() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- stretching disabled by user")
        
        enterStretchingTerminationPhase()
    }
    
    
    func stretchingTimeout() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- stretching timeout")
        
        enterStretchingTerminationPhase()
    }
    
    
    func enterHold() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- hold starting")
        
        holdingBus = true
        generatingClock = false
        lastHoldStartedX = currentX
    }
    
    
    func holdDisabled() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- hold disabled by user")
        
        holdingBus = false
        generatingStop = true
    }
    
    
    func holdTimeout() {
        
        print("")
        print("\(name) \(currentX) - I2CController -- hold timeout")
        
        holdingBus = false
        generatingStop = true
    }
    
    
    /* Bus control */
    
    
    func updateBusControls() {
        
        if generatingStart {
            assertStart()
        }
        
        if generatingClock {
            assertClock()
        }
        
        if generatingStop {
            assertStop()
        }
        
        if holdingClock {
            pullingSCL = true
        }
    }
    
    
    func assertStart() {
        
        if waited(after: lastBitClockEndX, xWaitBeforeEngagingStart),   // restart
           waited(after: lastIdleReachedX, xWaitBeforeEngagingStart),
           waited(after: lastStartRequestX, xWaitBeforeEngagingStart) {
            
            switch bus.currentLineLevels {
            case (SCL: .high, SDA: .low): pullingSCL = true
            case (SCL: .low, SDA: .low): pullingSDA = false
            case (SCL: .low, SDA: .high): pullingSCL = false
            case (SCL: .high, SDA: .high): pullingSDA = true
            }
        }
    }
    
    
    func assertStop() {
        
        if waited(after: lastBitClockEndX, xWaitBeforeEngagingStop) {
            
            switch bus.currentLineLevels {
            case (SCL: .high, SDA: .high): pullingSCL = true
            case (SCL: .low, SDA: .high): pullingSDA = true
            case (SCL: .low, SDA: .low): pullingSCL = false
            case (SCL: .high, SDA: .low): pullingSDA = false
            }
        }
    }
    
    
    func assertClock() {
        
        if bus.lineSCL.isHigh && waitedBitClockDuration() && waitedAfterStart() {
            pullingSCL = true
        }
        if bus.lineSCL.isLow && waitedBitSetupDuration() {
            pullingSCL = false
        }
    }
    
    
    func releaseBus() {
        
        pullingSCL = false
        pullingSDA = false
    }
    

    func applyBusControls() {
        
        if waitedDelayBetweenLineChanges() {
            pullingSDA ? pullSDA() : releaseSDA()
            pullingSCL ? pullSCL() : releaseSCL()
        }
    }
    
    
    /* Waits */
    
    
    func waited(after ref: CGFloat?, _ duration: CGFloat) -> Bool {

        if let ref = ref {
            return (currentX - ref) >= duration
        } else {
            return true
        }
    }
    
    
    func waitedDelayBetweenLineChanges() -> Bool {
        
        return waited(after: lastLineChangeX, xDelayBetweenLineChanges)
    }
    
    
    func waitedStartTimeout() -> Bool {
     
        return waited(after: lastStartRequestX, start_timeout)
    }
    
    
    func waitedAfterStart() -> Bool {
        
        return waited(after: lastStartDetectedX, xWaitAfterStart)
    }
    
    
    func waitedBitSetupDuration() -> Bool {
        
        return waited(after: lastBitSetupStartX, xBitSetupDuration)
    }
    
    
    func waitedBitClockDuration() -> Bool {
        
        return waited(after: lastBitClockStartX, xBitClockDuration)
    }
    
    
    func waitedStretchingTimeout() -> Bool {
        
        return waited(after: lastStretchingStartX, CGFloat(stretching_timeout))
    }
    
    
    func waitedHoldTimeout() -> Bool {
        
        return waited(after: lastHoldStartedX, CGFloat(hold_timeout))
    }
}
