//
//  RosterStorage.h
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChessStorage.h"
#import "FriendEntity.h"

@interface RosterStorage : ChessStorage

- (void)addNewFriendEntityWithName:(NSString *)name age:(NSInteger)age;

@end
