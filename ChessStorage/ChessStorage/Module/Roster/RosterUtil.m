//
//  RosterUtil.m
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "RosterUtil.h"

@interface RosterUtil ()

@property (nonatomic, strong) RosterStorage *rosterStorage;

@end

@implementation RosterUtil

- (id)init
{
    if (self = [super init]) {
        ChessConfig *config = [[ChessConfig alloc] initWithDatabaseFilename:@"Roster"
                                                     managedObjectModelName:@"Roster"];
        self.rosterStorage = [[RosterStorage alloc] initWithConfiguration:config];
    }
    
    return self;
}

- (NSFetchedResultsController *)fetchedResultsController
{
    NSManagedObjectContext *moc = [self.rosterStorage mainThreadManagedObjectContext];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kRosterFriendEntityName
                                              inManagedObjectContext:moc];
    NSFetchRequest *request = [[NSFetchRequest alloc]init];
    NSPredicate *pridicate = [NSPredicate predicateWithFormat:@"name != nil"];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"age" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [request setFetchLimit:20];
    [request setFetchBatchSize:20];
    [request setReturnsDistinctResults:NO];
    [request setSortDescriptors:sortDescriptors];
    [request setEntity:entity];
    [request setPredicate:pridicate];
    
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:moc
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)addNewFriendWithName:(NSString *)name age:(NSInteger)age
{
    // Run some other code
    // ...
    //
    // Add new record
    [self.rosterStorage addNewFriendEntityWithName:name age:age];
}

- (void)deleteFriendWithFriendEntity:(FriendEntity *)entity;
{
    // Run some other code
    // ...
    //
    // Delete record
    [self.rosterStorage deleteFriendEntity:entity];
}

@end
