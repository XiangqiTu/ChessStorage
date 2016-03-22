//
//  ChessStorageProtected.h
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "ChessStorage.h"

@interface ChessStorage (Protected)

#pragma mark - Override Method
/**
 * If your subclass needs to do anything for init, it can do so easily by overriding this method.
 * All public init methods will invoke this method at the end of their implementation.
 *
 * Important: If overriden you must invoke [super commonInit] at some point.
 **/
- (void)commonInit;

/**
 * Override me if you need to do anything special just before changes are saved to disk.
 *
 * This method will be invoked on the storageQueue.
 * The default implementation does nothing.
 **/
- (void)willSaveManagedObjectContext;

/**
 * Override me if you need to do anything special after changes have been saved to disk.
 *
 * This method will be invoked on the storageQueue.
 * The default implementation does nothing.
 **/
- (void)didSaveManagedObjectContext;


@end

