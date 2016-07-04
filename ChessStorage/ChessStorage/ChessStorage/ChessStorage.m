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

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

@interface ChessStorage ()

@property (nonatomic, strong) ChessConfig   *config;
@property (nonatomic, weak) dispatch_queue_t storageQueue;
@property (nonatomic, assign) void *storageQueueTag;

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

#pragma mark Setup

- (void)commonInit
{
    saveThreshold = 500;
    
    willSaveManagedObjectContextBlocks = [[NSMutableArray alloc] init];
    didSaveManagedObjectContextBlocks = [[NSMutableArray alloc] init];
    
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

#pragma mark Override Me

- (void)willSaveManagedObjectContext
{
    // Override me if you need to do anything special just before changes are saved to disk.
    //
    // This method is invoked on the storageQueue.
}

- (void)didSaveManagedObjectContext
{
    // Override me if you need to do anything special after changes have been saved to disk.
    //
    // This method is invoked on the storageQueue.
}

#pragma mark Utilities

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
    
    for(void (^block)(void) in willSaveManagedObjectContextBlocks) {
        block();
    }
    
    [willSaveManagedObjectContextBlocks removeAllObjects];
    
    NSError *error = nil;
    
    if ([[self managedObjectContext] save:&error]){
        saveCount++;
        
        for(void (^block)(void) in didSaveManagedObjectContextBlocks) {
            block();
        }
        
        [didSaveManagedObjectContextBlocks removeAllObjects];
    }
    else
    {
        
        [[self managedObjectContext] rollback];
        
        [didSaveManagedObjectContextBlocks removeAllObjects];
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

- (void)addWillSaveManagedObjectContextBlock:(void (^)(void))willSaveBlock
{
    dispatch_block_t block = ^{
        [willSaveManagedObjectContextBlocks addObject:[willSaveBlock copy]];
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
}

- (void)addDidSaveManagedObjectContextBlock:(void (^)(void))didSaveBlock
{
    dispatch_block_t block = ^{
        [didSaveManagedObjectContextBlocks addObject:[didSaveBlock copy]];
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
}

#pragma mark Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
#if !OS_OBJECT_USE_OBJC
    if (storageQueue)
        dispatch_release(storageQueue);
#endif
}

#pragma mark - Fetch Method

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
