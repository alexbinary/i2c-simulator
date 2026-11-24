
import SwiftUI



extension I2CMasterController {
    
    protocol Interrupts {
        func transmissionStarted()
        func transmissionSuspendStart()
        func transmissionSuspendEnd()
        func dataByteSent()
        func dataByteReceived()
        func transmissionEnded()
    }
}


/// I2C Master Controller
///
/// To start a transmission, first load the address and RW mode into the `address` and `rw` registers,
/// then set the `num_bytes` register to set the number of bytes to write or read.
/// The `num_bytes` register can be updated at any point during the transmission.
/// To start, set the `start` bit to 1. The controller sets the `start` bit to 0 when the transmission is complete.
///
/// When a transmission is complete, the driver can inspect the `transmission_result` register.
/// Possible values are: `success`, `addressNack`, `dataNack`, `error`, `timeout`.
///
/// Use `txFifo` to feed data bytes to be sent to the slave.
/// Use`rxFifo` to read data received from the slave.
///
/// If `txFifo` runs out of data before the configured number of bytes have been sent,
/// transmission stops after the last data ack, unless `stretchingEnabled` is `true`.
/// In that case the controller holds the bus and waits until new data is available in the fifo.
/// As soon as the fifo is no more empty, stretching stops and transmission resumes.
///
/// If `rxFifo` is full before the configured number of bytes have been read,
/// the controller holds the bus before the data ack and waits for the fifo to have at least one byte free.
/// As soon as the fifo is no more full the controller acks the data byte and transmission resumes.
///
/// In both cases, entering the stretching phase starts a timer.
/// If the timer reaches the duration set in the `timeout` register, the transmission is stopped.
/// In the case of a read, the last transmitted byte is nacked before the transmission stops.
///
/// The driver can detect that the controller is waiting on the fifos by polling the fifo state directly.
///
/// Interrupts from the `Interrupts` protocol are triggered on important events to give the driver
/// an opportunity to inspect the controller state without relying on polling.
///
class I2CMasterController: I2CController {
    
    var delegate: Interrupts?
    
    
    init(delegate: Interrupts? = nil) {
        
        self.delegate = delegate
    }
    
    
    override func reset(x: CGFloat) {
    
        
    }
    
    
    override func update(x: CGFloat) {
        
        
    }
}
