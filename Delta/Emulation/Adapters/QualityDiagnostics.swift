import Foundation
import OSLog

/// Correlation uses random operation IDs. Error details remain private in unified logging.
enum QualityDiagnostics
{
    private static let logger = Logger(subsystem: "page.ducnguyen.Delta", category: "EmulationLifecycle")
    static func event(_ name: String, operation: UUID)
    {
        logger.debug("operation=\(operation.uuidString, privacy: .public) event=\(name, privacy: .public)")
    }
    static func failure(_ name: String, error: Error, operation: UUID)
    {
        logger.error("operation=\(operation.uuidString, privacy: .public) event=\(name, privacy: .public) error=\(error.localizedDescription, privacy: .private)")
    }
}
