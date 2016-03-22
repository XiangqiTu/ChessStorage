//
//  RosterUtil.h
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RosterStorage.h"

@interface RosterUtil : NSObject

@property (nonatomic, strong) RosterStorage *rosterStorage;

- (void)addNewFriendWithName:(NSString *)name age:(NSInteger)age;

- (void)deleteFriendWithName:(NSString *)name;
@end
