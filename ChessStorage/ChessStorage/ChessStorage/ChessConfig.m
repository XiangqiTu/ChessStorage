//
//  ChessConfig.m
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "ChessConfig.h"
#import <objc/runtime.h>

@implementation ChessConfig

@synthesize storeOptions, databaseFileName, managedObjectModelName, storageQueueTag, storageQueue, persistentStoreDirectory = _persistentStoreDirectory;

- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName managedObjectModelName:(NSString *)aManagedObjectModelName
{
    if ((self = [super init]))
    {
        managedObjectModelName = aManagedObjectModelName;
        
        if (aDatabaseFileName)
            databaseFileName = [NSString stringWithFormat:@"%@.sqlite", [aDatabaseFileName copy]];
        else
            databaseFileName = [[self defaultDatabaseFileName] copy];
        
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    storeOptions = [self defaultStoreOptions];
    
    storageQueue = dispatch_queue_create(class_getName([self class]), NULL);
    
    storageQueueTag = &storageQueueTag;
    dispatch_queue_set_specific(storageQueue, storageQueueTag, storageQueueTag, NULL);
}

#pragma mark - Override Method
- (NSBundle *)managedObjectModelBundle
{
    return [NSBundle bundleForClass:[self class]];
}

- (NSString *)defaultDatabaseFileName
{
    // Override me, if needed, to provide customized behavior.
    //
    // This method is queried if the initWithDatabaseFileName:storeOptions: method is invoked with a nil parameter for databaseFileName.
    //
    // You are encouraged to use the sqlite file extension.
    
    return [NSString stringWithFormat:@"%@.sqlite", managedObjectModelName];
}

- (NSDictionary *)defaultStoreOptions
{
    // Override me, if needed, to provide customized behavior.
    //
    // This method is queried if the initWithDatabaseFileName:storeOptions: method is invoked with a nil parameter for defaultStoreOptions.
    
    NSDictionary *defaultStoreOptions = nil;
    
    if(databaseFileName)
    {
        defaultStoreOptions = @{ NSMigratePersistentStoresAutomaticallyOption: @(YES),
                                 NSInferMappingModelAutomaticallyOption : @(YES) };
    }
    
    return defaultStoreOptions;
}

- (void)willCreatePersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)theStoreOptions
{
    // Override me, if needed, to provide customized behavior.
    //
    // If you are using a database file with pure non-persistent data (e.g. for memory optimization purposes on iOS),
    // you may want to delete the database file if it already exists on disk.
    //
    // If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
    // If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
}

- (BOOL)addPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)theStoreOptions error:(NSError **)errorPtr
{
    // Override me, if needed, to completely customize the persistent store.
    //
    // Adds the persistent store path to the persistent store coordinator.
    // Returns true if the persistent store is created.
    //
    // If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
    // If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
    
    NSPersistentStore *persistentStore;
    
    if (storePath)
    {
        // SQLite persistent store
        
        NSURL *storeUrl = [NSURL fileURLWithPath:storePath];
        
        persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                   configuration:nil
                                                                             URL:storeUrl
                                                                         options:storeOptions
                                                                           error:errorPtr];
    }
    else
    {
        // In-Memory persistent store
        persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType
                                                                   configuration:nil
                                                                             URL:nil
                                                                         options:nil
                                                                           error:errorPtr];
    }
    
    return persistentStore != nil;
}

- (void)didNotAddPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)theStoreOptions error:(NSError *)error
{
    // Override me, if needed, to provide customized behavior.
    //
    // For example, if you are using the database for non-persistent data and the model changes,
    // you may want to delete the database file if it already exists on disk.
    //
    // E.g:
    //
    // [[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
    // [self addPersistentStoreWithPath:storePath error:NULL];
    //
    // This method is invoked on the storageQueue.
}

- (void)didCreateManagedObjectContext
{
    // Override me to provide customized behavior.
    // For example, you may want to perform cleanup of any non-persistent data before you start using the database.
    //
    // This method is invoked on the storageQueue.
}

- (void)mainThreadManagedObjectContextDidMergeChanges
{
    // Override me if you want to do anything special when changes get propogated to the main thread.
    //
    // This method is invoked on the main thread.
}

#pragma mark - CoreData Setup
- (NSString *)persistentStoreDirectory
{
    if (_persistentStoreDirectory) {
        return _persistentStoreDirectory;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    
    // Attempt to find a name for this application
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (appName == nil) {
        appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    }
    
    if (appName == nil) {
        appName = @"Chess";
    }
    
    
    NSString *result = [basePath stringByAppendingPathComponent:appName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:result])
    {
        [fileManager createDirectoryAtPath:result withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return result;
}

- (void)setPersistentStoreDirectory:(NSString *)persistenStoreDirectoryPath
{
    _persistentStoreDirectory = persistenStoreDirectoryPath;
}

- (NSManagedObjectModel *)managedObjectModel
{
    // This is a public method.
    // It may be invoked on any thread/queue.
    
    __block NSManagedObjectModel *result = nil;
    
    dispatch_block_t block = ^{ @autoreleasepool {
        if (managedObjectModel)
        {
            result = managedObjectModel;
            return;
        }
        
        NSString *momName = [self managedObjectModelName];
        NSString *momPath = [[self managedObjectModelBundle] pathForResource:momName ofType:@"mom"];
        if (momPath == nil)
        {
            // The model may be versioned or created with Xcode 4, try momd as an extension.
            momPath = [[self managedObjectModelBundle] pathForResource:momName ofType:@"momd"];
        }
        
        if (momPath)
        {
            // If path is nil, then NSURL or NSManagedObjectModel will throw an exception
            NSURL *momUrl = [NSURL fileURLWithPath:momPath];
            managedObjectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:momUrl] copy];
        }
        
        if([NSAttributeDescription instancesRespondToSelector:@selector(setAllowsExternalBinaryDataStorage:)])
        {
            if(autoAllowExternalBinaryDataStorage)
            {
                NSArray *entities = [managedObjectModel entities];
                for(NSEntityDescription *entity in entities)
                {
                    NSDictionary *attributesByName = [entity attributesByName];
                    [attributesByName enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                        if([obj attributeType] == NSBinaryDataAttributeType)
                        {
                            [obj setAllowsExternalBinaryDataStorage:YES];
                        }
                    }];
                }
            }
        }
        
        result = managedObjectModel;
    }};
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    // This is a public method.
    // It may be invoked on any thread/queue.
    
    __block NSPersistentStoreCoordinator *result = nil;
    dispatch_block_t block = ^{ @autoreleasepool {
        if (persistentStoreCoordinator)
        {
            result = persistentStoreCoordinator;
            return;
        }
        
        NSManagedObjectModel *mom = [self managedObjectModel];
        if (mom == nil)
        {
            return;
        }
        
        persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
        
        if (databaseFileName)
        {
            // SQLite persistent store
            NSString *docsPath = [self persistentStoreDirectory];
            NSString *storePath = [docsPath stringByAppendingPathComponent:databaseFileName];
            if (storePath)
            {
                // If storePath is nil, then NSURL will throw an exception
                if(autoRemovePreviousDatabaseFile)
                {
                    if ([[NSFileManager defaultManager] fileExistsAtPath:storePath])
                    {
                        [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
                    }
                }
                
                [self willCreatePersistentStoreWithPath:storePath options:storeOptions];
                
                NSError *error = nil;
                BOOL didAddPersistentStore = [self addPersistentStoreWithPath:storePath options:storeOptions error:&error];
                if(autoRecreateDatabaseFile && !didAddPersistentStore)
                {
                    [[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
                    
                    didAddPersistentStore = [self addPersistentStoreWithPath:storePath options:storeOptions error:&error];
                }
                
                if (!didAddPersistentStore)
                {
                    [self didNotAddPersistentStoreWithPath:storePath options:storeOptions error:error];
                }
            }
        }
        else
        {
            // In-Memory persistent store
            [self willCreatePersistentStoreWithPath:nil options:storeOptions];
            
            NSError *error = nil;
            if (![self addPersistentStoreWithPath:nil options:storeOptions error:&error])
            {
                [self didNotAddPersistentStoreWithPath:nil options:storeOptions error:error];
            }
        }
        
        result = persistentStoreCoordinator;
    }};
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (NSManagedObjectContext *)managedObjectContext
{
    // This is a private method.
    //
    // NSManagedObjectContext is NOT thread-safe.
    // Therefore it is VERY VERY BAD to use our private managedObjectContext outside our private storageQueue.
    //
    // You should NOT remove the assert statement below!
    // You should NOT give external classes access to the storageQueue! (Excluding subclasses obviously.)
    //
    // When you want a managedObjectContext of your own (again, excluding subclasses),
    // you can use the mainThreadManagedObjectContext (below),
    // or you should create your own using the public persistentStoreCoordinator.
    //
    // If you even comtemplate ignoring this warning,
    // then you need to go read the documentation for core data,
    // specifically the section entitled "Concurrency with Core Data".
    //
    NSAssert(dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
    //
    // Do NOT remove the assert statment above!
    // Read the comments above!
    //
    
    if (managedObjectContext)
    {
        return managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator)
    {
        managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        managedObjectContext.persistentStoreCoordinator = coordinator;
        managedObjectContext.undoManager = nil;
        
        [self didCreateManagedObjectContext];
    }
    
    return managedObjectContext;
}

- (NSManagedObjectContext *)mainThreadManagedObjectContext
{
    // NSManagedObjectContext is NOT thread-safe.
    // Therefore it is VERY VERY BAD to use this managedObjectContext outside the main thread.
    //
    // You should NOT remove the assert statement below!
    //
    // When you want a managedObjectContext of your own for non-main-thread use,
    // you should create your own using the public persistentStoreCoordinator.
    //
    // If you even comtemplate ignoring this warning,
    // then you need to go read the documentation for core data,
    // specifically the section entitled "Concurrency with Core Data".
    //
    NSAssert([NSThread isMainThread], @"Context reserved for main thread only");
    //
    // Do NOT remove the assert statment above!
    // Read the comments above!
    //
    
    if (mainThreadManagedObjectContext)
    {
        return mainThreadManagedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator)
    {
        mainThreadManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        mainThreadManagedObjectContext.persistentStoreCoordinator = coordinator;
        mainThreadManagedObjectContext.undoManager = nil;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(managedObjectContextDidSave:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:nil];
        
        // Todo: If we knew that our private managedObjectContext was going to be the only one writing to the database,
        // then a small optimization would be to use it as the object when registering above.
    }
    
    return mainThreadManagedObjectContext;
}

- (void)managedObjectContextDidSave:(NSNotification *)notification
{
    NSManagedObjectContext *sender = (NSManagedObjectContext *)[notification object];
    
    if ((sender != mainThreadManagedObjectContext) &&
        (sender.persistentStoreCoordinator == mainThreadManagedObjectContext.persistentStoreCoordinator))
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // http://stackoverflow.com/questions/3923826/nsfetchedresultscontroller-with-predicate-ignores-changes-merged-from-different
            for (NSManagedObject *object in [[notification userInfo] objectForKey:NSUpdatedObjectsKey]) {
                [[mainThreadManagedObjectContext objectWithID:[object objectID]] willAccessValueForKey:nil];
            }
            
            [mainThreadManagedObjectContext mergeChangesFromContextDidSaveNotification:notification];
            [self mainThreadManagedObjectContextDidMergeChanges];
        });
    }
}

- (BOOL)autoRemovePreviousDatabaseFile
{
    __block BOOL result = NO;
    
    dispatch_block_t block = ^{ @autoreleasepool {
        result = autoRemovePreviousDatabaseFile;
    }};
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (void)setAutoRemovePreviousDatabaseFile:(BOOL)flag
{
    dispatch_block_t block = ^{
        autoRemovePreviousDatabaseFile = flag;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
}

- (BOOL)autoRecreateDatabaseFile
{
    __block BOOL result = NO;
    
    dispatch_block_t block = ^{ @autoreleasepool {
        result = autoRecreateDatabaseFile;
    }};
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (void)setAutoRecreateDatabaseFile:(BOOL)flag
{
    dispatch_block_t block = ^{
        autoRecreateDatabaseFile = flag;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
}

- (BOOL)autoAllowExternalBinaryDataStorage
{
    __block BOOL result = NO;
    
    dispatch_block_t block = ^{ @autoreleasepool {
        result = autoAllowExternalBinaryDataStorage;
    }};
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (void)setAutoAllowExternalBinaryDataStorage:(BOOL)flag
{
    dispatch_block_t block = ^{
        autoAllowExternalBinaryDataStorage = flag;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
}
@end
