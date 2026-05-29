# Project Overview

HealthVaults is an iOS application built with SwiftUI and SwiftData, integrated with Apple HealthKit to track and display user health metrics. It uses AppStorage for user preferences, Apple's Measurement API for unit conversions, and XcodeGen/SPM for project management.

## Architecture & Data Flow

- **HealthKit**: Source-of-truth for externally generated metrics.
- **SwiftData**: Local store for app-created entries.
- **Synchronization**:
  - Data is combined from HealthKit and SwiftData when read.
  - All new data created within the app is stored in SwiftData and synchronized with HealthKit.
  - SwiftData is the source of truth for app-generated data.
- **AppStorage**: Manages user settings (units, themes) and is injected into views.
- **Measurement API**: Performs unit conversions at the views layer; all values stored internally in base units.

## Project Guidelines

- `Models/` contains data structures and protocols/interfaces.
- `Services/` contains implementations and business logic.
   - Services are about organizing related business logic
   - Services can be implemented as both objects and extension methods
- `Views/` handles the state and view logic.

- **ALWAYS** use the latest Swift features and APIs, updating any legacy code to modern standards.
- **ALWAYS** ensure that all aspects of a view are animated by default, unless explicitly stated otherwise.
- **ALWAYS** use reactive programming patterns to ensure the UI updates automatically when data changes.
- You can't run the project directly. You can only build it with `./Scripts/build [-d]`. **DON'T** use any VSCode tasks.

## Scope Rules (Solo Side Project)

This is a one-person side project. Every piece of work must be reviewable, understandable, and maintainable by a single developer in limited time.

1. **Minimize deliverables.** Solve a problem with one file, not three. One notebook, not a suite. Prefer extending an existing file over creating a new one.
2. **No duplication across languages.** Logic lives in one place. Python model mirrors Swift, but tests and scenarios stay in Swift. Don't rebuild test suites in Python.
3. **Every artifact must justify itself.** Before creating a file, chart, or abstraction — ask: will the developer use this more than once? If not, don't build it.
4. **Keep notebooks disposable.** Notebooks are scratchpads for investigating specific questions, not permanent documentation. A few starter cells, then add as needed.
5. **Scope each task tightly.** Propose the smallest change that solves the stated problem. If more is needed, ask first.
6. **Don't pre-build phases.** Only work on what's immediately needed. Future phases are notes, not work items.

## Core Assistant Guidelines

1. **Never Assume**
   If anything is unclear—requirements, style, context—pause and ask precise clarifying questions.

2. **Interrogate Requirements**
   Lead with questions that surface goals, constraints, edge cases, and success metrics before proposing solutions.

3. **Persistent Notes**
   Use `REVIEW.md` as your knowledge base of the project.
   Track any information that will help you better work on the project.
   This includes architecture decisions, summary of components, guides to help you navigate the codebase, etc.
   The file is to be read and updated with every interaction.
   It will be provided with every new session, keep it concise.
   With each new task, cleanup the file before proceeding.

4. **Self-Verification**
   When appropriate, include quick self-checks (e.g., sample inputs/outputs, minimal tests) to validate your proposals.

5. **Collaboration**
   Be concise and focused. Avoid unnecessary verbosity. Always keep the user in the loop with relevant context.
   The user is your collaborator; work together to solve problems.
