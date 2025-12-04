## TASK-016: Delete Architecture Files and UseCaseAccessors

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 5
**Depends On:** T015
---

### Overview

Delete Architecture infrastructure files (3 files) including UseCaseAccessors which is no longer needed.

**Files:**
- `Sources/App/Common/Architecture/UseCaseAccessors.swift` (delete)
- `Sources/App/Common/Architecture/UseCase.swift` (delete)
- `Sources/App/Common/Architecture/RequestContext.swift` (keep or inline if needed)
- `Sources/App/Common/Architecture/` (delete directory if empty)

### Implementation Steps

**Commit 1: Delete Architecture files**
- [ ] Check if RequestContext is used elsewhere - if so, move to appropriate location
- [ ] Delete UseCaseAccessors.swift
- [ ] Delete UseCase.swift (base protocol)
- [ ] Delete Architecture directory if empty
- [ ] Remove any imports of these files
- [ ] Verify build succeeds
- [ ] Verify all tests pass

### RequestContext Handling

RequestContext may still be useful for logging metadata. Check usage:

```bash
grep -r "RequestContext" Sources/
```

If still used:
- Move to `Common/Extensions/` or `Common/Models/`
- Keep the struct, just relocate it

If not used:
- Delete with other Architecture files

### Success Criteria

- [ ] Build succeeds with no Architecture code
- [ ] All tests pass
- [ ] `grep -r "UseCaseAccessors" Sources/` returns nothing
- [ ] `grep -r "req.useCases" Sources/` returns nothing
- [ ] Architecture/ directory doesn't exist (or only contains relocated files)

### Verification

```bash
swift build
swift test
grep -r "UseCaseAccessors" Sources/
grep -r "req.useCases" Sources/
ls Sources/App/Common/Architecture/ # Should fail or be empty
```

### Notes

- UseCaseAccessors provided `req.useCases.*` - this pattern is now gone
- UseCase protocol is the base protocol for use cases - no longer needed
- RequestContext might be worth keeping for structured logging
