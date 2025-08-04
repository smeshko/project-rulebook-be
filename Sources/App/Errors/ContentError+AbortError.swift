import Vapor

extension ContentError: DebuggableError {}
extension ContentError: CustomStringConvertible {}
extension ContentError: CustomDebugStringConvertible {}
extension ContentError: LocalizedError {}
extension ContentError: AppError {}

extension ContentError: AbortError {
    public var status: HTTPResponseStatus {
        .notFound
    }
}
