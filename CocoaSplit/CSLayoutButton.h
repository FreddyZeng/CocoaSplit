//
//  CSLayoutButton.h
//  CocoaSplit
//
//  Created by Zakk on 10/4/15.
//  Copyright © 2015 Zakk. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CSLayoutCollectionItem;


@interface CSLayoutButton : NSButton
{
    NSEvent *_savedMouseDown;
}


@property (weak) IBOutlet CSLayoutCollectionItem *viewController;


@end
