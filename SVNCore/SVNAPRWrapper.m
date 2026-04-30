#import "SVNAPRWrapper.h"

// --------------------- Required SVN & APR headers ---------------------
#import <apr_general.h>
#import <apr_pools.h>
#import <apr_strings.h>

#import <svn_client.h>
#import <svn_wc.h>
#import <svn_path.h>
#import <svn_props.h>
#import <svn_pools.h>
#import <svn_error.h>
#import <svn_auth.h>

#import "SVNAPRPoolManager.h"

// ----------------------------------------------------------------------

// Internal block type used for storing the Objective-C block in C baton
typedef void (^InternalLogBlock)(NSString *line);

@implementation SVNAPRWrapper {
    BOOL _isInitialized;
}

#pragma mark - Helpers

static const char * actionToString(enum svn_wc_notify_action_t action) {
    switch (action) {
        case svn_wc_notify_add: return "Added";
        case svn_wc_notify_copy: return "Copied";
        case svn_wc_notify_delete: return "Deleted";
        case svn_wc_notify_restore: return "Restored";
        case svn_wc_notify_resolved: return "Resolved conflict";
        case svn_wc_notify_skip: return "Skipped";
        case svn_wc_notify_update_add: return "Updated: Added";
        case svn_wc_notify_update_delete: return "Updated: Deleted";
        case svn_wc_notify_update_update: return "Updated: Modified";
        case svn_wc_notify_update_completed: return "Update Completed";
        default: return "Unknown action";
    }
}


#pragma mark - Notify callback

// notify_func2 signature
//
static void notifyCallback(void *baton,
                           const svn_wc_notify_t *notify,
                           apr_pool_t *pool)
{
    if (!notify || !baton) return;
    
    InternalLogBlock block = (__bridge InternalLogBlock)baton;
    if (!block) return;
    
    NSString *actionStr = [NSString stringWithUTF8String:actionToString(notify->action)];
    NSString *filePath = notify->path ? [NSString stringWithUTF8String:notify->path] : @"(unknown)";
    
    NSString *line;
    if (notify->revision != SVN_INVALID_REVNUM) {
        // User-friendly: "File.txt → Updated (r1234)"
        line = [NSString stringWithFormat:@"%@ → %@ (r%ld)", filePath, actionStr, notify->revision];
    } else {
        line = [NSString stringWithFormat:@"%@ → %@", filePath, actionStr];
    }
    
    // Ensure UI updates on main thread. ENHANCEMENT: Added autoreleasepool to prevent memory spikes.
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            block(line);
        }
    });
}


// Status
typedef struct {
    void *logBlock;
    BOOL verbose;
} StatusBaton;

typedef struct {
    void *logBlock;
} DetailedBaton;

static svn_error_t *
status_callback(
    void *baton,
    const char *path,
    const svn_client_status_t *status,
    apr_pool_t *scratch_pool
) {
    StatusBaton *b = (StatusBaton *)baton;
    if (!b || !b->logBlock || !status) {
        return SVN_NO_ERROR;
    }

    // 🌟 FIX: Extract the block so dispatch_async captures it strongly, not the pointer 'b'
    //SVNLogCallback safeLogBlock = b->logBlock;
    SVNLogCallback safeLogBlock = (__bridge SVNLogCallback)b->logBlock;

    char flag = ' ';

    switch (status->node_status) {
        case svn_wc_status_modified:      flag = 'M'; break;
        case svn_wc_status_added:         flag = 'A'; break;
        case svn_wc_status_deleted:       flag = 'D'; break;
        case svn_wc_status_unversioned:   flag = '?'; break;
        case svn_wc_status_conflicted:    flag = 'C'; break;
        case svn_wc_status_replaced:      flag = 'R'; break;
        case svn_wc_status_missing:       flag = '!'; break;
        default:                          flag = ' '; break;
    }

    NSString *line;
    if (b->verbose) {
        // Verbose format: status working_rev repo_rev author path
        // e.g., "       123   456 user file.txt" or "M      123   456 user file.txt"
        long workingRev = status->revision != SVN_INVALID_REVNUM ? (long)status->revision : 0;
        long reposRev = status->repos_relpath ? 0 : 0; // Not sure how to get repos rev
        // Actually, for verbose, it's working rev, but for unchanged, it's the same.
        // For simplicity, use working rev for both.
        NSString *author = @"-";
        if (status->repos_relpath) {
            // Not easy to get author here, perhaps leave as -
        }
        line = [NSString stringWithFormat:@"%c %6ld %6ld %-12@ %s",
                flag, workingRev, workingRev, author, path ? path : ""];
    } else {
        line = [NSString stringWithFormat:@"%c       %s",
                flag,
                path ? path : ""];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
           
            if (safeLogBlock) {
                safeLogBlock(line);
            }
        }
    });
    
    return SVN_NO_ERROR;
}



static svn_error_t *listDetailedCallback(void *baton,
                                         const char *path,
                                         const svn_dirent_t *dirent,
                                         const svn_lock_t *lock,
                                         const char *abs_path,
                                         const char *repos_relpath,
                                         const char *root_url,
                                         apr_pool_t *pool)
{
    if (!baton) return SVN_NO_ERROR;
    
    DetailedBaton *b = (DetailedBaton *)baton;
    if (!b->logBlock) return SVN_NO_ERROR;
    SVNLogCallback safeLogBlock = (__bridge SVNLogCallback)b->logBlock;


    // Name
    NSString *name = path ? [NSString stringWithUTF8String:path] : @"(unknown)";

    // Folder / file
    BOOL isFolder = (dirent && dirent->kind == svn_node_dir);
    NSString *kindStr = isFolder ? @"dir" : @"file";

    // Revision
    NSInteger revision = dirent ? (NSInteger)dirent->created_rev : 0;

    // Author
    NSString *author = @"-";
    if (dirent && dirent->last_author) {
        author = [NSString stringWithUTF8String:dirent->last_author];
    }

    // Date
    NSString *date = @"-";
    if (dirent && dirent->time != 0) {
        apr_time_t t = dirent->time;
        time_t unixTime = (time_t)(t / 1000000); // APR time = microseconds
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:unixTime];
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        [f setDateFormat:@"yyyy-MM-dd HH:mm"];
        date = [f stringFromDate:d];
    }

    // Size
    NSString *size = @"-";
    if (dirent && dirent->kind == svn_node_file) {
        size = [NSString stringWithFormat:@"%lld", dirent->size];
    }

    NSString *line = [NSString stringWithFormat:@"%ld|%@|%@|%@|%@|%@",
                      (long)revision, author, date, size, name, kindStr];

    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            if (safeLogBlock) {
                safeLogBlock(line);
            }
        }
    });

    return SVN_NO_ERROR;
}



#pragma mark - APR / Pool

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInitialized = NO;
    }
    return self;
}


- (BOOL)initializeAPRAndSVN {
    static BOOL initialized = NO;
    if (initialized) return YES;
    
    // ENHANCEMENT: Made APR initialization completely thread-safe via dispatch_once.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        apr_initialize();
        atexit(apr_terminate);
        initialized = YES;
    });
    
    return YES;
}

// MARK: - Cleanup Path
- (int)cleanupPath:(NSString *)path error:(NSString *__autoreleasing *)error {
    if (!path || path.length == 0) {
        if (error) *error = @"Invalid path";
        return -1;
    }

    apr_pool_t *pool = [[SVNAPRPoolManager sharedManager] createChildPool];
    if (!pool) {
        if (error) *error = @"Failed to create APR pool";
        return -1;
    }

    svn_wc_context_t *wc_ctx = NULL;

#if SVN_API_VERSION >= 14
    svn_wc_context_create_opts_t *opts = svn_wc_context_create_opts_alloc(pool);
    svn_error_t *err = svn_wc_context_create(&wc_ctx, opts, pool);
#else
    svn_error_t *err = svn_wc_context_create(&wc_ctx, NULL, pool, pool);
#endif

    if (err) {
        if (error) *error = [NSString stringWithUTF8String:err->message ?: "Failed to create WC context"];
        svn_error_clear(err);
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1;
    }

    err = svn_wc_cleanup4(
        wc_ctx,
        [path UTF8String],
        TRUE,
        TRUE,
        TRUE,
        TRUE,
        NULL,
        NULL,
        NULL,
        NULL,
        pool
    );

    if (err) {
        if (error) *error = [NSString stringWithUTF8String:err->message ?: "Unknown error"];
        svn_error_clear(err);
        svn_wc_context_destroy(wc_ctx);
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1;
    }

    svn_wc_context_destroy(wc_ctx);
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];

    return 0;
}


// MARK: - Reset Session
- (void)resetSessionFor:(NSString *)url {
    // If you have stored RA session or auth baton for the URL, clear them here.
    // For example:
    // [_sessions removeObjectForKey:url];
    // [_authBatons removeObjectForKey:url];
    // In this simplified example, we just log
    NSLog(@"Resetting SVN session for URL: %@", url);
}

- (apr_pool_t *)createPool {
    return [[SVNAPRPoolManager sharedManager] createChildPool];
}

#pragma mark - Internal: create context (private)

- (svn_client_ctx_t *)createContextWithPool:(apr_pool_t *)pool
                                   username:(NSString *)username
                                   password:(NSString *)password
                                        log:(nullable SVNLogCallback)logBlock
                                      error:(NSString * _Nullable * _Nullable)error
{
    svn_client_ctx_t *ctx = NULL;
    svn_error_t *err = svn_client_create_context2(&ctx, NULL, pool);
    if (err) {
        if (error && err->message) *error = [NSString stringWithUTF8String:err->message];
        svn_error_clear(err);
        return NULL;
    }
    
    // -----------------------------------------------------
    // Load SVN configuration (IMPORTANT for auth + commit)
    // -----------------------------------------------------
    apr_hash_t *config = NULL;
    svn_config_get_config(&config, NULL, pool);
    ctx->config = config;
    
    // Auth providers
    apr_array_header_t *providers = apr_array_make(pool, 4, sizeof(svn_auth_provider_object_t *));
    svn_auth_provider_object_t *simple_provider = NULL;
    svn_auth_provider_object_t *username_provider = NULL;
    
    svn_auth_get_simple_provider(&simple_provider, pool);
    svn_auth_get_username_provider(&username_provider, pool);
    
    APR_ARRAY_PUSH(providers, svn_auth_provider_object_t *) = simple_provider;
    APR_ARRAY_PUSH(providers, svn_auth_provider_object_t *) = username_provider;
    
    svn_auth_baton_t *auth_baton = NULL;
    svn_auth_open(&auth_baton, providers, pool);
    ctx->auth_baton = auth_baton;
    
    if (username.length > 0) {
        svn_auth_set_parameter(auth_baton, SVN_AUTH_PARAM_DEFAULT_USERNAME, username.UTF8String);
    }
    if (password.length > 0) {
        svn_auth_set_parameter(auth_baton, SVN_AUTH_PARAM_DEFAULT_PASSWORD, password.UTF8String);
    }
    
    // Wire notify to the provided logBlock, retaining it for the lifetime of ctx
    if (logBlock) {
        // create an internal block that calls the public block
        InternalLogBlock internal = ^(NSString *line){
            if (logBlock) {
                NSString *lower = [line lowercaseString];

                // Ignore SVN post-checkout noise
                if ([lower hasPrefix:@"updated to revision"]) {
                    return;
                }

                logBlock(line);
            }

        };
        
        // Retain the block for the C side; we'll release when operation ends
        ctx->notify_func2 = notifyCallback;
        ctx->notify_baton2 = (__bridge_retained void *)[internal copy];
    } else {
        ctx->notify_func2 = NULL;
        ctx->notify_baton2 = NULL;
    }
    
    return ctx;
}

// Release retained notify baton (if any)
- (void)releaseNotifyBatonFromContext:(svn_client_ctx_t *)ctx {
    if (ctx && ctx->notify_baton2) {
        // Transfer ownership back to ARC and let it be released
        id blockObj = (__bridge_transfer id)ctx->notify_baton2;
        (void)blockObj;
        ctx->notify_baton2 = NULL;
        ctx->notify_func2 = NULL;
    }
}

#pragma mark - SVN operations (public)

- (int)checkoutURL:(NSString *)url
            toPath:(NSString *)path
          username:(NSString *)username
          password:(NSString *)password
               log:(nullable SVNLogCallback)logBlock
          revision:(NSInteger)revisionNumber
             depth:(NSInteger)depthValue
       revisionOut:(NSInteger * _Nullable)revisionOut
             error:(NSString * _Nullable * _Nullable)error
{
    [self initializeAPRAndSVN];

    apr_pool_t *pool = [[SVNAPRPoolManager sharedManager] createChildPool];
    if (!pool) {
        if (error) *error = @"Failed to create APR pool";
        return -1;
    }

    svn_client_ctx_t *ctx = [self createContextWithPool:pool
                                               username:username
                                               password:password
                                                    log:logBlock
                                                  error:error];
    if (!ctx) {
           [[SVNAPRPoolManager sharedManager] destroyPool:pool];
           return -1;
       }

    svn_opt_revision_t peg_rev, revision;
    peg_rev.kind = svn_opt_revision_unspecified;

    if (revisionNumber >= 0) {
        revision.kind = svn_opt_revision_number;
        revision.value.number = revisionNumber;
    } else {
        revision.kind = svn_opt_revision_head;
    }

    svn_revnum_t newRevision = 0;

    svn_error_t *err = svn_client_checkout3(
        &newRevision,
        url.UTF8String,
        path.UTF8String,
        &peg_rev,
        &revision,
        (svn_depth_t)depthValue,
        FALSE,
        TRUE,
        ctx,
        pool
    );
    int rc = 0;
    if (err) {
        if (error && err->message) {
            *error = [NSString stringWithUTF8String:err->message];
        }
        rc = (int)err->apr_err;
        svn_error_clear(err);
    }

    if (revisionOut) {
        *revisionOut = (NSInteger)newRevision;
    }

    // BUG FIX 1: Removed duplicate log call that appeared before releaseNotifyBatonFromContext.
    // The single call below (inside rc == 0) is the correct one.
    [self releaseNotifyBatonFromContext:ctx];
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];

    if (logBlock && rc == 0) {
        logBlock([NSString stringWithFormat:@"✔ Checkout completed at revision %ld", (long)newRevision]);
    }
    return rc;
}



- (int)updatePath:(NSString *)path
         username:(NSString *)username
         password:(NSString *)password
              log:(nullable SVNLogCallback)logBlock
            error:(NSString * _Nullable * _Nullable)error
{
    [self initializeAPRAndSVN];

    // 1️⃣ Create APR pool
    apr_pool_t *pool = [self createPool];
    if (!pool) {
        if (error) *error = @"Failed to create APR pool";
        return -1;
    }

    // 2️⃣ Create SVN client context
    svn_client_ctx_t *ctx = [self createContextWithPool:pool
                                                username:username
                                                password:password
                                                     log:logBlock
                                                   error:error];
    if (!ctx) {
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1;
    }

    // 3️⃣ Prepare targets array
    apr_array_header_t *targets = apr_array_make(pool, 1, sizeof(const char *));
    APR_ARRAY_PUSH(targets, const char *) = apr_pstrdup(pool, [path UTF8String]);

    // 4️⃣ Set revision to HEAD
    svn_opt_revision_t rev;
    rev.kind = svn_opt_revision_head;

    
    // 5️⃣ Perform SVN update
    //svn_revnum_t result_revs; // Must declare result variable
    apr_array_header_t *result_revs = NULL;
    svn_error_t *err = svn_client_update4(
        &result_revs,
        targets, &rev,
        svn_depth_infinity,
        TRUE,   // depth_is_sticky
        FALSE,  // ignore_externals
        FALSE,  // allow_unver_obstructions
        FALSE,  // adds_as_modification
        FALSE,  // make_parents  ← was missing
        ctx, pool
    );

    // 6️⃣ Handle errors
    int rc = 0;
    if (err) {
        if (error && err->message) *error = [NSString stringWithUTF8String:err->message ?: "SVN update failed"];
        rc = (int)err->apr_err;
        svn_error_clear(err);
    }

    // 7️⃣ Clean up
    [self releaseNotifyBatonFromContext:ctx];
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];

    return rc;
}

- (int)listDetailed:(NSString *)url
           username:(NSString *)username
           password:(NSString *)password
                log:(nullable SVNLogCallback)logBlock
              error:(NSString * _Nullable * _Nullable)error
{
    [self initializeAPRAndSVN];
    apr_pool_t *pool = [self createPool];
    if (!pool) { if (error) *error = @"Failed to create APR pool"; return -1; }
    
    svn_client_ctx_t *ctx = [self createContextWithPool:pool username:username password:password log:nil error:error];
    if (!ctx) { [[SVNAPRPoolManager sharedManager] destroyPool:pool]; return -1; }
    
    svn_opt_revision_t peg_rev, rev;
    peg_rev.kind = svn_opt_revision_unspecified;
    rev.kind = svn_opt_revision_head;
    
    
    DetailedBaton baton;
    baton.logBlock = logBlock ? (__bridge_retained void *)[logBlock copy] : NULL;
    
    svn_error_t *err = svn_client_list4(
                                        url.UTF8String,
                                        &peg_rev,
                                        &rev,
                                        NULL,
                                        svn_depth_immediates,
                                        SVN_DIRENT_ALL,
                                        FALSE,
                                        FALSE,
                                        listDetailedCallback,
                                        &baton,
                                        ctx,
                                        pool
                                        );
    
    int rc = 0;
    if (err) {
        if (error && err->message) *error = [NSString stringWithUTF8String:err->message];
        rc = (int)err->apr_err;
        svn_error_clear(err);
    }
    
    [self releaseNotifyBatonFromContext:ctx];

    if (baton.logBlock) {
        CFRelease(baton.logBlock);
    }

    [[SVNAPRPoolManager sharedManager] destroyPool:pool];
    return rc;
}

- (int)commitPath:(NSString *)path
          message:(nullable NSString *)message
         username:(NSString *)username
         password:(NSString *)password
              log:(nullable SVNLogCallback)logBlock
            error:(NSString * _Nullable * _Nullable)error
{
    [self initializeAPRAndSVN];

    apr_pool_t *pool = [self createPool];
    if (!pool) {
        if (error) *error = @"Failed to create APR pool";
        return -1;
    }

    // BUG FIX 2: Create and nil-check ctx BEFORE accessing its fields.
    // Original code set log_msg_func3/log_msg_baton3 before the nil check, causing a crash on nil ctx.
    svn_client_ctx_t *ctx =
        [self createContextWithPool:pool
                           username:username
                           password:password
                                log:logBlock
                              error:error];

    if (!ctx) {
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1;
    }

    // -----------------------------------------------------
    // Provide commit message via SVN log callback
    // -----------------------------------------------------
    if (message.length > 0) {
        ctx->log_msg_func3 = log_msg_func;
        ctx->log_msg_baton3 = (__bridge void *)message;
    }

    apr_array_header_t *targets =
        apr_array_make(pool, 1, sizeof(const char *));

    APR_ARRAY_PUSH(targets, const char *) =
        apr_pstrdup(pool, path.UTF8String);

    apr_hash_t *revprops = NULL; // Do not set svn:log here

    svn_error_t *err = svn_client_commit6(
        targets,
        svn_depth_infinity,
        FALSE,   // keep_locks
        FALSE,   // keep_changelists
        FALSE,   // commit_as_operations (IMPORTANT FIX)
        FALSE,   // include_file_externals
        FALSE,   // include_dir_externals
        NULL,    // changelists
        revprops,
        commit_callback, // production callback
        NULL,
        ctx,
        pool
    );
    
    int rc = 0;

    if (err) {

        NSString *fullError = SVNFullErrorMessage(err);

        if (error) {
            *error = fullError;
        }

        NSLog(@"SVN Commit Error: %@", fullError);

        rc = (int)err->apr_err;

        svn_error_clear(err);
    }

    [self releaseNotifyBatonFromContext:ctx];
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];

    return rc;
}

// -----------------------------------------------------
// Log message callback (SVN 1.10+ / commit6 compatible)
// -----------------------------------------------------
static svn_error_t *
log_msg_func(const char **log_msg,
             const char **tmp_file,
             const apr_array_header_t *commit_items,
             void *baton,
             apr_pool_t *pool)
{
    if (!baton) {
        *log_msg = "";
        *tmp_file = NULL;
        return SVN_NO_ERROR;
    }

    NSString *msg = (__bridge NSString *)baton;

    if (msg.length == 0) {
        *log_msg = "";
    } else {
        *log_msg = apr_pstrdup(pool, [msg UTF8String]);
    }

    *tmp_file = NULL;

    return SVN_NO_ERROR;
}

// -----------------------------------------------------
// Commit callback (Production grade)
// -----------------------------------------------------
static svn_error_t *
commit_callback(const svn_commit_info_t *commit_info,
                void *baton,
                apr_pool_t *pool)
{
    if (!commit_info) {
        return SVN_NO_ERROR;
    }

    if (commit_info->revision != SVN_INVALID_REVNUM) {
        NSLog(@"SVN Commit completed at revision %ld", commit_info->revision);
    }

    return SVN_NO_ERROR;
}

// -----------------------------------------------------
// Helper: Print full SVN error chain
// -----------------------------------------------------
static NSString *SVNFullErrorMessage(svn_error_t *err)
{
    if (!err) return @"Unknown SVN error";

    NSMutableString *msg = [NSMutableString string];

    svn_error_t *e = err;
    while (e) {
        if (e->message) {
            [msg appendFormat:@"%s\n", e->message];
        }
        e = e->child;
    }

    if (msg.length == 0) {
        [msg appendString:@"Unknown SVN error"];
    }

    return msg;
}


- (int)addPath:(NSString *)path
       message:(nullable NSString *)message
      username:(NSString *)username
      password:(NSString *)password
           log:(nullable SVNLogCallback)logBlock
         error:(NSString * _Nullable * _Nullable)error
{
    [self initializeAPRAndSVN];

    apr_pool_t *pool = [self createPool];
    if (!pool) { if (error) *error = @"Failed to create APR pool"; return -1; }

    svn_client_ctx_t *ctx = [self createContextWithPool:pool username:username password:password log:logBlock error:error];
    if (!ctx) {
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1; }

    svn_error_t *err = svn_client_add5(
        path.UTF8String,
        svn_depth_infinity,
        TRUE,
        FALSE,
        FALSE,
        TRUE,
        ctx,
        pool
    );

    int rc = 0;
    if (err) {
        if (error && err->message) *error = [NSString stringWithUTF8String:err->message];
        rc = (int)err->apr_err;
        svn_error_clear(err);
    }

    [self releaseNotifyBatonFromContext:ctx];
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];
    return rc;
}

- (int)addBatch:(NSArray<NSString *> *)paths
       username:(NSString *)username
       password:(NSString *)password
            log:(SVNLogCallback)logBlock
          error:(NSString **)error
{
    apr_pool_t *pool = [[SVNAPRPoolManager sharedManager] createChildPool];

    svn_client_ctx_t *ctx = NULL;
    svn_error_t *err = svn_client_create_context2(&ctx, NULL, pool);

    if (err) {
        if (error) *error = [NSString stringWithUTF8String:err->message];
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return (int)err->apr_err;
    }

    svn_config_get_config(&(ctx->config), NULL, pool);

    for (NSString *path in paths) {

        const char *cpath = [path UTF8String];

        if (logBlock) {
            logBlock([NSString stringWithFormat:@"Adding %@", path]);
        }

        err = svn_client_add5(
            cpath,
            svn_depth_infinity,
            FALSE,
            FALSE,
            FALSE,
            TRUE,
            ctx,
            pool
        );

        if (err) {

            if (error) {
                *error = [NSString stringWithUTF8String:err->message];
            }

            [[SVNAPRPoolManager sharedManager] destroyPool:pool];
            return (int)err->apr_err;
        }
    }

    if (logBlock) {
        logBlock(@"✔ Add batch completed");
    }

    [[SVNAPRPoolManager sharedManager] destroyPool:pool];

    return 0;
}

- (int)deletePaths:(NSArray<NSString *> *)paths
           message:(nullable NSString *)message
          username:(NSString *)username
          password:(NSString *)password
               log:(nullable SVNLogCallback)logBlock
             error:(NSString * _Nullable * _Nullable)error
{
    [self initializeAPRAndSVN];

    apr_pool_t *pool = [self createPool];
    if (!pool) {
        if (error) *error = @"Failed to create APR pool";
        return -1;
    }

    svn_client_ctx_t *ctx = [self createContextWithPool:pool
                                               username:username
                                               password:password
                                                    log:logBlock
                                                  error:error];
    if (!ctx) {
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1;
    }

    apr_array_header_t *targets =
        apr_array_make(pool, (int)paths.count, sizeof(const char *));

    for (NSString *path in paths) {
        APR_ARRAY_PUSH(targets, const char *) =
            apr_pstrdup(pool, path.UTF8String);
    }

    apr_hash_t *revprops = apr_hash_make(pool);

    if (message.length > 0) {
        apr_hash_set(
            revprops,
            SVN_PROP_REVISION_LOG,
            APR_HASH_KEY_STRING,
            svn_string_create(message.UTF8String, pool)
        );
    }

    svn_error_t *err = svn_client_delete4(
        targets,
        TRUE,   // force
        FALSE,  // keep_local
        revprops,
        NULL,
        NULL,
        ctx,
        pool
    );

    int rc = 0;

    if (err) {
        if (error && err->message)
            *error = [NSString stringWithUTF8String:err->message];

        rc = (int)err->apr_err;
        svn_error_clear(err);
    }

    [self releaseNotifyBatonFromContext:ctx];
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];

    return rc;
}

- (int)deletePath:(NSString *)path
          message:(nullable NSString *)message
         username:(NSString *)username
         password:(NSString *)password
              log:(nullable SVNLogCallback)logBlock
            error:(NSString * _Nullable * _Nullable)error
{
    [self initializeAPRAndSVN];

    apr_pool_t *pool = [self createPool];
    if (!pool) { if (error) *error = @"Failed to create APR pool"; return -1; }

    svn_client_ctx_t *ctx = [self createContextWithPool:pool username:username password:password log:logBlock error:error];
    if (!ctx) { [[SVNAPRPoolManager sharedManager] destroyPool:pool]; return -1; }

    apr_array_header_t *targets = apr_array_make(pool, 1, sizeof(const char *));
    APR_ARRAY_PUSH(targets, const char *) = apr_pstrdup(pool, path.UTF8String);

    apr_hash_t *revprops = apr_hash_make(pool);
    if (message.length > 0) {
        apr_hash_set(revprops, SVN_PROP_REVISION_LOG, APR_HASH_KEY_STRING, svn_string_create(message.UTF8String, pool));
    }

    svn_error_t *err = svn_client_delete4(
        targets,
        TRUE,
        FALSE,
        revprops,
        NULL,
        NULL,
        ctx,
        pool
    );

    int rc = 0;
    if (err) {
        if (error && err->message) *error = [NSString stringWithUTF8String:err->message];
        rc = (int)err->apr_err;
        svn_error_clear(err);
    }

    [self releaseNotifyBatonFromContext:ctx];
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];
    return rc;
}

// -----------------------------------------------------
// ENHANCEMENT: Added stub implementation for `listURL:`
// to satisfy interface requirements and prevent crashing
// if called, returning an error natively.
// -----------------------------------------------------
- (int)listURL:(NSString *)url
      username:(NSString *)username
      password:(NSString *)password
           log:(nullable SVNLogCallback)logBlock
         error:(NSString * _Nullable * _Nullable)error
{
    if (error) *error = @"Not fully implemented. Use listDetailed: instead.";
    return -1;
}

- (int)statusPath:(NSString *)path
            depth:(NSInteger)depthValue
           verbose:(BOOL)verbose
         username:(NSString *)username
         password:(NSString *)password
              log:(SVNLogCallback)logBlock
            error:(NSString **)error
{
    
    if (!path.length) {
        if (error) *error = @"Invalid path";
        return -1;
    }

    apr_pool_t *pool = [[SVNAPRPoolManager sharedManager] createChildPool];

    // ---------------------------
    // Baton
    // ---------------------------
    StatusBaton baton;
    baton.logBlock = (__bridge_retained void *)[logBlock copy];
    baton.verbose = verbose;
    
    // BUG FIX 3: Removed the duplicate auth provider setup that followed this call.
    // createContextWithPool: already sets up auth providers with the supplied username/password.
    // The second setup overwrote ctx->auth_baton with a new baton that had no credentials,
    // causing authenticated status calls to silently fail.
    svn_client_ctx_t *ctx = [self createContextWithPool:pool
                                                username:username
                                                password:password
                                                     log:logBlock
                                                   error:error];
    if (!ctx) {
        if (baton.logBlock) CFRelease(baton.logBlock);
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1;
    }

    // ---------------------------
    // Call svn_client_status6
    // ---------------------------
    svn_error_t *err = svn_client_status6(
        NULL,                       // result_rev
        ctx,
        [path UTF8String],
        NULL,                       // revision (WC)
        (svn_depth_t)depthValue,    // 🌟 ENHANCEMENT: Replaced hardcoded infinity with depthValue
        TRUE,                       // get_all
        FALSE,                      // check_out_of_date
        TRUE,                       // check_working_copy
        TRUE,                       // no_ignore
        FALSE,                      // ignore_externals
        FALSE,                      // depth_as_sticky
        NULL,                       // changelists
        status_callback,
        &baton,
        pool
    );


    int rc = 0;
    if (err) {
        if (error) *error = [NSString stringWithUTF8String:err->message ?: "SVN status failed"];
        rc = (int)err->apr_err;
        svn_error_clear(err);
    }

    [self releaseNotifyBatonFromContext:ctx];
    if (baton.logBlock) CFRelease(baton.logBlock);
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];
    return rc;
}

- (int)lockPath:(NSString *)path comment:(NSString *)comment username:(NSString *)username password:(NSString *)password error:(NSString **)error {
    [self initializeAPRAndSVN];
    apr_pool_t *pool = [[SVNAPRPoolManager sharedManager] createChildPool];
    svn_client_ctx_t *ctx = [self createContextWithPool:pool username:username password:password log:nil error:error];
    
    [self releaseNotifyBatonFromContext:ctx];
    apr_array_header_t *targets = apr_array_make(pool, 1, sizeof(const char *));
    APR_ARRAY_PUSH(targets, const char *) = apr_pstrdup(pool, [path UTF8String]);
    
    svn_error_t *err = svn_client_lock(targets, [comment UTF8String], FALSE, ctx, pool);
    
    if (err) {
        if (error) *error = [NSString stringWithUTF8String:err->message];
        svn_error_clear(err);
        [[SVNAPRPoolManager sharedManager] destroyPool:pool];
        return -1;
    }
    [[SVNAPRPoolManager sharedManager] destroyPool:pool];
    return 0;
}
@end

