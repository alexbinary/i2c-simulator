
import SwiftUI



/// I2C Slave Controller
///
/// When a transmission starts the controller sets the`started` bit to `1`, and sets it back to `0` when a transmission stops.
///
/// For the controller to accept transmissions, at least one address must be configured in the `slave_addresses` registers.
/// Up to `128` different addresses can be configured in the register span, and the `slave_last_address_index` register
/// must be set to the appropriate value (`0` for one address, etc).
///
/// The controller always accepts reads and write transmissions that match the configured addresses,
/// unless the transmission is a read, no tx data is available, and stretching is disabled (see below).
///
/// As soon as they are received, the address and rw mode are written to the `address` and `rw` registers.
///
/// Data bytes reveived from the master are push into `rxFifo`.
/// If the rx fifo becomes full and `stretching_enabled` is `false`, the last data byte is nacked.
/// If the rx fifo becomes full, and `stretching_enabled` is `true`, transmission is suspended before the last data byte ack,
/// and the controller waits for more data to be available in the fifo.
/// As soon as the fifo is not full, the last byte is acked and the transmission resumes.
///
/// Data bytes to be read by the master are popped from `txFifo`.
/// If `txFifo` becomes empty and the master is still reading (acked the last data byte),
/// if `stretching_enabled` is `false` then `0xFF` is sent.
/// if `stretching_enabled` is `true` then transmission is suspended and the controller waits until more data becomes available.
/// This repeats after each byte.
///
/// If `txFifo` is empty at the moment of the address ack, the controller nacks the address unless `stretching_enabled` is `1`.
/// In that case the controller waits until data is available to ack the address.
///
/// A nack at the address ends the transmission, unless `slave_spy_mode` is set to `1`.
/// In spy mode the controller listes passively to the transmission till the end, pushing transmitted bytes to the `rxFifo`.
/// In spy mode, if the rx fifo is full, the controller wont hold the bus unless `slave_spy_mode_stretching_enabled` is `true`.
/// Note that in spy mode the controller cannot force nack data bytes, so if transmission resumed with the rx fifo still full data will be lost.
///
/// Stretching can be detected by polling the `stretching_ongoing` flag:
/// - `1` means stretching is ongoing
/// - `0` means no stretching is active
///
/// An ongoing stretching operation can always be interrupted by setting `stretching_enabled` to `0`.
/// Stretching is also interrupted automatically if the time since the stretching started exceeds the duration set in the `stretching_timeout` register.
/// When stretching is interrupted, the transmission resumes as if `stretching_enabled` was `0`.
///
/// End of transmission can be detected by polling the`started` bit and waiting for it to become `0`.
/// The `result` register contains the status of the completed transmission:
/// - `success` means no error, all bytes transmitted and properly acked
/// - `addressNack` means the address byte was nacked
/// - `dataNack` means the slave nacked the last data byte (write mode only)
/// Additionnally, `num_bytes` holds the number of bytes actually transmitted.
///
class I2CSlaveController: I2CController {

    
    override func evaluateNextBit(canStretch: Bool) -> EvaluateNextBitResult {
        
        if transmittingAddressByte {
            currentBitToWrite = nil
            return .ok
        }
        
        if transmittingAddressAck {
            
            let addressMatch: Bool = {
                for i in 0...slave_last_address_index {
                    if slave_addresses[i] == address {
                        
                        debugPointAtCurrentX(.green, "matched address: \(address)")
                        return true
                    }
                }
                debugPointAtCurrentX(.green, "no match for address: \(address)")
                return false
            }()
            
            currentBitToWrite = Ack(ackIf: addressMatch).bit
            return .ok
        }
        
        if transmittingDataByte && rw == .writeToSlave {
            currentBitToWrite = nil
            return .ok
        }
        
        if transmittingDataByte && rw == .readFromSlave {
            
            if currentBitInByte == 0 {
                
                if lastAck == .nack {
                    currentBitToWrite = nil
                    return .ok
                }
                
                if txFifo.isEmpty && canStretch {
                    return .stretch
                }
                
                currentByteToWrite = txFifo.isEmpty ? 0xFF : txFifo.pop()
            }
            
            currentBitToWrite = currentByteToWrite!.bit(atTransmissionIndex: currentBitInByte)
            return .ok
        }
        
        if transmittingDataAck && rw == .writeToSlave {
            
            if rxFifo.isFull && canStretch {
                return .stretch
            }
            
            if rxFifo.isFull {
                currentBitToWrite = .nack
                return .ok
            }
            
            rxFifo.push(currentTransmittingByte!)
            
            currentBitToWrite = .ack
            return .ok
        }
        
        if transmittingDataAck && rw == .readFromSlave {
            currentBitToWrite = nil
            return .ok
        }
        
        fatalError("invalid code path")
    }
}
