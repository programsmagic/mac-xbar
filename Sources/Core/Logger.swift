import os.log

public enum LogLevel: Int, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public final class Logger {
    public static let shared = Logger()

    private let subsystem = "com.macxbar.app"
    private let log: OSLog
    private var minimumLevel: LogLevel

    public init(minimumLevel: LogLevel = .info) {
        self.minimumLevel = minimumLevel
        self.log = OSLog(subsystem: subsystem, category: "mac-xbar")
    }

    public func setLevel(_ level: LogLevel) {
        minimumLevel = level
    }

    public func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logIf(.verbose, message, file: file, function: function, line: line)
    }

    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logIf(.debug, message, file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logIf(.info, message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logIf(.warning, message, file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logIf(.error, message, file: file, function: function, line: line)
    }

    private func logIf(_ level: LogLevel, _ message: String, file: String, function: String, line: Int) {
        guard level >= minimumLevel else { return }
        let fileName = (file as NSString).lastPathComponent
        os_log("%{public}@ [%{public}@:%d] %{public}@", log: log, type: level.osLogType, fileName, function, line, message)
    }
}

extension LogLevel {
    var osLogType: OSLogType {
        switch self {
        case .verbose: return .debug
        case .debug: return .debug
        case .info: return .info
        case .warning: return .fault
        case .error: return .error
        }
    }
}