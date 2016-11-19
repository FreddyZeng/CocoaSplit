//
//  CSLayoutEditWindowController.h
//  CocoaSplit
//
//  Created by Zakk on 10/12/15.
//  Copyright © 2015 Zakk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SourceLayout.h"
#import "PreviewView.h"


@interface CSLayoutEditWindowController : NSWindowController <NSWindowDelegate, NSOutlineViewDelegate, NSTableViewDelegate>
{
    float _frame_interval;
    NSPopover *_animatepopOver;
    NSPopover *_addInputpopOver;
    
    

}


@property (weak) id delegate;

@property (weak) IBOutlet PreviewView *previewView;

@property (strong) IBOutlet NSObjectController *layoutController;
- (IBAction)cancelEdit:(id)sender;
- (IBAction)editOK:(id)sender;
- (IBAction)newSource:(id)sender;
- (IBAction)openAnimatePopover:(NSButton *)sender;
- (IBAction)inputTableControlClick:(NSButton *)sender;

@property (weak) IBOutlet NSOutlineView *inputOutlineView;
@property (assign) bool previewOnly;

@end
