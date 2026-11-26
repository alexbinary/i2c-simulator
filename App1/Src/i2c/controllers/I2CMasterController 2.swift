
import SwiftUI



/// I2C Master Controller
///
/// Before starting a transmission, the following registers must be configured:
/// - `address` holds the address of the slave
/// - `rw` holds `0`for write, `1` for read
/// - `num_bytes` holds the number of bytes to transmit
///
/// The transmission starts when the `started` bit is set to `1`.
/// The controller sets the `started` bit back to `0` when the transmission is complete.
///
/// If the bus is busy when the `started` bit is set to `1`, the controller waits until it becomes free.
/// If that doesnt happen within the time configured in `start_timeout`, the transmission is aborted.
///
/// Data bytes to be sent to the slave are read from `txFifo`.
/// If `txFifo` becomes empty before `num_bytes` bytes have been sent,
/// transmission stops after the last data ack, unless `stretching_enabled` is `1`.
/// In that case the controller holds the bus and waits until new data is available in the fifo.
/// As soon as the fifo is not empty, stretching stops and transmission resumes.
///
/// Data bytes received from the slave are pushed into`rxFifo`.
/// If `rxFifo` becomes full before `num_bytes` bytes have been read,
/// the last data byte is nacked and transmission stops, unless `stretching_enabled` is `1`.
/// In that case the controller holds the bus before the data ack and waits for the fifo to have at least one byte free.
/// As soon as the fifo is not full, the controller acks the data byte and transmission resumes.
///
/// Stretching can be detected by polling the `stretching_ongoing` flag:
/// - `1` means stretching is ongoing
/// - `0` means no stretching is active
///
/// An ongoing stretching operation can be interrupted by setting `stretching_enabled` to `0`.
/// Stretching is also interrupted automatically if the time since the stretching started exceeds the duration set in the `stretching_timeout` register.
/// When stretching is interrupted, the transmission resumes as if `stretching_enabled` was `0`.
///
/// When all bytes and acks have been transmitted, the controller sends a STOP, unless `hold_bus` is set to `1`.
/// In that case the controller sets `started` to `0` and holds the bus until a new transmission is started or `hold` is set to `0`.
/// If no transmission is started before `hold_timeout` since the hold started, hold stops and the controller sends a STOP.
///
/// End of transmission can be detected by polling the`started` bit and waiting for it to become `0`.
/// The `result` register contains the status of the completed transmission:
/// - `success` means no error, all bytes transmitted and properly acked
/// - `addressNack` means no slave acked the address byte
/// - `dataNack` means the slave nacked the last data byte (write mode only)
/// - `timeout` means the transmission was unable to start in the alloted time
/// Additionnally, `num_bytes` holds the number of bytes actually transmitted.
///
class I2CMasterController: I2CController {
    
    
    /* Public registers */
    
    var start_timeout: CGFloat = 1000
    
    var hold_bus = 0
    var hold_timeout = 1000
    
    
    /* Configurations */
    
    let xWaitBeforeStart: CGFloat = 30
    let xWaitBeforeStop: CGFloat = 30
    let xWaitAfterStop: CGFloat = 30
    let xBitSetupDuration: CGFloat = 30
    let xBitClockDuration: CGFloat = 30
    
    
    /* Internal generic state */
    
    var started_previousValue = 0
    var stretching_enabled_previousValue = 0
    
    
    /* Internal transmission-related state */
    
    var generatingStart = false
    var generatingClock = false
    var generatingStop = false
    
    var lastStartRequestedX: CGFloat?
    var lastStretchingDisabledX: CGFloat?
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
    }
    
    
    override func updateBusControls() {
        super.updateBusControls()
        
        if !transmissionOngoing {
            
            if started != started_previousValue {
                
                if started == 1 && started_previousValue == 0 {
                    lastStartRequestedX = currentX
                    generatingStart = true
                }
                
                started_previousValue = started
            }
            
            if generatingStart && started == 0 {
                startAborted()
            }
            
            if generatingStart && waited(after: lastStartRequestedX, start_timeout) {
                startTimeout()
            }
            
            if generatingStart {
                assertStart()
            }
        }
        
        if transmissionOngoing {
            
            if stretching_enabled != stretching_enabled_previousValue {
                
                if stretching_enabled == 0 {
                    lastStretchingDisabledX = currentX
                }
                
                stretching_enabled_previousValue = stretching_enabled
            }
            
            if !generatingClock && stretching_enabled == 0,
               waited(after: lastStretchingDisabledX, xBitSetupDuration) {
                generatingClock = true
            }
            
            if generatingClock {
                assertClock()
            }
            
            if generatingStop {
                assertStop()
            }
        }
    }
    
    
    override func resetAllTransmissionRelatedState() {
        super.resetAllTransmissionRelatedState()
        
        generatingStart = false
        generatingClock = false
        generatingStop = false
    }
    
    
    func assertStart() {
        
        if waitedDelayBetweenLineChanges(),
           waitedAfterLastStop(xWaitAfterStop),
           waitedAfterLastBitSetupStart(xBitSetupDuration),
           waited(after: lastStartRequestedX, xWaitBeforeStart) {
            
            switch bus.currentLineLevels {
            case (SCL: .high, SDA: .low): pullingSCL = true
            case (SCL: .low, SDA: .low): pullingSDA = false
            case (SCL: .low, SDA: .high): pullingSCL = false
            case (SCL: .high, SDA: .high): pullingSDA = true
            }
        }
    }
    
    
    func assertStop() {
        
        if waitedDelayBetweenLineChanges(),
           waitedAfterLastBitSetupStart(xBitSetupDuration),
           waited(after: lastBitSetupStartX, xWaitBeforeStop) {
            
            switch bus.currentLineLevels {
            case (SCL: .high, SDA: .high): pullingSCL = true
            case (SCL: .low, SDA: .high): pullingSDA = true
            case (SCL: .low, SDA: .low): pullingSCL = false
            case (SCL: .high, SDA: .low): pullingSDA = false
            }
        }
    }
    
    
    func assertClock() {
        
        if waitedDelayBetweenLineChanges() {
            
            if bus.lineSCL.isHigh {
                if waitedAfterLastBitClockStart(xBitClockDuration),
                   waited(after: lastStartX, xBitClockDuration) {
                    pullingSCL = true
                }
            }
            if bus.lineSCL.isLow {
                if waitedAfterLastBitSetupStart(xBitSetupDuration) {
                    pullingSCL = false
                }
            }
        }
    }
    
    
    override func startCondition() {
        super.startCondition()
        
        generatingClock = true
    }
    
    
    override func bitClockEnded() {
        super.bitClockEnded()
        
        if numTransmittedBits % 4 == 3 {
            if stretching_enabled == 1 {
                generatingClock = false
                stretching_ongoing = 1
            }
        } else if numTransmittedBytes == num_bytes {
            allBytesTransmitted()
        }
    }
    
    
    func allBytesTransmitted() {
        
        result = .success
        generatingClock = false
        if hold_bus == 0 {
            generatingClock = false
            generatingStop = true
        } else {
            started = 0
            resetAllTransmissionRelatedState()
        }
    }
    
    func startTimeout() {
        
        result = .timeout
        started = 0
        resetAllTransmissionRelatedState()
    }
    
    
    func startAborted() {
        
        result = .aborted
        started = 0
        resetAllTransmissionRelatedState()
    }
}
