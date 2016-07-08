//
//  ChessMulticastBlockBus.m
//  ChessStorage
//
//  Created by Xiangqi on 16/7/8.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "ChessMulticastBlockBus.h"

@interface ChessMulticastBlockNode ()

@property (nonatomic, copy) dispatch_block_t invokeBlock;
@property (nonatomic, strong) dispatch_queue_t invokeQueue;

@end

@implementation ChessMulticastBlockNode

@synthesize invokeBlock, invokeQueue;

- (id)initWithInvokeBlock:(dispatch_block_t)block   invokeQueue:(dispatch_queue_t)aInvokeQueue
{
    if (self = [super init]) {
        invokeBlock = [block copy];
        invokeQueue = aInvokeQueue;
    }
    
    return self;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ChessMulticastBlockBus ()
{
    NSMutableArray *muticastBlockNodesArray;
}

@end

@implementation ChessMulticastBlockBus

@synthesize muticastBlockNodesArray;

- (id)init
{
    if (self = [super init]) {
        muticastBlockNodesArray = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)addInvokeBlock:(dispatch_block_t)block invokeQueue:(dispatch_queue_t)invokeQueue
{
    ChessMulticastBlockNode *node = [[ChessMulticastBlockNode alloc] initWithInvokeBlock:block invokeQueue:invokeQueue];
    [muticastBlockNodesArray addObject:node];
}

- (void)removeAllInvokeBlocks
{
    for (ChessMulticastBlockNode *node in muticastBlockNodesArray) {
        node.invokeBlock = nil;
        node.invokeQueue = nil;
    }
    
    [muticastBlockNodesArray removeAllObjects];
}

- (void)multicastBlocks
{
    for (ChessMulticastBlockNode *node in muticastBlockNodesArray) {
        dispatch_queue_t queue = node.invokeQueue;
        dispatch_block_t block = node.invokeBlock;
        if (queue && block) {
            dispatch_async(queue, block);
        }
    }
    
    [self removeAllInvokeBlocks];
}

@end

