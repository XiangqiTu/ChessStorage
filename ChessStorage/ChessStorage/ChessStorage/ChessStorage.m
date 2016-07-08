//
//  ChessStorage.m
//  ChessStorage
//
//  Created by Xiangqi on 16/3/19.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "ChessStorage.h"
#import <UIKit/UIApplication.h>
#import <libkern/OSAtomic.h>
#import "ChessMulticastBlockBus.h"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

@interface ChessStorage ()
{
    ChessMulticastBlockBus *didSaveManagedContextBus;
}

@property (nonatomic, strong) ChessConfig   *config;
@property (nonatomic, weak) dispatch_queue_t storageQueue;
@property (nonatomic, assign) void *storageQueueTag;

/**
 * Queries the managedObjectContext to determine the number of unsaved managedObjects.
 **/
- (NSUInteger)numberOfUnsavedChanges;

/**
 * You will not often need to manually call this method.
 * It is called automatically, at appropriate and optimized times, via the executeBlock and scheduleBlock methods.
 *
 * The one exception to this is when you are inserting/deleting/updating a large number of objects in a loop.
 * It is recommended that you invoke save from within the loop.
 * E.g.:
 *
 * NSUInteger unsavedCount = [self numberOfUnsavedChanges];
 * for (NSManagedObject *obj in fetchResults)
 * {
 *     [[self managedObjectContext] deleteObject:obj];
 *
 *     if (++unsavedCount >= saveThreshold)
 *     {
 *         [self save];
 *         unsavedCount = 0;
 *     }
 * }
 *
 * See also the documentation for executeBlock and scheduleBlock below.
 **/
- (void)save; // Read the comments above !

/**
 * You will rarely need to manually call this method.
 * It is called automatically, at appropriate and optimized times, via the executeBlock and scheduleBlock methods.
 *
 * This method makes informed decisions as to whether it should save the managedObjectContext changes to disk.
 * Since this disk IO is a slow process, it is better to buffer writes during high demand.
 * This method takes into account the number of pending requests waiting on the storage instance,
 * as well as the number of unsaved changes (which reside in NSManagedObjectContext's internal memory).
 *
 * Please see the documentation for executeBlock and scheduleBlock below.
 **/
- (void)maybeSave; // Read the comments above !

@end

@implementation ChessStorage

@synthesize storageQueue, storageQueueTag;

- (id)initWithConfiguration:( ChessConfig * )configuration
{
    if (self = [super init]) {
        self.config = configuration;
        storageQueue = configuration.storageQueue;
        storageQueueTag = configuration.storageQueueTag;
        
        [self commonInit];
    }
    
    return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)commonInit
{
    saveThreshold = 500;
    
    didSaveManagedContextBus = [[ChessMulticastBlockBus alloc] init];
    
    /**
     *  In iOS 8.0 ~iOS 9.0,saveMainThreadContext while appplication terminate will generate a crash log,
     *  do this to avoid this log
     */
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0") || SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(saveMainThreadContext)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
    }
}

- (void)saveMainThreadContext
{
    NSManagedObjectContext *moc = [self mainThreadManagedObjectContext];
    NSError *error = nil;
    if ([moc hasChanges] && moc.persistentStoreCoordinator != nil) {
        if (![moc save:&error])
        {
            [moc rollback];
        }
    }
}

- (NSUInteger)saveThreshold
{
    if (dispatch_get_specific(storageQueueTag))
    {
        return saveThreshold;
    }
    else
    {
        __block NSUInteger result;
        
        dispatch_sync(storageQueue, ^{
            result = saveThreshold;
        });
        
        return result;
    }
}

- (void)setSaveThreshold:(NSUInteger)newSaveThreshold
{
    dispatch_block_t block = ^{
        saveThreshold = newSaveThreshold;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_async(storageQueue, block);
}

- (NSManagedObjectContext *)mainThreadManagedObjectContext
{
    return [self.config mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)managedObjectContext
{
    return [self.config managedObjectContext];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)numberOfUnsavedChanges
{
    NSManagedObjectContext *moc = [self managedObjectContext];
    
    NSUInteger unsavedCount = 0;
    unsavedCount += [[moc updatedObjects] count];
    unsavedCount += [[moc insertedObjects] count];
    unsavedCount += [[moc deletedObjects] count];
    
    return unsavedCount;
}

- (void)save
{
    // I'm fairly confident that the implementation of [NSManagedObjectContext save:]
    // internally checks to see if it has anything to save before it actually does anthing.
    // So there's no need for us to do it here, especially since this method is usually
    // called from maybeSave below, which already does this check.
    
    NSError *error = nil;
    
    if ([[self managedObjectContext] save:&error]){
        
        [didSaveManagedContextBus multicastBlocks];
    }
    else
    {
        [[self managedObjectContext] rollback];
        
        [didSaveManagedContextBus removeAllInvokeBlocks];
    }
}

- (void)maybeSave:(int32_t)currentPendingRequests
{
    NSAssert(dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
    
    
    if ([[self managedObjectContext] hasChanges])
    {
        if (currentPendingRequests == 0)
        {
            [self save];
        }
        else
        {
            NSUInteger unsavedCount = [self numberOfUnsavedChanges];
            if (unsavedCount >= saveThreshold)
            {
                [self save];
            }
        }
    }
}

- (void)maybeSave
{
    // Convenience method in the very rare case that a subclass would need to invoke maybeSave manually.
    
    [self maybeSave:OSAtomicAdd32(0, &pendingRequests)];
}

- (void)executeBlock:(dispatch_block_t)block
{
    // By design this method should not be invoked from the storageQueue.
    //
    // If you remove the assert statement below, you are destroying the sole purpose for this class,
    // which is to optimize the disk IO by buffering save operations.
    //
    NSAssert(!dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
    //
    // For a full discussion of this method, please see ChessStorageProtocol.h
    //
    // dispatch_Sync
    //          ^
    
    OSAtomicIncrement32(&pendingRequests);
    
    dispatch_sync(storageQueue, ^{ @autoreleasepool {
        
        block();
        
        // Since this is a synchronous request, we want to return as quickly as possible.
        // So we delay the maybeSave operation til later.
        
        dispatch_async(storageQueue, ^{ @autoreleasepool {
            
            [self maybeSave:OSAtomicDecrement32(&pendingRequests)];
        }});
        
    }});
}

- (void)scheduleBlock:(dispatch_block_t)block
{
    // By design this method should not be invoked from the storageQueue.
    //
    // If you remove the assert statement below, you are destroying the sole purpose for this class,
    // which is to optimize the disk IO by buffering save operations.
    //
    NSAssert(!dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
    //
    // For a full discussion of this method, please see ChessStorageProtocol.h
    //
    // dispatch_Async
    //          ^
    
    OSAtomicIncrement32(&pendingRequests);
    dispatch_async(storageQueue, ^{ @autoreleasepool {
        
        block();
        [self maybeSave:OSAtomicDecrement32(&pendingRequests)];
    }});
}

- (void)addDidSaveManagedObjectContextBlock:(void (^)(void))didSaveBlock invokeQueue:(dispatch_queue_t)invokeQueue;
{
    dispatch_block_t block = ^{
        [didSaveManagedContextBus addInvokeBlock:didSaveBlock invokeQueue:invokeQueue];
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_async(storageQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
#if !OS_OBJECT_USE_OBJC
    if (storageQueue)
        dispatch_release(storageQueue);
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Fetch Method
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)fetchEntityName:(NSString *)entityName
                    criteria:(NSString *)criteria
                   variables:(NSDictionary *)variables
                      sortBy:(NSString *)sortKeys
                   ascending:(BOOL)isAscending
{
    return [self fetchEntityName:entityName
                        criteria:criteria
                       variables:variables
                          sortBy:sortKeys
                       ascending:isAscending
                     fetchOffset:0
                      fetchLimit:0
              propertiesToReturn:nil
                        distinct:NO
                           error:nil];
}

- (NSArray *)fetchEntityName:(NSString *)entityName
                    criteria:(NSString *)criteria
                   variables:(NSDictionary *)variables
                      sortBy:(NSString *)sortKeys
                   ascending:(BOOL)isAscending
                 fetchOffset:(NSInteger)offset
                  fetchLimit:(NSInteger)limit
          propertiesToReturn:(NSArray*)properties
                    distinct:(BOOL)isDistinct
                       error:(NSError **)error
{
    NSManagedObjectContext *fetchContext = nil;
    if (dispatch_get_specific(storageQueueTag)) {
        fetchContext = [self managedObjectContext];
    } else {
        fetchContext = [self mainThreadManagedObjectContext];
    }
    
    if (fetchContext == nil) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:fetchContext]];
    
    if (criteria && [criteria length]>0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:criteria];
        if (variables && [variables count]>0) {
            predicate = [predicate predicateWithSubstitutionVariables:variables];
        }
        [fetchRequest setPredicate:predicate];
    }
    
    // sort results by keys which separeted by character ' , '
    if (sortKeys && [sortKeys length]>0) {
        NSArray *keys = [sortKeys componentsSeparatedByString:@","];
        if (keys && [keys count]>0) {
            NSMutableArray *sortDescriptorArray = [NSMutableArray arrayWithCapacity:2];
            for (int i = 0; i<[keys count]; i++) {
                NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:[keys objectAtIndex:i] ascending:isAscending];
                [sortDescriptorArray addObject:sortDescriptor];
            }
            [fetchRequest setSortDescriptors:sortDescriptorArray];
        }
    }
    
    // 0 means no limit
    [fetchRequest setFetchLimit:limit];
    // 0 means no offset
    [fetchRequest setFetchOffset:offset];
    
    // NSFetchRequestResultType
    [fetchRequest setResultType:NSManagedObjectResultType];
    
    if (properties && [properties count]>0) {
        [fetchRequest setPropertiesToFetch:properties];
        [fetchRequest setPropertiesToGroupBy:properties];
        [fetchRequest setResultType:NSDictionaryResultType];
    }
    
    [fetchRequest setReturnsDistinctResults:isDistinct];
    
    return [fetchContext executeFetchRequest:fetchRequest error:error];
}

@end
