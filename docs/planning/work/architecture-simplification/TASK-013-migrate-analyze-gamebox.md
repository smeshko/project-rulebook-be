## TASK-013: Migrate AnalyzeGameBoxUseCase

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 4
**Depends On:** T012
---

### Overview

Migrate AnalyzeGameBoxUseCase (287 lines) to RulesGenerationController. Contains binary image format detection that must be preserved exactly.

**Files:**
- `Sources/App/Modules/RulesGeneration/Controllers/RulesGenerationController.swift` (modify)
- `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift` (reference, delete later)

### Implementation Steps

**Commit 1: Copy AnalyzeGameBoxUseCase.execute() to controller**
- [ ] Copy entire execute() method body (lines 96-145)
- [ ] Copy processImageData() helper (lines 150-220)
- [ ] Copy performAIAnalysis() helper (lines 223-265)
- [ ] Copy validateResponse() helper (lines 268-286)
- [ ] Update to use `req.services.*` syntax
- [ ] Preserve EXACT binary header detection patterns

### Binary Image Format Detection (CRITICAL)

```swift
// MUST PRESERVE EXACT BYTE SEQUENCES (lines 156-194)
if imageData.count >= 4 {
    let header = imageData.prefix(4)

    // JPEG detection (FFD8FF)
    if header.starts(with: [0xFF, 0xD8, 0xFF]) {
        mimeType = "image/jpeg"
    }
    // PNG detection (89504E47)
    else if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
        mimeType = "image/png"
    }
    // GIF detection (474946)
    else if header.starts(with: [0x47, 0x49, 0x46]) {
        mimeType = "image/gif"
    }
    // WebP detection (RIFF container with WEBP marker)
    else if header.starts(with: [0x52, 0x49, 0x46, 0x46]) {
        if imageData.count >= 12 {
            let webpHeader = imageData.prefix(12)
            if webpHeader[8..<12].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
                mimeType = "image/webp"
            } else {
                throw AIProcessingError.imageFormatInvalid(reason: "Failed to convert data to base64")
            }
        } else {
            throw AIProcessingError.imageFormatInvalid(reason: "Invalid WebP format")
        }
    }
    else {
        throw AIProcessingError.imageFormatInvalid(reason: "Invalid image format")
    }
}
```

### Code Example

```swift
// After migration:
func analyzeGameBox(_ req: Request) async throws -> GameboxRecognition.Response {
    let context = RequestContext(
        logger: req.logger,
        clientIP: req.services.ipExtractor.extract(from: req),
        requestID: req.services.uuidGenerator.generate(),
        timestamp: Date.now
    )

    // Log request
    context.logger.info("Game identification use case initiated", metadata: [
        "client_ip": .string(context.clientIP),
        "image_size": .string("\(request.imageData.count) bytes"),
        "request_id": .string(context.requestID),
        "timestamp": .string(ISO8601DateFormatter().string(from: context.timestamp))
    ])

    let imageData = try req.content.decode(GameboxRecognition.Request.self).imageData

    // Validate image data not empty
    guard !imageData.isEmpty else {
        context.logger.warning("Empty image data provided", metadata: [...])
        throw Abort(.badRequest, reason: "No image data provided")
    }

    // Process image data to base64 with MIME type detection
    let dataURL = try processImageData(imageData, context: context)

    // Invoke LLM for analysis
    let aiResponse = try await performAIAnalysis(dataURL: dataURL, context: context, req: req)

    // Validate response
    let gameboxRecognition = try validateResponse(response: aiResponse, context: context, req: req)

    return Response(gameboxRecognition: gameboxRecognition, analyzedAt: Date.now)
}

// Helper: Process image data with format detection
private func processImageData(_ imageData: Data, context: RequestContext) throws -> String {
    let base64String = imageData.base64EncodedString()
    let mimeType: String

    // Binary header detection (exact bytes from original)
    if imageData.count >= 4 {
        let header = imageData.prefix(4)
        if header.starts(with: [0xFF, 0xD8, 0xFF]) {
            mimeType = "image/jpeg"
        } else if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            mimeType = "image/png"
        } else if header.starts(with: [0x47, 0x49, 0x46]) {
            mimeType = "image/gif"
        } else if header.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            // WebP requires additional check at bytes 8-11
            if imageData.count >= 12 {
                let webpHeader = imageData.prefix(12)
                if webpHeader[8..<12].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
                    mimeType = "image/webp"
                } else {
                    throw AIProcessingError.imageFormatInvalid(reason: "Unrecognized RIFF container")
                }
            } else {
                throw AIProcessingError.imageFormatInvalid(reason: "Invalid WebP format")
            }
        } else {
            throw AIProcessingError.imageFormatInvalid(reason: "Invalid image format")
        }
    } else {
        throw AIProcessingError.imageFormatInvalid(reason: "Insufficient data")
    }

    // Create data URL
    let dataURL = "data:\(mimeType);base64,\(base64String)"

    // Validate image for security
    try req.services.aiInputValidator.validateImageData(dataURL)

    return dataURL
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] JPEG images are detected correctly
- [ ] PNG images are detected correctly
- [ ] GIF images are detected correctly
- [ ] WebP images are detected correctly (including offset check)
- [ ] Invalid formats throw appropriate error
- [ ] LLM analysis returns game identification
- [ ] Response validation works
- [ ] All game box analysis tests pass

### Verification

```bash
swift build
swift test --filter GameBox
swift test --filter Analyze
```

### Notes

- Binary format detection is byte-exact - do not modify hex values
- WebP has special handling (RIFF container + WEBP marker at offset 8)
- Data URL format: `data:{mimeType};base64,{base64String}`
- Image validation happens AFTER data URL creation
