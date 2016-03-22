//
//  RosterStorage.m
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "RosterStorage.h"

@implementation RosterStorage

- (void)addNewFriendEntityWithName:(NSString *)name age:(NSInteger)age
{
    [self scheduleBlock:^{
        NSString *criteria = [NSString stringWithFormat:@"name = $name && age = $age"];
        NSArray *result = [self fetchEntityName:kRosterFriendEntityName
                                       criteria:criteria
                                      variables:@{@"name": name,
                                                  @"age": @(age)}
                                         sortBy:nil
                                      ascending:YES];
        
        FriendEntity *entity = nil;
        NSManagedObjectContext *context = [self managedObjectContext];
        if ([result count]) {
            // Need to update
            entity = result[0];
        } else {
            // Need to add a new record
            entity = (FriendEntity *)[[NSManagedObject alloc] initWithEntity:[NSEntityDescription entityForName:kRosterFriendEntityName inManagedObjectContext:context] insertIntoManagedObjectContext:context];
        }
        
        entity.name = name;
        entity.age = @(age);
        // context will auto perform saving action, and then post contextDidMergeNotification
    }];
}

- (void)deleteFriendEntity:(FriendEntity *)entity
{
    //MainThreadManangedObjectContext
    NSManagedObjectContext *context = entity.managedObjectContext;
    if ([context isEqual:[self mainThreadManagedObjectContext]]) {
        [context deleteObject:entity];
    } else {
        [self scheduleBlock:^{
            [context deleteObject:entity];
        }];
    }
}
@end
