//
//  ChessConfig.h
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
/**
 *
 * ChessConfig  defines Core Data storage on how to configure the basic structures
 * and contexts of the merger notification
 *
 * For more information on how to extend this class,
 * please see the ChessConfigProtected.h header file.
 *
 * Feel free to skim over these as reference implementations.
 **/

@interface ChessConfig : NSObject
{
@private
    NSManagedObjectModel *managedObjectModel;
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectContext *managedObjectContext;
    NSManagedObjectContext *mainThreadManagedObjectContext;
    
    BOOL autoRemovePreviousDatabaseFile;
    BOOL autoRecreateDatabaseFile;
    BOOL autoAllowExternalBinaryDataStorage;
    
@protected
    NSString *databaseFileName;
    NSString *managedObjectModelName;
    NSDictionary *storeOptions;
    
    dispatch_queue_t storageQueue;
    void * storageQueueTag;
}

@property (nonatomic, readonly) NSString *databaseFileName;
@property (nonatomic, readonly) NSString *managedObjectModelName;

@property (nonatomic, strong, readonly) dispatch_queue_t storageQueue;
@property (nonatomic, assign, readonly) void *storageQueueTag;

/**
 * Readonly access to the databaseOptions used during initialization.
 * If nil was passed to the init method, returns the actual databaseOptions being used (the default databaseOptions).
 **/
@property (readonly) NSDictionary *storeOptions;

/**
 * Provides access to the the thread-safe components of the CoreData stack.
 *
 * Please note:
 * The managedObjectContext is private to the storageQueue.
 * If you're on the main thread you can use the mainThreadManagedObjectContext.
 * Otherwise you must create and use your own managedObjectContext.
 *
 * If you think you can simply add a property for the private managedObjectContext,
 * then you need to go read the documentation for core data,
 * specifically the section entitled "Concurrency with Core Data".
 *
 * @see mainThreadManagedObjectContext
 **/
@property (strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

/**
 * Convenience method to get a managedObjectContext appropriate for use on the main thread.
 * This context should only be used from the main thread,
 * and configured to automatically merge changesets from other threads.
 *
 * NSManagedObjectContext is a light-weight thread-UNsafe component of the CoreData stack.
 * Thus a managedObjectContext should only be accessed from a single thread, or from a serialized queue.
 *
 * A managedObjectContext is associated with a persistent store.
 * In most cases the persistent store is an sqlite database file.
 * So think of a managedObjectContext as a thread-specific cache for the underlying database.
 *
 **/
@property (nonatomic, strong, readonly) NSManagedObjectContext *mainThreadManagedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;

/**
 * The Previous Database File is removed before creating a persistant store.
 *
 * Default NO
 **/

@property (readwrite) BOOL autoRemovePreviousDatabaseFile;

/**
 * The Database File is automatically recreated if the persistant store cannot read it e.g. the model changed or the file became corrupt.
 * For greater control overide didNotAddPersistentStoreWithPath:
 *
 * Default NO
 **/
@property (readwrite) BOOL autoRecreateDatabaseFile;

/**
 * This method calls setAllowsExternalBinaryDataStorage:YES for all Binary Data Attributes in the Managed Object Model.
 * On OS Versions that do not support external binary data storage, this property does nothing.
 *
 * Default NO
 **/
@property (readwrite) BOOL autoAllowExternalBinaryDataStorage;

/**
 * Initializes a core data storage instance, backed by SQLite, with the given database store filename.
 * It is recommended your database filname use the "sqlite" file extension (e.g. "XMPPRoster.sqlite").
 * managedObjectModelName should return the name of the appropriate file (*.xdatamodel / *.mom / *.momd) sans file extension.
 **/
- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName managedObjectModelName:(NSString *)aManagedObjectModelName;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@property (nonatomic, copy) NSString *persistentStoreDirectory;
/**
 * The standard persistentStoreDirectory method.
 **/
- (NSString *)persistentStoreDirectory;

- (void)setPersistentStoreDirectory:(NSString *)persistenStoreDirectoryPath;

@end
