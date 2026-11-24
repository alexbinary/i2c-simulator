
import SwiftUI



/// I2C Master Controller
///
/// To start a transmission, first load the address and RW mode into the `address` and `rw` registers,
/// then set the `num_bytes` register to set the number of bytes to write or read.
/// The `num_bytes` register can be updated at any point during the transmission.
/// To start, set the `started` bit to `1`. The controller sets the `started` bit to `0` when the transmission is complete.
///
/// When a transmission is complete, the driver can inspect the `transmission_result` register.
/// Possible values are: `success`, `addressNack`, `dataNack`, `error`, `timeout`.
///
/// Data bytes to be sent to the slave are read from `txFifo`.
/// Data bytes received from the slave are pushed into`rxFifo`.
///
/// If `txFifo` runs out of data before the configured number of bytes have been sent,
/// transmission stops after the last data ack, unless `stretching_enabled` is `1`.
/// In that case the controller holds the bus and waits until new data is available in the fifo.
/// As soon as the fifo is no more empty, stretching stops and transmission resumes.
///
/// If `rxFifo` is full before the configured number of bytes have been read,
/// the last data byte is nacked and transmission stops, unless `stretching_enabled` is `1`.
/// In that case transmission is suspended before the data ack and the controller waits for the fifo to have at least one byte free.
/// As soon as the fifo is no more full the controller acks the data byte and transmission resumes.
///
/// Entering the stretching phase starts a timer.
/// If the timer reaches the duration set in the `timeout` register, the transmission resumes as if `stretching_enabled` was `0`.
///
/// When a transmission is suspended, setting `stretching_enabled` to `0` ends the stretching phase.
///
/// The driver can detect that the controller is waiting on the fifos by polling the fifo state directly.
///
class I2CMasterController: I2CController {
    
    
    override init() {
        
    }
    
    
    override func reset(x: CGFloat) {
    
    }
    
    
    override func update(x: CGFloat) {
        
    }
}
