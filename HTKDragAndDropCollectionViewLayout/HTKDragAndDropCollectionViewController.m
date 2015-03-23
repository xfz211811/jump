//
//  HTKDragAndDropCollectionViewController.m
//  HTKDragAndDropCollectionView
//
//  Created by Henry T Kirk on 11/9/14.
//  Copyright (c) 2014 Henry T. Kirk (http://www.henrytkirk.info)
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "HTKDragAndDropCollectionViewController.h"
#import <objc/runtime.h>

@interface HTKDragAndDropCollectionView () <UICollectionViewDelegate>

/**
 * Helper method that will scroll the collectionView up or down
 * based on if the cell being dragged is out of it's visible bounds or not.
 * Defaults to 10pt buffer and moves 1pt at a time. It will "speed up" when
 * you drag the cell further past the 10pt buffer.
 */
- (void)scrollIfNeededWhileDraggingCell:(UICollectionViewCell *)cell;

@end

@implementation HTKDragAndDropCollectionView

// self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[[HTKDragAndDropCollectionViewLayout alloc] init]];
- (instancetype)initWithFrame:(CGRect)frame
{
    if([super initWithFrame:frame collectionViewLayout:[[HTKDragAndDropCollectionViewLayout alloc] init]])
    {
        self.backgroundColor = [UIColor whiteColor];
        //    self.delegate = self;
        //    self.dataSource = self;
        if(![self.delegate respondsToSelector:@selector(collectionView:willDisplayCell:forItemAtIndexPath:)])
        {
            Method addMethod = class_getInstanceMethod([self class], @selector(collectionView:willDisplayCell:forItemAtIndexPath:));
            IMP addMethodImp = method_getImplementation(addMethod);
            class_addMethod([self.delegate class], @selector(collectionView:willDisplayCell:forItemAtIndexPath:), addMethodImp, method_getTypeEncoding(addMethod));
        }
        //
        Method sendEvent = class_getInstanceMethod([self.delegate class], @selector(collectionView:willDisplayCell:forItemAtIndexPath:));
        Method sendEventMySelf = class_getInstanceMethod([self class], @selector(xcollectionView:willDisplayCell:forItemAtIndexPath:));
        method_exchangeImplementations(sendEvent, sendEventMySelf);
    }
    return self;
    // 将目标函数的原实现绑定到sendEventOriginalImplemention方法上

//    
    // 然后用我们自己的函数的实现，替换目标函数对应的实现
    //IMP sendEventMySelfImp = method_getImplementation(sendEventMySelf);
    //class_replaceMethod([self.delegate class], @selector(sendEvent:), sendEventMySelfImp, method_getTypeEncoding(sendEvent));
}

- (void)xcollectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    ((HTKDraggableCollectionViewCell *)cell).editing = self.isEditing;
    [self xcollectionView:collectionView willDisplayCell:cell forItemAtIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath{}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;
    NSArray *cells = [self visibleCells];
    [cells enumerateObjectsUsingBlock:^(HTKDraggableCollectionViewCell *cell, NSUInteger idx, BOOL *stop) {
        cell.editing = _editing;
    }];
}

#pragma mark - HTKDraggableCollectionViewCellDelegate

- (void)userDidBeginDraggingCell:(UICollectionViewCell *)cell {
    
    HTKDragAndDropCollectionViewLayout *flowLayout = (HTKDragAndDropCollectionViewLayout *)self.collectionViewLayout;
    // Set the indexPath that we're beginning to drag
    flowLayout.draggedIndexPath = [self indexPathForCell:cell];
    // Set it's frame so if we have to reset it, we know where to put it.
    flowLayout.draggedCellFrame = cell.frame;
}

- (void)userDidEndDraggingCell:(UICollectionViewCell *)cell {
    
    HTKDragAndDropCollectionViewLayout *flowLayout = (HTKDragAndDropCollectionViewLayout *)self.collectionViewLayout;

    // Reset
    [flowLayout resetDragging];
}

- (void)userDidDragCell:(UICollectionViewCell *)cell withGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    
    HTKDragAndDropCollectionViewLayout *flowLayout = (HTKDragAndDropCollectionViewLayout *)self.collectionViewLayout;
    CGPoint translation = [recognizer translationInView:self];
    // Determine our new center
    CGPoint newCenter = CGPointMake(recognizer.view.center.x + translation.x,
                                    recognizer.view.center.y + translation.y);
    // Set center
    flowLayout.draggedCellCenter = newCenter;
    [recognizer setTranslation:CGPointZero inView:self];
    
    // swap items if needed
    [flowLayout exchangeItemsIfNeeded];
    
    // Scroll down if we're holding cell off screen vertically
    UICollectionViewCell *draggedCell = [self cellForItemAtIndexPath:flowLayout.draggedIndexPath];
    [self scrollIfNeededWhileDraggingCell:draggedCell];
}

#pragma mark - Helper Methods

- (void)scrollIfNeededWhileDraggingCell:(UICollectionViewCell *)cell {
 
    HTKDragAndDropCollectionViewLayout *flowLayout = (HTKDragAndDropCollectionViewLayout *)self.collectionViewLayout;
    if (![flowLayout isDraggingCell]) {
        // If we've stopped dragging, exit
        return;
    }
    
    CGPoint cellCenter = flowLayout.draggedCellCenter;
    // Offset we will be adjusting
    CGPoint newOffset = self.contentOffset;
    // How far past edge does it need to be before scrolling
    CGFloat buffer = 10;
    
    // Check for scrolling down
    CGFloat bottomY = self.contentOffset.y + CGRectGetHeight(self.frame);
    if (bottomY < CGRectGetMaxY(cell.frame) - buffer) {
        // We're scrolling down
        newOffset.y += 1;
        
        if (newOffset.y + CGRectGetHeight(self.bounds) > self.contentSize.height) {
            return; // Stop moving, went too far
        }
        
        // adjust cell's center by 1
        cellCenter.y += 1;
    }
    
    // Check if moving upwards
    CGFloat offsetY = self.contentOffset.y;
    if (CGRectGetMinY(cell.frame) + buffer < offsetY) {
        // We're scrolling up
        newOffset.y -= 1;
        
        if (newOffset.y <= 0) {
            return; // Stop moving, went too far
        }
        
        // adjust cell's center by 1
        cellCenter.y -= 1;
    }
    
    // Set new values
    self.contentOffset = newOffset;
    flowLayout.draggedCellCenter = cellCenter;
    // Repeat until we went to far.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollIfNeededWhileDraggingCell:cell];
    });
}

@end

// 版权属于原作者
// http://code4app.com (cn) http://code4app.net (en)
// 发布代码于最专业的源码分享网站: Code4App.com 
