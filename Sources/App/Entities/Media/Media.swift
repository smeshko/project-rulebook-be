import Foundation

public enum Media {}

public extension Media {
    enum `Type`: String, Codable, Equatable, Sendable {
        case photo, video
    }
    
    enum Size: String, Codable, Equatable, Sendable {
        case s = "small"
        case m = "medium"
        case o = "original"
    }
    
    enum Upload {
        public struct Request: Codable, Equatable, Sendable {
            public let data: Data
            public let ext: String
            public let type: `Type`
            
            public init(
                data: Data,
                ext: String,
                type: `Type`
            ) {
                self.data = data
                self.ext = ext
                self.type = type
            }
        }
        
        public struct Response: Codable, Equatable, Sendable {
            public let id: UUID
            public let type: `Type`

            public init(
                id: UUID,
                type: `Type`
            ) {
                self.id = id
                self.type = type
            }
        }
    }
    
    enum Download {
        public struct Request: Codable, Equatable, Sendable {
            public let id: UUID
            public let size: Size
            
            public init(
                id: UUID,
                size: Size
            ) {
                self.id = id
                self.size = size
            }
        }
        
        public struct Response: Codable, Equatable, Sendable {
            public let data: Data
            
            public init(data: Data) {
                self.data = data
            }
        }
    }
}
