//
//  ChessMulticastBlockBus.h
//  ChessStorage
//
//  Created by Xiangqi on 16/7/8.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChessMulticastBlockBus : NSObject

@property (nonatomic, strong, readonly) NSMutableArray *muticastBlockNodesArray;

- (void)addInvokeBlock:(dispatch_block_t)block invokeQueue:(dispatch_queue_t)invokeQueue;

- (void)removeAllInvokeBlocks;

- (void)multicastBlocks;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ChessMulticastBlockNode : NSObject

- (id)initWithInvokeBlock:(dispatch_block_t)block   invokeQueue:(dispatch_queue_t)aInvokeQueue;

@end
