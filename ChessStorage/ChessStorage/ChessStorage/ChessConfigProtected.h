//
//  ChessConfigProtected.h
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "ChessConfig.h"

@interface ChessConfig (Protected)

#pragma mark - Override Method

/**
 * Override me, if needed, to provide customized behavior.
 *
 * This method is queried to get the bundle containing the ManagedObjectModel.
 **/
- (NSBundle *)managedObjectModelBundle;

/**
 * Override me, if needed, to provide customized behavior.
 *
 * This method is queried if the initWithDatabaseFileName:storeOptions: method is invoked with a nil parameter for databaseFileName.
 * The default implementation returns:
 *
 * [NSString stringWithFormat:@"%@.sqlite", [self managedObjectModelName]];
 *
 * You are encouraged to use the sqlite file extension.
 **/
- (NSString *)defaultDatabaseFileName;


/**
 * Override me, if needed, to provide customized behavior.
 *
 * This method is queried if the initWithDatabaseFileName:storeOptions method is invoked with a nil parameter for storeOptions.
 * The default implementation returns the following:
 *
 * @{ NSMigratePersistentStoresAutomaticallyOption: @(YES),
 *    NSInferMappingModelAutomaticallyOption : @(YES) };
 **/
- (NSDictionary *)defaultStoreOptions;

/**
 * Override me, if needed, to provide customized behavior.
 *
 * If you are using a database file with pure non-persistent data (e.g. for memory optimization purposes on iOS),
 * you may want to delete the database file if it already exists on disk.
 *
 * If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
 * If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
 *
 * The default implementation does nothing.
 **/
- (void)willCreatePersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)storeOptions;

/**
 * Override me, if needed, to completely customize the persistent store.
 *
 * Adds the persistent store path to the persistent store coordinator.
 * Returns true if the persistent store is created.
 *
 * If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
 * If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
 **/
- (BOOL)addPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)storeOptions error:(NSError **)errorPtr;

/**
 * Override me, if needed, to provide customized behavior.
 *
 * For example, if you are using the database for non-persistent data and the model changes, you may want
 * to delete the database file if it already exists on disk and a core data migration is not worthwhile.
 *
 * If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
 * If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
 *
 * The default implementation simply writes to the  error log.
 **/
- (void)didNotAddPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)storeOptions error:(NSError *)error;

/**
 * Override me, if needed, to provide customized behavior.
 *
 * For example, you may want to perform cleanup of any non-persistent data before you start using the database.
 *
 * The default implementation does nothing.
 **/
- (void)didCreateManagedObjectContext;

/**
 * This method will be invoked on the main thread,
 * after the mainThreadManagedObjectContext has merged changes from another context.
 *
 * This method may be useful if you have code dependent upon when changes the datastore hit the user interface.
 * For example, you want to play a sound when a message is received.
 * You could play the sound right away, from the background queue, but the timing may be slightly off because
 * the user interface won't update til the changes have been saved to disk,
 * and then propogated to the managedObjectContext of the main thread.
 * Alternatively you could set a flag, and then hook into this method
 * to play the sound at the exact moment the propogation hits the main thread.
 *
 * The default implementation does nothing.
 **/
- (void)mainThreadManagedObjectContextDidMergeChanges;

@end