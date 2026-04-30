import Foundation
// Assuming SVNCore is your objective-C module name
import SVNCore

// MARK: - SVN Error Handling
public enum SVNError: Error, LocalizedError, CustomStringConvertible {
    case apiError(String)
    
    public var errorDescription: String? {
        switch self {
        case .apiError(let s): return s
        }
    }
    
    // ENHANCEMENT: Conformed to CustomStringConvertible for better console logs
    public var description: String {
        return errorDescription ?? "Unknown SVN Error"
    }
}

public enum SVNDepth {
    case infinity
    case immediates
    case empty
}

// MARK: - Callback Types
public typealias SVNLogCallback = (_ line: String) -> Void
public typealias SVNProgressCallback = (_ processed: Int, _ total: Int) -> Void

// MARK: - File Status & Info
public struct SVNFileStatus {
    public let path: String
    public let status: String
    public init(path: String, status: String) { self.path = path; self.status = status }
}

public struct SVNFileInfo {
    public let name: String
    public let isFolder: Bool
    public let revision: Int
    public let author: String
    public let size: String
    public let date: String
    
    public init(name: String, isFolder: Bool, revision: Int, author: String, size: String, date: String) {
        self.name = name
        self.isFolder = isFolder
        self.revision = revision
        self.author = author
        self.size = size
        self.date = date
    }
}

// MARK: - SVN Executor
public final class SVNExecutor {
    
    public static let shared = SVNExecutor()

    // MARK: Properties
    private let svnWrapper = SVNAPRWrapper()
    private var processed = 0
    private var total = 0
    private var initialized = false
    
    // MARK: - Caching Properties
    private let cacheLock = NSLock()
    private var statusCache: [String: (timestamp: Date, results: [SVNFileStatus])] = [:]
    /// How long (in seconds) the status cache remains valid before requiring a fresh SVN call.
    public var cacheValidityInSeconds: TimeInterval = 10.0
    
    // MARK: Initializer
    private init() {
        do {
            try initializeIfNeeded()
        } catch {
            print("SVN initialization failed: \(error)")
        }
    }
    
    public func initializeIfNeeded() throws {
        guard !initialized else { return }
        let success = svnWrapper.initializeAPRAndSVN()
        if !success {
            throw SVNError.apiError("Couldn't perform atomic initialization")
        }
        initialized = true
    }
    
    private func resetProgress() {
        processed = 0
        total = 0
    }
    
    // MARK: Error Handling
    private func handleResult(_ code: Int, error: String?) throws {
        if code != 0 {
            let friendlyMessage = svnErrorMessage(for: code)
            print("SVN error Code (\(code)): \(friendlyMessage)")
            if let error = error {
                print("SVN detailed error: \(error)")
            }
            throw SVNError.apiError(error ?? friendlyMessage)
        }
    }
    
    // MARK: Helper for log/progress callbacks
    private func makeLogCallback(_ log: SVNLogCallback?, progress: SVNProgressCallback?) -> SVNLogCallback {
        return { [weak self] line in
            guard let self = self else { return }
            log?(line)
            self.processed += 1
            self.total += 1
            progress?(self.processed, self.total)
        }
    }
    
    // MARK: - Abort / Clear Memory for a specific URL
    public func clearMemory(for url: String, at path: String) throws {
        // 1. Reset internal progress state
        resetProgress()
        
        // 2. Attempt to cleanup any partially checked-out working copy
        var errorObj: NSString?
        let cleanupCode = svnWrapper.cleanupPath(path, error: &errorObj)
        if cleanupCode != 0 {
            print("SVN cleanup failed at path \(path), code: \(cleanupCode)")
            if let error = errorObj {
                print("SVN cleanup detailed error: \(error)")
            }
            // Not fatal — we just log it
        } else {
            print("SVN cleanup successful for path: \(path)")
        }
        
        // 3. Delete working copy folder if still exists (fully reset)
        /*let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            do {
                try fileManager.removeItem(atPath: path)
                print("Deleted partial working copy at path: \(path)")
            } catch {
                print("Failed to delete folder \(path): \(error)")
            }
        }*/
        
        // 4. Reset internal wrapper / session (if needed)
        svnWrapper.resetSession(for: url)
        
        print("Memory cleared for URL: \(url)")
    }

    // MARK: Map SVN Error Codes
    public func svnErrorMessage(for code: Int) -> String {
        switch code {
        case -1: return "Unknown SVN error (-1) – possibly network or repository unreachable"
        case 200029: return "Repository access denied (200029) – check permissions or credentials"
        case 170001: return "Authentication failed"
        case 170013: return "Unable to connect to repository"
        case 170000: return "Invalid repository"
        case 210005: return "Permission denied"
        // ENHANCEMENT: Added more common SVN error codes to the map
        case 160028: return "Working copy is locked; please run cleanup"
        case 155004: return "Working copy is locked"
        case 155007: return "Path is not a working copy"
        default: return "SVN Error code \(code)"
        }
    }
    
    // MARK: - SVN Operations (Synchronous)
    
    // UPDATE
    public func update(path: String, username: String, password: String,
                       log: SVNLogCallback? = nil, progress: SVNProgressCallback? = nil) throws {
        resetProgress()
        var errorObj: NSString?
        let code = svnWrapper.updatePath(path, username: username, password: password,
                                         log: makeLogCallback(log, progress: progress), error: &errorObj)
        try handleResult(Int(code), error: errorObj as String?)
    }
    
    // Add this inside SVNExecutor
    func getDiff(path: String, username: String, password: String) throws -> String {
        // Assuming you have a standard Process/Command runner setup in your executor
        let arguments = ["diff", path, "--username", username, "--password", password, "--non-interactive", "--trust-server-cert"]
        
        // Replace this with your actual command execution method
        let output = "new"
        //try runCommand("svn", arguments: arguments)
             return output
    }
    
    
    // STATUS
    // STATUS (Enhanced with Caching and Depth)
        public func status(
            path: String,
            username: String,
            password: String,
            depth: SVNDepth = .immediates, // Defaults to immediates for performance
            verbose: Bool = false,
            forceRefresh: Bool = false,
            log: SVNLogCallback? = nil
        ) throws -> [SVNFileStatus] {
            
            // 1. Check the Cache First (Thread-Safe)
            cacheLock.lock()
            if !forceRefresh, let cached = statusCache[path], Date().timeIntervalSince(cached.timestamp) < cacheValidityInSeconds {
                let cachedResults = cached.results
                cacheLock.unlock()
                //print("⚡️ Returned SVN status from cache for \(path)")
                return cachedResults
            }
            cacheLock.unlock()

            // 2. Convert Swift Depth to SVN C-API Int
            let svnDepthValue: Int32 = {
                switch depth {
                case .empty: return 0          // svn_depth_empty
                case .immediates: return 1     // svn_depth_immediates
                case .infinity: return 3       // svn_depth_infinity
                }
            }()

            var errorObj: NSString?
            var results: [SVNFileStatus] = []
            let callback: SVNLogCallback = { line in
                guard !line.isEmpty else { return }
                if verbose {
                    // Verbose format: status (1) + spaces + working_rev + space + repo_rev + space + user + space + path
                    // e.g., "       123   456 user file.txt"
                    // or "M      123   456 user file.txt"
                    let parts = line.split(separator: " ", omittingEmptySubsequences: false)
                    guard parts.count >= 5 else { return }
                    let statusChar = parts[0].isEmpty ? " " : String(parts[0])
                    let path = parts.suffix(from: 4).joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    results.append(SVNFileStatus(path: path, status: statusChar))
                } else {
                    // Non-verbose: status + 7 spaces + path
                    guard line.count >= 8 else { return }
                    let statusChar = String(line.prefix(1))
                    let filePath = line.dropFirst(8).trimmingCharacters(in: .whitespaces)
                    results.append(SVNFileStatus(path: filePath, status: statusChar))
                }
                log?(line)
            }
            
            let cPath = path.withCString { String(cString: $0) }
            print("Passing to C-Wrapper: \(cPath)")
            // 3. Perform the actual SVN call
            let code = svnWrapper.statusPath(
                cPath,
                depth: Int(svnDepthValue),
                verbose: verbose,
                username: username,
                password: password,
                log: callback,
                error: &errorObj
            )
            
            try handleResult(Int(code), error: errorObj as String?)
            
            // 4. Save the new results to the Cache
            cacheLock.lock()
            statusCache[path] = (timestamp: Date(), results: results)
            cacheLock.unlock()
            
            return results
        }
    
    // LIST DETAILED
    public func listDetailed(url: String, username: String, password: String,
                             log: SVNLogCallback? = nil) throws -> [SVNFileInfo] {
        var errorObj: NSString?
        var collectedItems: [SVNFileInfo] = []
        
        // ENHANCEMENT: Protect concurrent array writes from Obj-C async callbacks
        let queue = DispatchQueue(label: "com.svnexecutor.listdetailed.safesync")
        
        let callback: SVNLogCallback = { line in
            let parts = line.split(separator: "|", maxSplits: 6, omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 6 else { log?(line); return }
            let revision = Int(parts[0]) ?? 0
            let author   = parts[1]
            let date     = parts[2]
            let size     = parts[3]
            let name     = parts[4]
            let kind     = parts[5].trimmingCharacters(in: .whitespacesAndNewlines)
            let isFolder = (kind == "dir")
            
            queue.sync {
                collectedItems.append(SVNFileInfo(name: name, isFolder: isFolder, revision: revision, author: author, size: size, date: date))
            }
            log?(line)
        }
        let code = svnWrapper.listDetailed(url, username: username, password: password, log: callback, error: &errorObj)
        try handleResult(Int(code), error: errorObj as String?)
        
        return queue.sync { collectedItems }
    }
    
    // COMMIT
    /*public func commit(path: String, message: String, username: String, password: String,
                       log: SVNLogCallback? = nil) throws {
        resetProgress()
        var errorObj: NSString?
        let logCallback: SVNLogCallback = { line in log?(line) }
        let canonicalPath = URL(fileURLWithPath: path).path
        print("🚀 Committing Canonical Path: \(canonicalPath)")
        let code = svnWrapper.commitPath(canonicalPath, message: message, username: username, password: password,
                                         log: logCallback, error: &errorObj)
        try handleResult(Int(code), error: errorObj as String?)
    }*/
    
    
    // COMMIT (Paths handling fix)
    // COMMIT
    public func commit(path: String, message: String, username: String, password: String,
                       log: SVNLogCallback? = nil) throws {
        resetProgress()
        var errorObj: NSString?
        let logCallback: SVNLogCallback = { line in log?(line) }
        let code = svnWrapper.commitPath(path, message: message, username: username, password: password,
                                         log: logCallback, error: &errorObj)
        try handleResult(Int(code), error: errorObj as String?)
    }
    
    // MARK: - LOCK
    public func lock(
        path: String,
        comment: String = "Locked via MacSVN Pro",
        force: Bool = false,
        username: String,
        password: String
    ) throws {
        // 1. Reset progress as this is a new operation
        resetProgress()
        var errorObj: NSString?
        
        // 2. Sanitize the path for the C-library (as we did for status/commit)
        let canonicalPath = URL(fileURLWithPath: path).path
        //print("🔒 Requesting SVN Lock for: \(canonicalPath)")

        // 3. Call the Objective-C wrapper
        // Note: If your Obj-C method doesn't take 'force' yet, remove it from the call
        let code = svnWrapper.lockPath(
            canonicalPath,
            comment: comment,
            username: username,
            password: password,
            error: &errorObj
        )

        // 4. Handle the result using your existing helper
        try handleResult(Int(code), error: errorObj as String?)
        
        print("✅ Lock acquired successfully for: \(path)")
    }
    
    // CHECKOUT (Depth + Revision Support)
    public func checkout(
        url: String,
        to path: String,
        username: String,
        password: String,
        depth: SVNDepth = .infinity,
        revision: Int? = nil,
        log: SVNLogCallback? = nil
    ) throws {

        resetProgress()
        var errorObj: NSString?
        let logCallback: SVNLogCallback = { line in log?(line) }

        var checkedOutRevision: Int = 0

        let svnDepthValue: Int32 = {
            switch depth {
            case .empty: return 0          // svn_depth_empty
            case .immediates: return 1     // svn_depth_immediates
            case .infinity: return 3       // svn_depth_infinity
            }
        }()

        let code = svnWrapper.checkoutURL(
            url,
            toPath: path,
            username: username,
            password: password,
            log: logCallback,
            revision: revision ?? -1,
            depth: Int(svnDepthValue),
            revisionOut: &checkedOutRevision,
            error: &errorObj
        )

        print("Checked out revision: \(checkedOutRevision)")
        try handleResult(Int(code), error: errorObj as String?)
    }

    // ADD
    public func add(path: String, username: String, password: String, message: String? = nil,
                    log: SVNLogCallback? = nil, progress: SVNProgressCallback? = nil) throws {
        resetProgress()
        var errorObj: NSString?
        let logCallback: SVNLogCallback = { line in
            log?(line)
            self.processed += 1
            self.total += 1
            progress?(self.processed, self.total)
        }
        let code = svnWrapper.addPath(path, message: message, username: username, password: password,
                                      log: logCallback, error: &errorObj)
        try handleResult(Int(code), error: errorObj as String?)
    }
    
    // ADD BATCH
    public func addBatch(
        paths: [String],
        username: String,
        password: String,
        log: SVNLogCallback? = nil,
        progress: SVNProgressCallback? = nil
    ) throws {

        guard !paths.isEmpty else { return }

        resetProgress()

        var errorObj: NSString?

        let logCallback: SVNLogCallback = { line in
            log?(line)

            self.processed += 1
            self.total += 1

            progress?(self.processed, self.total)
        }

        let code = svnWrapper.addBatch(
            paths,
            username: username,
            password: password,
            log: logCallback,
            error: &errorObj
        )

        try handleResult(Int(code), error: errorObj as String?)
    }
    
    // DELETE
    public func delete(path: String,
                       username: String,
                       password: String,
                       message: String? = nil,
                       log: SVNLogCallback? = nil) throws {

        resetProgress()

        var errorObj: NSString?
        let logCallback: SVNLogCallback = { line in log?(line) }

        let code = svnWrapper.deletePath(
            path,
            message: message,
            username: username,
            password: password,
            log: logCallback,
            error: &errorObj
        )

        try handleResult(Int(code), error: errorObj as String?)
    }
    
    //NEW Delete
    public func deleteBatch(paths: [String],
                            username: String,
                            password: String,
                            message: String,
                            log: SVNLogCallback? = nil) throws {

        guard !paths.isEmpty else { return }

        resetProgress()

        var errorObj: NSString?

        let logCallback: SVNLogCallback = { line in
            log?(line)
        }

        let code = svnWrapper.deletePaths(
            paths,
            message: message,
            username: username,
            password: password,
            log: logCallback,
            error: &errorObj
        )

        try handleResult(Int(code), error: errorObj as String?)
    }
    
    
    
    // MARK: - ENHANCEMENT: Async / Await Wrappers for Non-Blocking execution
    // These wrappers dispatch the heavy C-calls to a background queue automatically so your Mac app UI doesn't freeze.
    
    public func checkoutAsync(url: String, to path: String, username: String, password: String, depth: SVNDepth = .infinity, revision: Int? = nil, log: SVNLogCallback? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.checkout(url: url, to: path, username: username, password: password, depth: depth, revision: revision, log: log)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func updateAsync(path: String, username: String, password: String, log: SVNLogCallback? = nil, progress: SVNProgressCallback? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.update(path: path, username: username, password: password, log: log, progress: progress)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
   
    
    public func listDetailedAsync(url: String, username: String, password: String, log: SVNLogCallback? = nil) async throws -> [SVNFileInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.listDetailed(url: url, username: username, password: password, log: log)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
