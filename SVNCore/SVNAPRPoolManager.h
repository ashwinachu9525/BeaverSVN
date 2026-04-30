//
//  SVNAPRPoolManager.h
//  FreeSVN
//
//  Created by Aswin K on 01/04/26.
//

#import <Foundation/Foundation.h>
#import <apr_pools.h>

NS_ASSUME_NONNULL_BEGIN

@interface SVNAPRPoolManager : NSObject

+ (instancetype)sharedManager;

- (apr_pool_t *)globalPool;
- (apr_pool_t *)createChildPool;
- (void)destroyPool:(apr_pool_t *)pool;

@end

NS_ASSUME_NONNULL_END
