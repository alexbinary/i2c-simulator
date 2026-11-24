
import SwiftUI



extension I2CMasterController{
    
    protocol Delegate {
        func transmissionStarted() -> ()
        func nextDataByteToWrite() -> Byte?
        func sentDataByte(_ byte: Byte) -> ()
        func receivedDataByte(_ byte: Byte) -> ()
        func shouldContinueReadingDataBytes() -> Bool
        func shouldHoldBeforeNextDataByte() -> Bool
        func transmissionEnded(withResult result: TransmissionResult)
    }
}


class I2CMasterController: I2CController {
    
    var delegate: Delegate?
    
    
    init(delegate: Delegate? = nil) {
        
        self.delegate = delegate
    }
    
    
    override func reset(x: CGFloat) {
    
        
    }
    
    
    override func update(x: CGFloat) {
        
        
    }
}
