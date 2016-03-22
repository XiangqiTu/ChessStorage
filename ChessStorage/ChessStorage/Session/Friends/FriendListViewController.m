//
//  FriendListViewController.m
//  ChessStorage
//
//  Created by Xiangqi on 16/3/21.
//  Copyright © 2016年 Xiangqi. All rights reserved.
//

#import "FriendListViewController.h"
#import "RosterUtil.h"

@interface FriendListViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSFetchedResultsController    *fetchedResultsController;
@property (nonatomic, strong) RosterUtil            *rosterUtil;

@end

@implementation FriendListViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    if (self = [super initWithStyle:style]) {
        self.rosterUtil = [[RosterUtil alloc] init];
        self.fetchedResultsController = [self.rosterUtil fetchedResultsController];
        self.fetchedResultsController.delegate = self;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initNavigationItems];
    [self performFetch];
}

- (void)performFetch
{
    NSError *error = nil;
    if ([self.fetchedResultsController performFetch:&error]) {
        [self.tableView reloadData];
    }
}

- (void)initNavigationItems
{
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add" style:UIBarButtonItemStylePlain
                                                                             target:self action:@selector(respondsToRightBarButton:)];
}

- (void)respondsToRightBarButton:(id)sender
{
    static int t = 0;
    [self.rosterUtil addNewFriendWithName:[NSString stringWithFormat:@"ChessStorage%d",t]
                                      age:t];
    t++;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.fetchedResultsController.fetchedObjects count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *cellIdentifier = @"FriendListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    FriendEntity *entity = (FriendEntity *)[self.fetchedResultsController.fetchedObjects objectAtIndex:indexPath.row];
    [cell.textLabel setText:entity.name];
    [cell.detailTextLabel setText:[entity.age stringValue]];
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        FriendEntity *entity = (FriendEntity *)[self.fetchedResultsController.fetchedObjects objectAtIndex:indexPath.row];
        [self.rosterUtil deleteFriendWithFriendEntity:entity];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - FetchedResultsController Delegate
- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    NSLog(@"At: %ld   newIndex: %ld",indexPath.row,newIndexPath.row );
    switch (type) {
        case NSFetchedResultsChangeInsert:
        {
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationRight];
            [self.tableView scrollToRowAtIndexPath:newIndexPath
                                  atScrollPosition:UITableViewScrollPositionBottom
                                          animated:YES];
            break;
        }
            case NSFetchedResultsChangeDelete:
        {
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
            break;
        }
        case NSFetchedResultsChangeUpdate:
        {
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
            case NSFetchedResultsChangeMove:
        {
            [self.tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
            break;
        }
        default:
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    
}

@end
