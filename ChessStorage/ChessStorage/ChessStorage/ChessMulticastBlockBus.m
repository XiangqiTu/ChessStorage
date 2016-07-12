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
        if (aInvokeQueue)
            invokeQueue = aInvokeQueue;
        else
            invokeQueue = dispatch_get_main_queue();
    }
    
    return self;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ChessMulticastBlockBus ()
{
    NSMutableArray *muticastBlockNodesArray;
    dispatch_queue_t multicastBlockQueue;
    void *multicastBlockQueueTag;
}

@end

@implementation ChessMulticastBlockBus

@synthesize muticastBlockNodesArray;

- (id)initWithMulticastBlockQueue:(dispatch_queue_t)aMulticastBlockQueue multicastBlockQueueTag:(void *)queueTag;
{
    if (self = [super init]) {
        muticastBlockNodesArray = [[NSMutableArray alloc] init];
        multicastBlockQueue = aMulticastBlockQueue;
        multicastBlockQueueTag = queueTag;
    }
    
    return self;
}

- (void)addInvokeBlock:(dispatch_block_t)block invokeQueue:(dispatch_queue_t)invokeQueue
{
    dispatch_block_t aBlock = ^{@autoreleasepool{
        ChessMulticastBlockNode *node = [[ChessMulticastBlockNode alloc] initWithInvokeBlock:block invokeQueue:invokeQueue];
        [muticastBlockNodesArray addObject:node];
    }};
    
    if (dispatch_get_specific(multicastBlockQueueTag))
        aBlock();
    else
        dispatch_async(multicastBlockQueue, aBlock);
}

- (void)removeAllInvokeBlocks
{
    dispatch_block_t aBlock = ^{@autoreleasepool{
        for (ChessMulticastBlockNode *node in muticastBlockNodesArray) {
            node.invokeBlock = nil;
            node.invokeQueue = nil;
        }
        
        [muticastBlockNodesArray removeAllObjects];
    }};
    
    if (dispatch_get_specific(multicastBlockQueueTag))
        aBlock();
    else
        dispatch_async(multicastBlockQueue, aBlock);
}

- (void)multicastBlocks
{
    dispatch_block_t aBlock = ^{@autoreleasepool{
        dispatch_group_t group = dispatch_group_create();
        
        for (ChessMulticastBlockNode *node in muticastBlockNodesArray) {
            dispatch_queue_t queue = node.invokeQueue;
            dispatch_block_t block = [node.invokeBlock copy];
            if (!queue || !block)
                continue;
            
            dispatch_group_async(group, queue, block);
        }
        
        dispatch_group_notify(group, multicastBlockQueue, ^{
            [self removeAllInvokeBlocks];
        });
    }};
    
    if (dispatch_get_specific(multicastBlockQueueTag))
        aBlock();
    else
        dispatch_async(multicastBlockQueue, aBlock);
}

@end

