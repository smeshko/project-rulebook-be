@testable import App
import Vapor

extension Application.Service.Provider where ServiceType == RandomGeneratorService {
    static func rigged(value: String) -> Self {
        .init {
            $0.services.randomGenerator.use { RiggedRandomGeneratorService(app: $0, value: value) }
        }
    }
}

class RiggedRandomGeneratorService: RandomGeneratorService {
    let app: Application?
    let value: String
    private let values: [String]
    private var valueIndex = 0
    
    init(app: Application, value: String) {
        self.app = app
        self.value = value
        self.values = [value]
    }
    
    /// Test-only constructor with single value
    init(value: String) {
        self.app = nil
        self.value = value
        self.values = [value]
    }
    
    /// Test-only constructor with multiple values (will rotate through them)
    init(values: [String]) {
        self.app = nil
        self.value = values.first ?? ""
        self.values = values
    }
    
    func generate(bits: Int) -> String {
        if values.count == 1 {
            return value
        }
        
        let currentValue = values[valueIndex % values.count]
        valueIndex += 1
        return currentValue
    }
    
    func `for`(_ request: Request) -> RandomGeneratorService {
        if app != nil {
            return RiggedRandomGeneratorService(app: request.application, value: value)
        } else if values.count == 1 {
            return RiggedRandomGeneratorService(value: value)
        } else {
            return RiggedRandomGeneratorService(values: values)
        }
    }
}