import Foundation

/// SwiftData model for body fat percentage data.
@Observable public final class BodyFatPercentage: HealthData, @unchecked Sendable {
    public let id: UUID
    public let source: DataSource
    public var date: Date

    /// Body fat value in percentage points (0...100).
    public var percentage: Double

    public init(
        _ percentage: Double,
        id: UUID = UUID(),
        source: DataSource = .app,
        date: Date = Date(),
    ) {
        self.percentage = percentage

        self.id = id
        self.source = source
        self.date = date
    }

    public convenience init() {
        self.init(0)
    }
}
