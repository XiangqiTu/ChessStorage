//
//  ChessMulticastBlockBus.h
//  ChessStorage
//
//  Created by Xiangqi on 16/7/8.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  ChessMulticastBlockBus is thread safe while you initialize with method 'initWithMulticastBlockQueue: multicastBlockQueueTag: multicastBlockQueueTag:
 */

@interface ChessMulticastBlockBus : NSObject

@property (nonatomic, strong, readonly) NSMutableArray *muticastBlockNodesArray;

- (id)initWithMulticastBlockQueue:(dispatch_queue_t)aMulticastBlockQueue multicastBlockQueueTag:(void *)queueTag;

- (void)addInvokeBlock:(dispatch_block_t)block invokeQueue:(dispatch_queue_t)invokeQueue;

- (void)removeAllInvokeBlocks;

/**
 *  Invoke all blocks in muticastBlockNodesArray, and reset muticastBlockNodesArray.
 */
- (void)multicastBlocks;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ChessMulticastBlockNode : NSObject

- (id)initWithInvokeBlock:(dispatch_block_t)block   invokeQueue:(dispatch_queue_t)aInvokeQueue;

@end
