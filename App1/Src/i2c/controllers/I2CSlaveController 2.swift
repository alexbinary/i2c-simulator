
import SwiftUI



/// I2C Slave Controller
///
/// Reveived data bytes are push into `rxFifo`.
/// Data to be read by the master are popped from `txFifo`.
///
/// If `rxFifo` becomes full, and `stretching_enabled` is `false`,
/// the last data byte is nacked.
///
/// If `rxFifo` becomes full, and `stretching_enabled` is `true`,
/// transmission is suspended before the last data byte ack,
/// and the controller waits for more data to be available in the fifo.
/// As soon as the fifo is not more full, the last byte is acked and the transmission resumes.
///
/// If `txFifo` becomes empty and the master is still reading (still acks the data bytes),
/// if `stretching_enabled` is `false` then `0xFF` is sent.
/// if `stretching_enabled` is `true` then transmission is suspended
/// and the controller waits until more data becomes available.
///
/// If a master initiates a transmission in read mode and the `txFifo` is empty at the moment of the address ack,
/// the controller nacks the address, unless `stretching_enabled` is `1`.
/// In that case the controller waits until data is available to ack the address.
///
/// Entering the stretching phase starts a timer.
/// If the timer reaches the duration set in the `timeout` register, the transmission resumes as if `stretching_enabled` was `0`.
/// In the case of a read, `0xFF` is sent and if the fifo is still empty after that, a new stretching phase is entered.
///
/// When a transmission is suspended, `stretching_enabled` can be set to `0` to end the stretching phase.
///
/// The driver can detect that the controller is waiting on the fifos by polling the fifo state directly.
/// The `started` bit is set to `1` when a transmission starts, and `0` when a transmission stops.
///
/// The slave controller can be configured to respond to multiple addresses.
/// Set all the addresses you want in the `addresses` registers (up to 128 addresses), and set the `num_addresses` register.
/// The controller always accepts transmissions that match the configured addresses, unless the transmission is a read and no tx data is available.
///
class I2CSlaveController: I2CController {


    override init() {
        
    }


    override func reset(x: CGFloat) {

    }


    override func update(x: CGFloat) {
                
    }
}
