
import SwiftUI



extension I2CSlaveController{
    
    protocol Delegate {
        func shouldAcceptTransmission(with address: Byte, mode: ReadWrite) -> Bool
        func transmissionStarted(with address: Byte, mode: ReadWrite) -> ()
        func receivedDataByte(_: Byte) -> ()
        func sentDataByte(_: Byte) -> ()
        func nextDataByteToBeRead() -> Byte?
        func shouldHoldBeforeNextDataByte(mode: ReadWrite) -> Bool
        func shouldAckDataByte() -> Bool
        func transmissionEnded(withResult: TransmissionResult)
    }
}


class I2CSlaveController: I2CController {
    
    
    var transmissionActive = false
    var delegate: Delegate?


    init(delegate: Delegate? = nil) {
        self.delegate = delegate
    }


    override func reset(x: CGFloat) {

        
    }


    override func update(x: CGFloat) {
        
        
    }
}
