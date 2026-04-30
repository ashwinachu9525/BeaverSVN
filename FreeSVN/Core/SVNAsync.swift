//
//  SVNAsync.swift
//  FreeSVN
//
//  Created by Aswin K on 01/04/26.
//
import Foundation

public final class SVNAsync {
    
    public static let shared = SVNAsync()
    
    private let executor = SVNExecutor.shared
    
    private let queue = DispatchQueue(
        label: "com.freesvn.async",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    private init() {}
    
    // MARK: - CHECKOUT
    
    public func checkout(
        url: String,
        to path: String,
        username: String,
        password: String,
        depth: SVNDepth = .infinity,
        revision: Int? = nil,
        log: SVNLogCallback? = nil
    ) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            
            queue.async {
                
                do {
                    try self.executor.checkout(
                        url: url,
                        to: path,
                        username: username,
                        password: password,
                        depth: depth,
                        revision: revision,
                        log: log
                    )
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - UPDATE
    
    public func update(
        path: String,
        username: String,
        password: String,
        log: SVNLogCallback? = nil,
        progress: SVNProgressCallback? = nil
    ) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            
            queue.async {
                
                do {
                    try self.executor.update(
                        path: path,
                        username: username,
                        password: password,
                        log: log,
                        progress: progress
                    )
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - STATUS
    
    public func status(
        path: String,
        username: String,
        password: String,
        depth: SVNDepth = .immediates,
        verbose: Bool = false,
        forceRefresh: Bool = false,
        log: SVNLogCallback? = nil
    ) async throws -> [SVNFileStatus] {
        
        try await withCheckedThrowingContinuation { continuation in
            
            queue.async {
                
                do {
                    
                    let result = try self.executor.status(
                        path: path,
                        username: username,
                        password: password,
                        depth: depth,
                        verbose: verbose,
                        forceRefresh: forceRefresh,
                        log: log
                    )
                    
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - LIST
    
    public func listDetailed(
        url: String,
        username: String,
        password: String,
        log: SVNLogCallback? = nil
    ) async throws -> [SVNFileInfo] {
        
        try await withCheckedThrowingContinuation { continuation in
            
            queue.async {
                
                do {
                    
                    let result = try self.executor.listDetailed(
                        url: url,
                        username: username,
                        password: password,
                        log: log
                    )
                    
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - COMMIT
    
    public func commit(
        path: String,
        message: String,
        username: String,
        password: String,
        log: SVNLogCallback? = nil
    ) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            
            queue.async {
                
                do {
                    
                    try self.executor.commit(
                        path: path,
                        message: message,
                        username: username,
                        password: password,
                        log: log
                    )
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - ADD
    
    public func add(
        path: String,
        username: String,
        password: String,
        message: String? = nil,
        log: SVNLogCallback? = nil
    ) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            
            queue.async {
                
                do {
                    
                    try self.executor.add(
                        path: path,
                        username: username,
                        password: password,
                        message: message,
                        log: log
                    )
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - DELETE
    
    public func delete(
        path: String,
        username: String,
        password: String,
        message: String? = nil,
        log: SVNLogCallback? = nil
    ) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            
            queue.async {
                
                do {
                    
                    try self.executor.delete(
                        path: path,
                        username: username,
                        password: password,
                        message: message,
                        log: log
                    )
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
