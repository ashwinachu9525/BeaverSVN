//
//  SVNAPRWrapper.h
//  MacSVN Pro
//
//  Created by Aswin K on 22/12/25.


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ---------------------------
// Callback Types
// ---------------------------
/// Public log callback type (pass from Swift to receive notify lines)
typedef void (^SVNLogCallback)(NSString *line);

// ---------------------------
// Internal baton for detailed list
// ---------------------------


// ---------------------------
// Forward declare callback
// This matches svn_client_list_func2_t
// ---------------------------

/// Wrapper class to bridge Subversion C APIs to Objective-C and Swift
@interface SVNAPRWrapper : NSObject

// MARK: - Initialization

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Initialize APR and SVN libraries. Enhanced to be completely thread-safe.
/// Safe to call multiple times.
- (BOOL)initializeAPRAndSVN;

// MARK: - Core Operations

/// Checkout repository URL to local path
/// @param revisionNumber Use -1 for HEAD revision
- (int)checkoutURL:(NSString *)url
            toPath:(NSString *)path
          username:(NSString *)username
          password:(NSString *)password
               log:(nullable SVNLogCallback)logBlock
          revision:(NSInteger)revisionNumber
             depth:(NSInteger)depthValue
       revisionOut:(NSInteger * _Nullable)revisionOut
             error:(NSString * _Nullable * _Nullable)error;

/// Update working copy at path
- (int)updatePath:(NSString *)path
         username:(NSString *)username
         password:(NSString *)password
              log:(nullable SVNLogCallback)logBlock
            error:(NSString * _Nullable * _Nullable)error;

/// Commit changes at path with a message
- (int)commitPath:(NSString *)path
          message:(nullable NSString *)message
         username:(NSString *)username
         password:(NSString *)password
              log:(nullable SVNLogCallback)logBlock
            error:(NSString * _Nullable * _Nullable)error;

/// Add a file or directory to SVN
- (int)addPath:(NSString *)path
       message:(nullable NSString *)message
      username:(NSString *)username
      password:(NSString *)password
           log:(nullable SVNLogCallback)logBlock
         error:(NSString * _Nullable * _Nullable)error;


/// Add multiple files or directories to SVN
- (int)addBatch:(NSArray<NSString *> *)paths
       username:(NSString *)username
       password:(NSString *)password
            log:(nullable SVNLogCallback)logBlock
          error:(NSString * _Nullable * _Nullable)error;

/// Delete a file or directory from SVN
- (int)deletePath:(NSString *)path
          message:(nullable NSString *)message
         username:(NSString *)username
         password:(NSString *)password
              log:(nullable SVNLogCallback)logBlock
            error:(NSString * _Nullable * _Nullable)error;

- (int)deletePaths:(NSArray<NSString *> *)paths
           message:(nullable NSString *)message
          username:(NSString *)username
          password:(NSString *)password
               log:(nullable SVNLogCallback)logBlock
             error:(NSString * _Nullable * _Nullable)error;

// MARK: - Browsing & Status

// Repository browser / list
- (int)listURL:(NSString *)url
       username:(NSString *)username
       password:(NSString *)password
            log:(nullable SVNLogCallback)logBlock
          error:(NSString * _Nullable * _Nullable)error;

/// Get SVN status for a working copy path (Enhanced with Depth control)
- (int)statusPath:(NSString *)path
            depth:(NSInteger)depthValue
           verbose:(BOOL)verbose
         username:(NSString *)username
         password:(NSString *)password
              log:(nullable SVNLogCallback)logBlock
            error:(NSString * _Nullable * _Nullable)error;


// --- NEW: Lock Path Method ---
/**
 * Locks a file or directory in the repository.
 * Error 195011 (SVN_ERR_CLIENT_NO_LOCK_TOKEN) indicates this is required before commit.
 */
- (int)lockPath:(NSString *)path
        comment:(nullable NSString *)comment
       username:(NSString *)username
       password:(NSString *)password
          error:(NSString **)error;
// ---------------------------
// ⭐ New method for detailed list
// ---------------------------
/// Fetch detailed directory listing (author, date, size, etc.)
- (int)listDetailed:(NSString *)url
           username:(NSString *)username
           password:(NSString *)password
                log:(nullable SVNLogCallback)logBlock
              error:(NSString * _Nullable * _Nullable)error;

// MARK: - Utility

// New cleanup method to resolve locked working copies
- (int)cleanupPath:(NSString *)path error:(NSString* __autoreleasing *)error;

// Reset session for a URL (clears cached credentials/states)
- (void)resetSessionFor:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
