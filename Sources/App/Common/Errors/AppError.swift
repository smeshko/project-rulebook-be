import Vapor

public protocol AppError: AbortError, DebuggableError {}
