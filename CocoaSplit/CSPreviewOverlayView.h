//
//  CSPreviewOverlayView.h
//  CocoaSplit
//
//  Created by Zakk on 8/31/15.
//  Copyright (c) 2015 Zakk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "InputSource.h"


@interface CSTextView : NSTextView

@end
@class PreviewView;

@interface CSPreviewOverlayView : NSView
{
    NSButton *_closeButton;
    NSButton *_autoFitButton;
    CSTextView *_sizeTextView;
    
}

@property (weak) InputSource *parentSource;
@property (weak) PreviewView *previewView;
@property (assign) bool renderControls;

-(void)updatePosition;

@end
