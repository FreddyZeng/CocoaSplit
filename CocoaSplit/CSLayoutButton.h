//
//  CSLayoutButton.h
//  CocoaSplit
//
//  Created by Zakk on 10/4/15.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class CSLayoutCollectionItem;


@interface CSLayoutButton : NSButton
{
    NSEvent *_savedMouseDown;
}


@property (weak) IBOutlet CSLayoutCollectionItem *viewController;


@end
