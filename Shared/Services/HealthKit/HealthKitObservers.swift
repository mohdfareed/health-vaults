import Foundation
import HealthKit
import WidgetKit

// MARK: Observer Management
// ============================================================================

extension HealthKitService {
    /// Start observing HealthKit data changes for a specific widget
    public func startObserving(
        for widgetKind: String, dataTypes: [HealthKitDataType],
        from startDate: Date, to endDate: Date,
        onUpdate: @escaping @Sendable () -> Void
    ) {
        guard Self.isAvailable else { return }

        // Stop any existing observers for this widget
        stopObserving(for: widgetKind)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: endDate
        )

        for dataType in dataTypes {
            registerSingleObserver(
                for: widgetKind, dataType: dataType,
                predicate: predicate,
                from: startDate, to: endDate,
                onUpdate: onUpdate
            )
        }
    }

    /// Register a single observer for one data type. Used both for initial setup
    /// and for retry — only touches the specific observer key, never siblings.
    private func registerSingleObserver(
        for widgetKind: String, dataType: HealthKitDataType,
        predicate: NSPredicate,
        from startDate: Date, to endDate: Date,
        onUpdate: @escaping @Sendable () -> Void
    ) {
        let observerKey = observerKey(for: widgetKind, dataType: dataType)

        // Stop only this specific observer if it already exists
        stopSingleObserver(key: observerKey)

        // Reset retry count for fresh observer setup
        observerQueue.sync { observerRetryCounts[observerKey] = 0 }

        let observer = HKObserverQuery(
            sampleType: dataType.sampleType,
            predicate: predicate
        ) { [weak self] query, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }

            if let error = error {
                self.logger.error(
                    "Observer error for \(observerKey): \(error)"
                )

                // Retry with exponential backoff, capped at maxObserverRetries
                let retryCount = self.observerQueue.sync {
                    self.observerRetryCounts[observerKey] ?? 0
                }

                if retryCount < self.maxObserverRetries {
                    self.observerQueue.sync {
                        self.observerRetryCounts[observerKey] = retryCount + 1
                    }
                    let delay = 5.0 * pow(3.0, Double(retryCount))  // 5s, 15s, 45s
                    self.logger.warning(
                        "Retrying observer \(observerKey) in \(delay)s (attempt \(retryCount + 1)/\(self.maxObserverRetries))"
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        // Restart only the failed observer, not all siblings.
                        // Rebuild the NSPredicate here to avoid capturing a non-Sendable
                        // value across the @Sendable closure boundary.
                        let freshPredicate = HKQuery.predicateForSamples(
                            withStart: startDate, end: endDate
                        )
                        self.registerSingleObserver(
                            for: widgetKind, dataType: dataType,
                            predicate: freshPredicate,
                            from: startDate, to: endDate,
                            onUpdate: onUpdate
                        )
                    }
                } else {
                    self.logger.error(
                        "Observer \(observerKey) failed after \(self.maxObserverRetries) retries, giving up"
                    )
                }
                completionHandler()
                return
            }

            // Reset retry count on successful callback
            self.observerQueue.sync {
                self.observerRetryCounts[observerKey] = 0
            }

            self.logger.debug(
                "HealthKit data changed for \(observerKey)"
            )

            // Trigger widget update on main queue
            DispatchQueue.main.async {
                onUpdate()
            }
            completionHandler()
        }

        observerQueue.sync {
            activeObservers[observerKey] = observer
        }
        self.store.execute(observer)

        logger.info("Started observing: \(observerKey)")
    }

    /// Stop a single observer by its exact key (does not affect siblings).
    private func stopSingleObserver(key: String) {
        observerQueue.sync {
            if let observer = activeObservers.removeValue(forKey: key) {
                self.store.stop(observer)
                observerRetryCounts.removeValue(forKey: key)
                logger.info("Stopped observer: \(key)")
            }
        }
    }

    /// Stop observing HealthKit data changes for a specific widget
    public func stopObserving(for widgetKind: String) {
        observerQueue.sync {
            let observersToRemove = activeObservers.filter { key, _ in
                key.hasPrefix("\(widgetKind)_")
            }

            for (key, observer) in observersToRemove {
                self.store.stop(observer)
                activeObservers.removeValue(forKey: key)
                observerRetryCounts.removeValue(forKey: key)
                logger.info("Stopped observer: \(key)")
            }
        }
    }

    /// Get the observer key for a specific widget and data type
    func observerKey(
        for widgetKind: String, dataType: HealthKitDataType
    ) -> String { "\(widgetKind)_\(dataType.sampleType.identifier)" }
}
