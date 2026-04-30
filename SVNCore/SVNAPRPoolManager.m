//
//  SVNAPRPoolManager.m
//  FreeSVN
//
//  Created by Aswin K on 01/04/26.
//

#import "SVNAPRPoolManager.h"
#import <apr_general.h>

@implementation SVNAPRPoolManager {
    apr_pool_t *_globalPool;
    dispatch_queue_t _poolQueue;
}

+ (instancetype)sharedManager {
    static SVNAPRPoolManager *manager;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        manager = [[SVNAPRPoolManager alloc] init];
    });

    return manager;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        apr_initialize();
        atexit(apr_terminate);

        apr_pool_create(&_globalPool, NULL);

        _poolQueue = dispatch_queue_create(
            "com.freesvn.aprpool",
            DISPATCH_QUEUE_SERIAL
        );
    }

    return self;
}

- (apr_pool_t *)globalPool {
    return _globalPool;
}

- (apr_pool_t *)createChildPool {

    __block apr_pool_t *child = NULL;

    dispatch_sync(_poolQueue, ^{
        apr_pool_create(&child, _globalPool);
    });

    return child;
}

- (void)destroyPool:(apr_pool_t *)pool {

    if (!pool) return;

    dispatch_sync(_poolQueue, ^{
        apr_pool_destroy(pool);
    });
}

@end
