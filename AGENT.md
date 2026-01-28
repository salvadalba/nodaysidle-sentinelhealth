# Agent Prompts — SENTINEL HEALTH

## 🧭 Global Rules

### ✅ Do
- Use Swift 6 with strict concurrency checking enabled
- Use actors for all shared mutable state
- Use OSLog with 'com.sentinel.health' subsystem for all logging
- Use .ultraThinMaterial/.regularMaterial for all UI surfaces
- Use typed throws with SentinelError enum

### ❌ Don't
- Do not use any server-side code - this is local-first only
- Do not use callbacks - use async/await exclusively
- Do not suspend system-critical processes (Finder, WindowServer, etc.)
- Do not use UIKit or AppKit directly when SwiftUI suffices
- Do not store sensitive process data outside SwiftData

## 🧩 Task Prompts
## Project Foundation and Core Infrastructure

**Context**
Initialize macOS 15+ menu bar app with Swift 6, SwiftUI 6 lifecycle, OSLog infrastructure, and core error handling types.

### Universal Agent Prompt
```
_No prompt generated_
```