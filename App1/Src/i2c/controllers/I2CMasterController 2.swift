
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
    
    
    /* Internal state */
    
    var generatingStart = false
    var generatingClock = false
    var generatingStop = false
    
    var started_previousValue = 0
    var xStartTimeoutRef: CGFloat = 0
    
    let xWaitBeforeStart: CGFloat = 30
    

    override func reset(x: CGFloat) {
    
        generatingStart = false
        generatingClock = false
        generatingStop = false
        
        started_previousValue = 0
        xStartTimeoutRef = 0
    }
    
    
    override func updateBusControls() {
        super.updateBusControls()
        
        if !transmissionOngoing {
            
            if started != started_previousValue {
                
                if started == 1 && started_previousValue == 0 {
                    xStartTimeoutRef = currentX
                    generatingStart = true
                }
                
                started_previousValue = started
            }
            
            if (started == 1 && waited(start_timeout, relativeTo: xStartTimeoutRef)) || generatingStart && started == 0 {
                abort()
            }
            
            if generatingStart {
                generateStart()
            }
        }
        
        if transmissionOngoing {
            
            if generatingClock {
                if bus.lineSCL.isHigh {
                    if waited(xBitClockHighDuration, relativeTo: lastBitClockHighStartX), waitedDelayBetweenLineChanges() {
                        pullingSCL = true
                    }
                }
                if bus.lineSCL.isLow {
                    if waited(xBitClockLowDuration, relativeTo: lastBitClockLowStartX), waitedDelayBetweenLineChanges() {
                        pullingSCL = false
                    }
                }
            }
            
            if generatingStop {
                generateStop()
            }
        }
    }
    
    
    func generateStart() {
        
        if waitedDelayBetweenLineChanges() {
            
            switch bus.currentLineLevels {
            case (SCL: .high, SDA: .low): pullingSCL = true
            case (SCL: .low, SDA: .low): pullingSDA = false
            case (SCL: .low, SDA: .high): pullingSCL = false
            case (SCL: .high, SDA: .high):
                if waited(xWaitBeforeStart, relativeTo: lastIdleReachedX) {
                    pullingSDA = true
                }
            }
        }
    }
    
    
    func generateStop() {
        
        if waitedDelayBetweenLineChanges() {
            
            switch bus.currentLineLevels {
            case (SCL: .high, SDA: .high): pullingSCL = true
            case (SCL: .low, SDA: .high): pullingSDA = true
            case (SCL: .low, SDA: .low): pullingSCL = false
            case (SCL: .high, SDA: .low): pullingSDA = false
            }
        }
    }
    
    
    override func transmissionStarted() {
        super.transmissionStarted()
        
        generatingClock = true
    }
    
    
    override func bitClockPhaseEnded() {
        super.bitClockPhaseEnded()
        
        if numTransmittedBits == 10 {
            
            generatingClock = false
            generatingStop = true
        }
    }
    
    
    override func transmissionStopped() {
        super.transmissionStopped()
        
        generatingStart = false
        generatingStop = false
        
        result = .success
        started = 0
    }
    
    
    func abort() {
        
        transmissionOngoing = false
        generatingStart = false
        generatingStop = false
        
        result = .timeout
        started = 0
    }
}
