//
//  ChessStorage.h
//  ChessStorage
//
//  Created by Xiangqi on 16/3/19.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "ChessConfig.h"

/**
 * This class provides an optional base class that may be used to implement
 * a CoreDataStorage class (or perhaps any core data storage class).
 *
 * It operates on its own dispatch queue which allows it to easily provide storage for multiple extension instance.
 * More importantly, it smartly buffers its save operations to maximize performance!
 *
 * It does this using two techniques:
 *
 * First, it monitors the number of pending requests.
 * When a operation is requested of the class, it increments an atomic variable, and schedules the request.
 * After the request has been processed, it decrements the atomic variable.
 * At this point it knows if there are other pending requests,
 * and it uses the information to decide if it should save now,
 * or postpone the save operation until the pending requests have been executed.
 *
 * Second, it monitors the number of unsaved changes.
 * Since NSManagedObjectContext retains any changed objects until they are saved to disk
 * it is an important memory management concern to keep the number of changed objects within a healthy range.
 * This class uses a configurable saveThreshold to save at appropriate times.
 *
 * This class also offers several useful features such as
 * preventing multiple instances from using the same database file (conflict)
 *
 * For more information on how to extend this class,
 * please see the ChessStorageProtected.h header file.
 *
 * Feel free to skim over these as reference implementations.
 **/

@interface ChessStorage : NSObject
{
@private
    int32_t pendingRequests;
    
    NSMutableArray *willSaveManagedObjectContextBlocks;
    NSMutableArray *didSaveManagedObjectContextBlocks;
    
@protected
    NSUInteger saveThreshold;
    NSUInteger saveCount;
}

/**
 * The saveThreshold specifies the maximum number of unsaved changes to NSManagedObjects before a save is triggered.
 *
 * Since NSManagedObjectContext retains any changed objects until they are saved to disk
 * it is an important memory management concern to keep the number of changed objects within a healthy range.
 *
 * Default 500
 **/
@property (readwrite) NSUInteger saveThreshold;

/**
 * Convenience method to get a managedObjectContext appropriate for use on the main thread.
 * This context should only be used from the main thread.
 *
 * NSManagedObjectContext is a light-weight thread-UNsafe component of the CoreData stack.
 * Thus a managedObjectContext should only be accessed from a single thread, or from a serialized queue.
 *
 * A managedObjectContext is associated with a persistent store.
 * In most cases the persistent store is an sqlite database file.
 * So think of a managedObjectContext as a thread-specific cache for the underlying database.
 *
 * This method lazily creates a proper managedObjectContext,
 * associated with the persistent store of this instance,
 * and configured to automatically merge changesets from other threads.
 **/
@property (weak, readonly) NSManagedObjectContext *mainThreadManagedObjectContext;
@property (weak, readonly) NSManagedObjectContext *managedObjectContext;

/**
 *
 * Initializes a core data storage instance with ChessConfig.
 * ChessConfig  defines Core Data storage on how to configure the basic structures,
 * and contexts of the merger notification
 *
 */
- (id)initWithConfiguration:(ChessConfig *)configuration;

#pragma mark Performance Optimizations

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

/**
 * This method synchronously invokes the given block (dispatch_sync) on the storageQueue.
 *
 * Prior to dispatching the block it increments (atomically) the number of pending requests.
 * After the block has been executed, it decrements (atomically) the number of pending requests,
 * and then invokes the maybeSave method which implements the logic behind the optimized disk IO.
 *
 * If you use the executeBlock and scheduleBlock methods for all your database operations,
 * you will automatically inherit optimized disk IO for free.
 *
 * If you manually invoke [managedObjectContext save:] you are destroying the optimizations provided by this class.
 *
 * The block handed to this method is automatically wrapped in a NSAutoreleasePool,
 * so there is no need to create these yourself as this method automatically handles it for you.
 *
 * The architecture of this class purposefully puts the CoreDataStorage instance on a separate dispatch_queue
 * from the parent . Not only does this allow a single storage instance to service multiple extension
 * instances, but it provides the mechanism for the disk IO optimizations. The theory behind the optimizations
 * is to delay a save of the data (a slow operation) until the storage class is no longer being used. With xmpp
 * it is often the case that a burst of data causes a flurry of queries and/or updates for a storage class.
 * Thus the theory is to delay the slow save operation until later when the flurry has ended and the storage
 * class no longer has any pending requests.
 *
 * This method is designed to be invoked from within the XmppExtension storage protocol methods.
 * In other words, it is expecting to be invoked from a dispatch_queue other than the storageQueue.
 * If you attempt to invoke this method from within the storageQueue, an exception is thrown.
 * Therefore care should be taken when designing your implementation.
 * The recommended procedure is as follows:
 *
 * All of the methods that implement the XmppExtension storage protocol invoke either executeBlock or scheduleBlock.
 * However, none of these methods invoke each other (they are only to be invoked from the XmppExtension instance).
 * Instead, create internal utility methods that may be invoked.
 *
 **/
- (void)executeBlock:(dispatch_block_t)block;

/**
 * This method asynchronously invokes the given block (dispatch_async) on the storageQueue.
 *
 * It works very similarly to the executeBlock method.
 * See the executeBlock method above for a full discussion.
 **/
- (void)scheduleBlock:(dispatch_block_t)block;

/**
 * Sometimes you want to call a method before calling save on a Managed Object Context e.g. willSaveObject:
 *
 * addWillSaveManagedObjectContextBlock allows you to add a block of code to be called before saving a Managed Object Context,
 * without the overhead of having to call save at that moment.
 **/
- (void)addWillSaveManagedObjectContextBlock:(void (^)(void))willSaveBlock;

/**
 * Sometimes you want to call a method after calling save on a Managed Object Context e.g. didSaveObject:
 *
 * addDidSaveManagedObjectContextBlock allows you to add a block of code to be after saving a Managed Object Context,
 * without the overhead of having to call save at that moment.
 **/
- (void)addDidSaveManagedObjectContextBlock:(void (^)(void))didSaveBlock;

#pragma mark - Fetch Method

- (NSArray *)fetchEntityName:(NSString *)entityName
                    criteria:(NSString *)criteria
                   variables:(NSDictionary *)variables
                      sortBy:(NSString *)sortKeys
                   ascending:(BOOL)isAscending;

/**
 *
 *  According mark, execute the query function in the right context,
 *  and returns a array which contains fetched results(Type of NSManagedObjectResultType).
 *
 *  @param entityName  <#entityName description#>
 *  @param criteria    <#criteria description#>
 *  @param variables   <#variables description#>
 *  @param sortKeys    <#sortKeys description#>
 *  @param isAscending <#isAscending description#>
 *  @param offset      <#offset description#>
 *  @param limit       <#limit description#>
 *  @param properties  <#properties description#>
 *  @param isDistinct  <#isDistinct description#>
 *  @param error       <#error description#>
 *
 *  @return <#return value description#>
 */
- (NSArray *)fetchEntityName:(NSString *)entityName
                    criteria:(NSString *)criteria
                   variables:(NSDictionary *)variables
                      sortBy:(NSString *)sortKeys
                   ascending:(BOOL)isAscending
                 fetchOffset:(NSInteger)offset
                  fetchLimit:(NSInteger)limit
          propertiesToReturn:(NSArray*)properties
                    distinct:(BOOL)isDistinct
                       error:(NSError **)error;

@end
