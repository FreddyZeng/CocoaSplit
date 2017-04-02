//
//  SourceLayout.m
//  CocoaSplit
//
//  Created by Zakk on 8/31/14.
//  Copyright (c) 2014 Zakk. All rights reserved.
//

#import "SourceLayout.h"
#import "InputSource.h"
#import "CaptureController.h"


@implementation SourceLayout


@synthesize isActive = _isActive;
@synthesize frameRate = _frameRate;

-(instancetype) init
{
    if (self = [super init])
    {
        _sourceDepthSorter = [[NSSortDescriptor alloc] initWithKey:@"depth" ascending:YES];
        _sourceUUIDSorter = [[NSSortDescriptor alloc] initWithKey:@"uuid" ascending:YES];
        self.sourceCache = [[SourceCache alloc] init];
        _frameRate = 30;
        _canvas_height = 720;
        _canvas_width = 1280;
        _fboTexture = 0;
        _rFbo = 0;
        _uuidMap = [NSMutableDictionary dictionary];
        
        
        _animationQueue = dispatch_queue_create("CSAnimationQueue", NULL);
        _containedLayouts = [[NSMutableArray alloc] init];
        _noSceneTransactions = NO;
        _topLevelSourceArray = [[NSMutableArray alloc] init];
        self.rootLayer = [self newRootLayer];
        
        //self.rootLayer.geometryFlipped = YES;
        _rootSize = NSMakeSize(_canvas_width, _canvas_height);
        self.sourceList = [NSMutableArray array];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputAttachEvent:) name:CSNotificationInputAttached object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputAttachEvent:) name:CSNotificationInputDetached object:nil];

        
        
    }
    
    return self;
}


-(void)inputAttachEvent:(NSNotification *)notification
{
    InputSource *src = notification.object;
    if (src.sourceLayout == self)
    {
        [self generateTopLevelSourceList];
    }
}


-(CALayer *)newRootLayer
{
    CALayer *newRoot = [CALayer layer];
    [CATransaction begin];
    newRoot.bounds = CGRectMake(0, 0, _canvas_width, _canvas_height);
    newRoot.anchorPoint = CGPointMake(0.0, 0.0);
    newRoot.position = CGPointMake(0.0, 0.0);
    newRoot.masksToBounds = YES;
    newRoot.backgroundColor = CGColorCreateGenericRGB(0, 0, 0, 1);
    newRoot.layoutManager = [CAConstraintLayoutManager layoutManager];

    //newRoot.autoresizingMask = kCALayerMinXMargin | kCALayerWidthSizable | kCALayerMaxXMargin | kCALayerMinYMargin | kCALayerHeightSizable | kCALayerMaxYMargin;
    
    
    newRoot.delegate = self;
    [CATransaction commit];

    return newRoot;
    
}

-(NSString *)MIDIIdentifier
{
    return [NSString stringWithFormat:@"Layout:%@", self.name];
}


-(MIKMIDIResponderType)MIDIResponderTypeForCommandIdentifier:(NSString *)commandID
{
    return MIKMIDIResponderTypeButton;
}

-(BOOL)respondsToMIDICommand:(MIKMIDICommand *)command
{
    return YES;
}

-(void)handleMIDICommand:(MIKMIDICommand *)command forIdentifier:(NSString *)identifier
{
    
    
    __weak SourceLayout *weakSelf = self;
    
    
}


-(NSArray *)commandIdentifiers
{
    
    NSMutableArray *ret = [NSMutableArray array];
    
    
    return ret;
}








-(void)runAnimationString:(NSString *)animationCode withCompletionBlock:(void (^)(void))completionBlock withExceptionBlock:(void (^)(NSException *exception))exceptionBlock
{
    if (!animationCode)
    {
        return;
    }
    
    NSMutableDictionary *animMap = @{@"animationString": animationCode}.mutableCopy;
    if (completionBlock)
    {
        [animMap setObject:completionBlock forKey:@"completionBlock"];
    }
    
    if (exceptionBlock)
    {
        [animMap setObject:exceptionBlock forKey:@"exceptionBlock"];
        
    }
    
    //[self doAnimation:animMap];
    
    NSThread *runThread = [[NSThread alloc] initWithTarget:self selector:@selector(doAnimation:) object:animMap];
    [runThread start];

    
    
}




-(void)doAnimation:(NSDictionary *)threadDict
{
    
    CSAnimationRunnerObj *runner = [CaptureController sharedAnimationObj];

    NSString *modName = threadDict[@"moduleName"];
    NSDictionary *inpMap = threadDict[@"inputs"];
    CALayer *rootLayer = threadDict[@"rootLayer"];
    NSString *animationCode = threadDict[@"animationString"];
    
    void (^completionBlock)(void) = [threadDict objectForKey:@"completionBlock"];
    void (^exceptionBlock)(NSException *exception) = [threadDict objectForKey:@"exceptionBlock"];
    
    
    @try {

        if (completionBlock)
        {
            [CATransaction begin];
            [CATransaction setCompletionBlock:completionBlock];
        }
        
        if (animationCode)
        {
            [runner runAnimation:animationCode forLayout:self];
        } else {
            [runner runAnimation:modName forLayout:self  withSuperlayer:rootLayer];
        }
    }
    @catch (NSException *exception) {
        
        if (exceptionBlock)
        {
            exceptionBlock(exception);
        }
        
        NSLog(@"Animation module %@ failed with exception: %@: %@", modName, [exception name], [exception reason]);
    }
    @finally {
        if (completionBlock)
        {
            [CATransaction commit];
        }

        [CATransaction flush];
    }
}







-(id)copyWithZone:(NSZone *)zone
{
    SourceLayout *newLayout = [[SourceLayout allocWithZone:zone] init];
    
    newLayout.savedSourceListData = self.savedSourceListData;
    newLayout.name = self.name;
    newLayout.canvas_height = self.canvas_height;
    newLayout.canvas_width = self.canvas_width;
    newLayout.frameRate = self.frameRate;
    newLayout.isActive = NO;
    newLayout.containedLayouts = self.containedLayouts.mutableCopy;
    
    return newLayout;
}




-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    
    if (self.doSaveSourceList)
    {
        [self saveSourceList];
    }
    
    
    
    [aCoder encodeObject:self.savedSourceListData forKey:@"savedSourceData"];
    [aCoder encodeInt:self.canvas_width forKey:@"canvas_width"];
    [aCoder encodeInt:self.canvas_height forKey:@"canvas_height"];
    [aCoder encodeFloat:self.frameRate forKey:@"frameRate"];
    if (self.containedLayouts)
    {
        [aCoder encodeObject:self.containedLayouts forKey:@"containedLayouts"];
    }
    
}





-(id) initWithCoder:(NSCoder *)aDecoder
{
    if (self = [self init])
    {
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.savedSourceListData = [aDecoder decodeObjectForKey:@"savedSourceData"];
        if ([aDecoder containsValueForKey:@"canvas_height"])
        {
            self.canvas_height = [aDecoder decodeIntForKey:@"canvas_height"];
        }
        
        if ([aDecoder containsValueForKey:@"canvas_width"])
        {
            self.canvas_width = [aDecoder decodeIntForKey:@"canvas_width"];
        }
        
        if ([aDecoder containsValueForKey:@"frameRate"])
        {
            self.frameRate = [aDecoder decodeFloatForKey:@"frameRate"];
        }
        
    
        if ([aDecoder containsValueForKey:@"containedLayouts"])
        {
            self.containedLayouts = [[aDecoder decodeObjectForKey:@"containedLayouts"] mutableCopy];
            //set live/staging status for each layout
        }
        
    }
    
    return self;
}



-(float)frameRate
{
    return _frameRate;
}


-(void)setFrameRate:(float)frameRate
{
    float oldframerate = _frameRate;
    
    _frameRate = frameRate;
    
    if (_frameRate != oldframerate)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationLayoutFramerateChanged object:self userInfo:nil];
    }
}


-(void)applyAddBlock
{
    if (self.addLayoutBlock)
    {
        for (SourceLayout *layout in self.containedLayouts)
        {
            self.addLayoutBlock(layout);
        }
    }
}


-(void)generateTopLevelSourceList
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self willChangeValueForKey:@"topLevelSourceList"];

        [_topLevelSourceArray removeAllObjects];
        for (InputSource *src in self.sourceListOrdered)
        {
            if (!src.parentInput)
            {
                [_topLevelSourceArray addObject:src];
            }
        }
        [self didChangeValueForKey:@"topLevelSourceList"];

    });
    [_topLevelSourceArray removeAllObjects];
    for (InputSource *src in self.sourceListOrdered)
    {
        if (!src.parentInput)
        {
            [_topLevelSourceArray addObject:src];
        }
    }
}


-(NSArray *)topLevelSourceList
{
    
    return _topLevelSourceArray;
    
}


-(NSArray *)sourceListOrdered
{
    NSArray *mylist;
    
    @synchronized(self)
    {
        mylist = self.sourceList;
    }
    
    
    NSArray *listCopy = [mylist sortedArrayUsingDescriptors:@[_sourceDepthSorter, _sourceUUIDSorter]];
    return listCopy;
}


-(InputSource *)findSource:(NSPoint)forPoint withExtra:(float)withExtra deepParent:(bool)deepParent
{
    /* invert the point due to layer rendering inversion/weirdness */
    
    CGPoint newPoint = CGPointMake(forPoint.x, self.canvas_height-forPoint.y);
    CALayer *foundLayer = [self.rootLayer hitTest:newPoint];
    
    InputSource *retInput = nil;
    
    if (foundLayer && [foundLayer isKindOfClass:[CSInputLayer class]])
    {
        retInput = ((CSInputLayer *)foundLayer).sourceInput;
    }
    

    if (deepParent)
    {
        while (retInput && retInput.parentInput && NSEqualRects(retInput.globalLayoutPosition, ((InputSource *)retInput.parentInput).globalLayoutPosition))
        {
            retInput = retInput.parentInput;
        }
    }
    
    
    return retInput;

}


-(void) resetAllRefCounts
{
    for (InputSource *src in self.sourceList)
    {
        src.refCount = 1;
    }
    
}




-(NSInteger)incrementInputRef:(InputSource *)input
{
    
    input.refCount++;
    
    return input.refCount;
}

-(NSInteger)decrementInputRef:(InputSource *)input
{
    
    input.refCount--;
    
    if (input.refCount < 0)
    {
        input.refCount = 0;
    }
    
    return input.refCount;
}


-(InputSource *)findSource:(NSPoint)forPoint deepParent:(bool)deepParent
{
    
    return [self findSource:forPoint withExtra:0 deepParent:deepParent];
}


-(NSData *)makeSaveData
{
    NSObject *timerSrc = self.layoutTimingSource;
    if (!timerSrc)
    {
        timerSrc = [NSNull null];
    }
    
    NSDictionary *saveDict = @{@"sourcelist": self.sourceList,  @"timingSource": timerSrc};
    NSMutableData *saveData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:saveData];
    archiver.delegate = self;
    [archiver encodeObject:saveDict forKey:@"root"];
    [archiver finishEncoding];
    
    return saveData;
}


-(void) saveSourceList
{
    
    NSData *saveData = [self makeSaveData];
    self.savedSourceListData = saveData;
    [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationLayoutSaved object:self userInfo:nil];

}

-(id)archiver:(NSKeyedArchiver *)archiver willEncodeObject:(id)object
{
    if ([object isKindOfClass:[InputSource class]])
    {
        InputSource *src = (InputSource *)object;
        if (src.skipSave)
        {
            return nil;
        }
    }
    
    return object;
}


-(void)replaceWithSourceLayout:(SourceLayout *)layout
{
    [self replaceWithSourceLayout:layout withCompletionBlock:nil];
}


-(void)replaceWithSourceLayout:(SourceLayout *)layout withCompletionBlock:(void (^)(void))completionBlock
{
    
    
    //_noSceneTransactions = YES;
    CATransition *rTrans = nil;
    
    [CATransaction begin];
    if (completionBlock)
    {
        [CATransaction setCompletionBlock:completionBlock];
    }

    if (self.transitionFullScene)
    {
        if (self.transitionName || self.transitionFilter)
        {
            rTrans = [CATransition animation];
            rTrans.type = self.transitionName;
            rTrans.duration = self.transitionDuration;
            rTrans.removedOnCompletion = YES;
            rTrans.subtype = self.transitionDirection;
            if (self.transitionFilter)
            {
                rTrans.filter = self.transitionFilter;
            }
        }
        
    }
    
    
    for (SourceLayout *cLayout in self.containedLayouts.copy)
    {
        if (self.removeLayoutBlock)
        {
            self.removeLayoutBlock(cLayout);
        }
        
        [self.containedLayouts removeObject:cLayout];
    }
    //If an input exists in both lists, only remove it if the new one is different/changed
    
    NSMutableArray *rList = [[NSMutableArray alloc] init];
    for (InputSource *src in self.sourceList)
    {
        InputSource *nSrc = [layout inputForUUID:src.uuid];
        if (nSrc)
        {
            if ([nSrc isDifferentInput:src])
            {
                [rList addObject:src];
            }
        } else {
            [rList addObject:src];
            
        }
    }
    
    [self removeSourceInputs:rList withLayer:nil];
    
    
    if (self.addLayoutBlock)
    {
        self.addLayoutBlock(layout);
    }
    
    [self.containedLayouts addObject:layout];

    for (SourceLayout *cLayout in layout.containedLayouts.copy)
    {
        if (self.addLayoutBlock)
        {
            self.addLayoutBlock(cLayout);
        }
        
        [self.containedLayouts addObject:cLayout];
    }

    [self mergeSourceListData:layout.savedSourceListData onlyAdd:YES];
    
    
    if (self.transitionFullScene)
    {
        if (rTrans)
        {
            //[self.rootLayer addAnimation:rTrans forKey:kCATransition];
        }

    }
    
    [CATransaction commit];

    
    _noSceneTransactions = NO;
    [self updateCanvasWidth:layout.canvas_width height:layout.canvas_height];
    self.frameRate = layout.frameRate;
    [self resetAllRefCounts];
    
}



-(bool)containsLayout:(SourceLayout *)layout
{
    return [self.containedLayouts containsObject:layout];
}







-(void)mergeSourceLayout:(SourceLayout *)toMerge
{
    [self mergeSourceLayout:toMerge withCompletionBlock:nil];
}

-(void)mergeSourceLayout:(SourceLayout *)toMerge withCompletionBlock:(void (^)(void))completionBlock
{
    
    
    if ([self.containedLayouts containsObject:toMerge])
    {
        return;
    }
    

    
    [CATransaction begin];
    
    if (completionBlock)
    {
        [CATransaction setCompletionBlock:completionBlock];
    }
    
    NSObject *dictOrObj = [self mergeSourceListData:toMerge.savedSourceListData];
    
    if ([dictOrObj isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *dict = (NSDictionary *)dictOrObj;
    }
    
    [self adjustAllInputs];
    [self.containedLayouts addObject:toMerge];
    if (self.addLayoutBlock)
    {
        self.addLayoutBlock(toMerge);
    }

    [CATransaction commit];
    
}


-(void)removeSourceLayout:(SourceLayout *)toRemove{
    
    if (![self.containedLayouts containsObject:toRemove])
    {
        return;
    }
    
    [self removeSourceListData:toRemove.savedSourceListData];
    
    [self.containedLayouts removeObject:toRemove];
    if (self.removeLayoutBlock)
    {
        self.removeLayoutBlock(toRemove);
    }
}




-(NSArray *)mergeSourceInputsScene:(NSArray *)inputs onlyAdd:(bool)onlyAdd
{
    
    NSMutableArray *undoSources = [NSMutableArray array];
    
    
    CATransition *rTrans = nil;
    if (!_noSceneTransactions && (self.transitionName || self.transitionFilter))
    {
        rTrans = [CATransition animation];
        rTrans.type = self.transitionName;
        rTrans.duration = self.transitionDuration;
        rTrans.removedOnCompletion = YES;
        rTrans.subtype = self.transitionDirection;
        if (self.transitionFilter)
        {
            rTrans.filter = self.transitionFilter;
        }
    }
    
    if (!_noSceneTransactions)
    {
        [CATransaction begin];
    }
    
    for(InputSource *src in inputs)
    {
        src.sourceLayout = self;
        src.is_live = self.isActive;
        InputSource *eSrc = [self inputForUUID:src.uuid];
        bool isDifferent = YES;
        
        
        
        if (eSrc && eSrc.refCount)
        {

            isDifferent = [eSrc isDifferentInput:src];
            if (!isDifferent)
            {
                [self incrementInputRef:eSrc];

                continue;
            }
        }
        if (eSrc && eSrc.refCount && !onlyAdd)
        {
            if (!src.layer.superlayer)
            {
                [eSrc.layer.superlayer addSublayer:src.layer];
            }
            eSrc.layer.hidden = YES;
            [undoSources addObject:eSrc];
            eSrc.refCount = 0;
        } else {
            if (!src.layer.superlayer)
            {
                [self.rootLayer addSublayer:src.layer];
            }
        }
        [NSApp registerMIDIResponder:src];
        [self incrementInputRef:src];
        
        [[self mutableArrayValueForKey:@"sourceList" ] addObject:src];

        [self generateTopLevelSourceList];

         [_uuidMap setObject:src forKey:src.uuid];
        
    }
    
    __weak SourceLayout *weakSelf = self;
    
    if (undoSources.count > 0)
    {
        [CATransaction setCompletionBlock:^{
            for (InputSource *dInput in undoSources)
            {
                [weakSelf deleteSource:dInput];
            }
        }];
    }
    
    if (rTrans)
    {
        [self.rootLayer addAnimation:rTrans forKey:nil];
    }
    if (!_noSceneTransactions)
    {
        [CATransaction commit];
    }
    
    return undoSources;
}


-(NSArray *)mergeSourceInputsIndividual:(NSArray *)inputs onlyAdd:(bool)onlyAdd
{
    
    NSMutableArray *undoSources = [NSMutableArray array];
    CATransition *rTrans = nil;
    NSInteger origRefCnt = 0;
    
    if (self.transitionName || self.transitionFilter)
    {
        rTrans = [CATransition animation];
        rTrans.type = self.transitionName;
        rTrans.duration = self.transitionDuration;
        rTrans.removedOnCompletion = YES;
        rTrans.subtype = self.transitionDirection;
        if (self.transitionFilter)
        {
            rTrans.filter = self.transitionFilter;
        }
    }
    
    for(InputSource *src in inputs)
    {
        src.sourceLayout = self;
        src.is_live = self.isActive;
        InputSource *eSrc = [self inputForUUID:src.uuid];
        
        bool isDifferent = NO;
        
        if (eSrc)
        {
            isDifferent = [eSrc isDifferentInput:src];
        }
        
        if (eSrc && eSrc.refCount && !onlyAdd)
        {
            if (!isDifferent)
            {
                [self incrementInputRef:eSrc];
                continue;
            }
            
            src.layer.hidden = YES;
            if (!src.layer.superlayer)
            {
                [eSrc.layer.superlayer addSublayer:src.layer];
            }
            [CATransaction flush];
            
            [CATransaction begin];
            __weak SourceLayout *weakSelf = self;
            
            [CATransaction setCompletionBlock:^{
                [weakSelf deleteSource:eSrc];
            }];
            
            
            
            if (rTrans)
            {
                [eSrc.layer addAnimation:rTrans forKey:nil];
                [src.layer addAnimation:rTrans forKey:nil];
            }
            
            origRefCnt = eSrc.refCount;
            eSrc.refCount = 0;
            eSrc.layer.hidden = YES;
            src.layer.hidden = NO;
            [CATransaction commit];
            [undoSources addObject:eSrc];
        } else {

            if (eSrc && eSrc.refCount && !isDifferent)
            {
                [self incrementInputRef:eSrc];

                continue;
            }
            
            [CATransaction begin];

            if (!src.layer.superlayer)
            {
                [self.rootLayer addSublayer:src.layer];
            }


            src.layer.hidden = YES;
            
            [CATransaction commit];
            
            //worst hack ever. add a dummy animation of same length so the outer transaction doesn't complete until we do
            
            [CATransaction begin];
            CABasicAnimation *hackAnim = [CABasicAnimation animationWithKeyPath:@"dummyKeyPath"];
            hackAnim.duration = rTrans.duration;
            hackAnim.fromValue = @0;
            hackAnim.toValue = @100;
            hackAnim.removedOnCompletion = YES;
            
            [src.layer addAnimation:hackAnim forKey:@"dummyKey"];
            [CATransaction commit];
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
            [CATransaction begin];
            
            if (rTrans)
            {

                [src.layer addAnimation:rTrans forKey:nil];
            }


            src.layer.hidden = NO;



            
            [CATransaction commit];
            });
            

        }

        [NSApp registerMIDIResponder:src];
        
        
        src.refCount = origRefCnt+1;
        
        [[self mutableArrayValueForKey:@"sourceList" ] addObject:src];
        [_uuidMap setObject:src forKey:src.uuid];
        
    }
    
    [self generateTopLevelSourceList];
    return undoSources;
}


-(NSObject *)mergeSourceListData:(NSData *)mergeData
{
    
    return [self mergeSourceListData:mergeData onlyAdd:NO];
}


-(NSObject *)mergeSourceListData:(NSData *)mergeData onlyAdd:(bool)onlyAdd
{
    
    
    
    if (!self.sourceList)
    {
        self.sourceList = [NSMutableArray array];
    }
    
    if (!mergeData)
    {
        return nil;
    }
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:mergeData];
    
    [unarchiver setDelegate:self];
    
    NSObject *mergeObj = [unarchiver decodeObjectForKey:@"root"];
    [unarchiver finishDecoding];
    
    NSArray *mergeList;
    
    
    if ([mergeObj isKindOfClass:[NSDictionary class]])
    {
        mergeList = [((NSDictionary *)mergeObj) objectForKey:@"sourcelist"];
    } else {
        mergeList = (NSArray *)mergeObj;
    }
    
    if (self.undoManager)
    {
        [self.undoManager beginUndoGrouping];
    }
   
    
    
    
    NSArray *undoSources;
    
    if (self.transitionFullScene)
    {
        undoSources = [self mergeSourceInputsScene:mergeList onlyAdd:onlyAdd];
    } else {
        undoSources = [self mergeSourceInputsIndividual:mergeList onlyAdd:onlyAdd];
    }
    
    
    if (undoSources.count > 0)
    {
        NSData *undoData = [NSKeyedArchiver archivedDataWithRootObject:undoSources];
        [[self.undoManager prepareWithInvocationTarget:self] mergeSourceListData:undoData];
    } else {
        [[self.undoManager prepareWithInvocationTarget:self] removeSourceListData:mergeData];
    }

    if (self.undoManager)
    {
        [self.undoManager endUndoGrouping];
    }
    
    return mergeObj;
}


-(NSArray *)removeSourceInputsScene:(NSArray *)inputs
{
    NSMutableArray *undoSources = [NSMutableArray array];
    
    CATransition *rTrans = nil;
    
    if (!_noSceneTransactions && (self.transitionName || self.transitionFilter))
    {
        rTrans = [CATransition animation];
        rTrans.type = self.transitionName;
        rTrans.duration = self.transitionDuration;
        rTrans.subtype = self.transitionDirection;

        if (self.transitionFilter)
        {
            rTrans.filter = self.transitionFilter;
        }
        rTrans.removedOnCompletion = YES;
    }
    
    if (!_noSceneTransactions)
    {
        [CATransaction begin];
        
    }
    __weak SourceLayout *weakSelf = self;

    [CATransaction setCompletionBlock:^{
        for (InputSource *dInput in undoSources)
        {
            [weakSelf deleteSource:dInput];
        }
    }];
    if (rTrans)
    {
        [self.rootLayer addAnimation:rTrans forKey:nil];
    }

    for(InputSource *src in inputs)
    {
        src.sourceLayout = self;
        InputSource *eSrc = [self inputForUUID:src.uuid];
        


        if (eSrc)
        {
            NSInteger refCnt = [self decrementInputRef:eSrc];
            

            if (refCnt != 0)
            {
                continue;
            }

            eSrc.layer.hidden = YES;
            [undoSources addObject:eSrc];
        }
    }
    
    if (!_noSceneTransactions)
    {
        [CATransaction commit];
    }
    
    return undoSources;
}


-(NSArray *)removeSourceInputsIndividual:(NSArray *)inputs
{
    
    NSMutableArray *undoSources = [NSMutableArray array];
    
    CATransition *rTrans = nil;
    if (self.transitionName || self.transitionFilter)
    {
        rTrans = [CATransition animation];
        rTrans.type = self.transitionName;
        rTrans.duration = self.transitionDuration;
        rTrans.subtype = self.transitionDirection;
        if (self.transitionFilter)
        {
            rTrans.filter = self.transitionFilter;
        }
        rTrans.removedOnCompletion = YES;
    }
    
    for(InputSource *src in inputs)
    {
        src.sourceLayout = self;
        InputSource *eSrc = [self inputForUUID:src.uuid];
        if (eSrc)
        {
            NSInteger refCnt = [self decrementInputRef:eSrc];
            if (refCnt != 0)
            {
                continue;
            }
            
            [CATransaction begin];
            __weak SourceLayout *weakSelf = self;
            
            [CATransaction setCompletionBlock:^{
                [weakSelf deleteSource:eSrc];
            }];
            
            
            if (rTrans)
            {
                [eSrc.layer addAnimation:rTrans forKey:nil];
            }
            
            eSrc.layer.hidden = YES;
            [CATransaction commit];
            [undoSources addObject:eSrc];
        }
        
        
    }
    
    return undoSources;
}



-(void)removeSourceInputs:(NSArray *)inputs withLayer:(CALayer *)withLayer
{
    

    if (self.undoManager)
    {
        [self.undoManager beginUndoGrouping];
    }
    
    NSArray *undoSources;
    
    if (self.transitionFullScene)
    {
        undoSources = [self removeSourceInputsScene:inputs];
    } else {
        undoSources = [self removeSourceInputsIndividual:inputs];
    }
    
    
    if (undoSources.count > 0)
    {
        NSData *undoData = [NSKeyedArchiver archivedDataWithRootObject:undoSources];
        [[self.undoManager prepareWithInvocationTarget:self] mergeSourceListData:undoData];
    }

    if (self.undoManager)
    {
        [self.undoManager endUndoGrouping];
    }

    
}


-(NSObject *)removeSourceListData:(NSData *)mergeData
{
    
    CALayer *withLayer = nil;
    
    if (!self.sourceList)
    {
        return nil;
    }

    if (!mergeData)
    {
        return nil;
    }
    
    if (!withLayer)
    {
        withLayer = self.rootLayer;
    }
    
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:mergeData];
    
    [unarchiver setDelegate:self];
    
    NSObject *mergeObj = [unarchiver decodeObjectForKey:@"root"];
    [unarchiver finishDecoding];
    
    NSArray *mergeList;
    
    if ([mergeObj isKindOfClass:[NSDictionary class]])
    {
        mergeList = [((NSDictionary *)mergeObj) objectForKey:@"sourcelist"];

    } else {
        mergeList = (NSArray *)mergeObj;
    }
    

    [self removeSourceInputs:mergeList withLayer:withLayer];
    
    return mergeObj;
}


-(void)restoreSourceList:(NSData *)withData
{
    
    if (self.savedSourceListData)
    {
        
        [CATransaction begin];
        
        NSMutableArray *oldSourceList = self.sourceList;
        
        
        self.sourceList = [NSMutableArray array];
        _uuidMap = [NSMutableDictionary dictionary];
        
        
        if (!withData)
        {
            withData = self.savedSourceListData;
        }
        NSObject *restData = [self mergeSourceListData:withData];
        
        
        if (restData && [restData isKindOfClass:[NSDictionary class]])
        {
            NSObject *timerSrc = nil;
            timerSrc = [((NSDictionary *)restData) objectForKey:@"timingSource"];
            if (timerSrc == [NSNull null])
            {
                timerSrc = nil;
            }
            
            
            self.layoutTimingSource = ((InputSource *)timerSrc);
        }
        
        for(InputSource *src in oldSourceList)
        {
            [src willDelete];
            [src.layer removeFromSuperlayer];
        }

        
        
        [CATransaction commit];

    }
}


-(bool)containsInput:(InputSource *)cInput
{
    NSArray *listCopy = [self sourceListOrdered];
    
    for (InputSource *testSrc in listCopy)
    {
        if (testSrc == cInput)
        {
            return YES;
        }
    }

    return NO;
}



-(void)deleteSource:(InputSource *)delSource
{
    
    [delSource willDelete];
    
    [self willChangeValueForKey:@"topLevelSourceList"];
    @synchronized (self) {
        [[self mutableArrayValueForKey:@"sourceList" ] removeObject:delSource];
    }
    [self generateTopLevelSourceList];
    [self didChangeValueForKey:@"topLevelSourceList"];
    

    InputSource *uSrc;
    uSrc = _uuidMap[delSource.uuid];
    if ([uSrc isEqual:delSource])
    {
        [_uuidMap removeObjectForKey:delSource.uuid];
    }
    
    //[self.sourceList removeObject:delSource];
    if (delSource == self.layoutTimingSource)
    {
        self.layoutTimingSource = nil;
    }
    
    [delSource.layer removeFromSuperlayer];

    [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationInputDeleted  object:delSource userInfo:nil];
    delSource.sourceLayout = nil;

    
    

}



-(void)setupMIDI
{
    [NSApp registerMIDIResponder:self];
    for (InputSource *src in self.sourceList)
    {
        [NSApp registerMIDIResponder:src];

    }
}


-(void) adjustAllInputs
{
    
    NSArray *copiedInputs = [self sourceListOrdered];
    
    for (InputSource *src in copiedInputs)
    {
        src.needsAdjustPosition = YES;
        src.needsAdjustment = YES;
    }
}




-(void) addSource:(InputSource *)newSource
{
    newSource.sourceLayout = self;
    newSource.is_live = self.isActive;
    
    [[self mutableArrayValueForKey:@"sourceList" ] addObject:newSource];
    

    [self.rootLayer addSublayer:newSource.layer];


    newSource.needsAdjustPosition = NO;
    newSource.needsAdjustment = YES;
    
    [_uuidMap setObject:newSource forKey:newSource.uuid];
    
    
    [NSApp registerMIDIResponder:newSource];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationInputAdded object:newSource userInfo:nil];
}


-(void)clearSourceList
{
    self.rootLayer.sublayers = [NSArray array];
    @synchronized(self)
    {
        [self.sourceList removeAllObjects];
        [self generateTopLevelSourceList];

        
    }
    [_uuidMap removeAllObjects];
}


/*
-(void) setIsActive:(bool)isActive
{
    
    
    bool oldActive = _isActive;
    
    _isActive = isActive;
    
    
    
    if (oldActive == isActive)
    {
        //If the value didn't change don't do anything
        return;
    }
    
    
    if (isActive)
    {
            [self restoreSourceList:nil];
            for(InputSource *src in self.sourceList)
            {
                src.sourceLayout = self;
                
            }

        
    } else {
        [self saveSourceList];
        for(InputSource *src in self.sourceList)
        {
            src.editorController = nil;
            
            
        }
        
        self.rootLayer.sublayers = [NSArray array];
        @synchronized(self)
        {
            [self.sourceList removeAllObjects];

        }
        [self.animationList removeAllObjects];
        self.selectedAnimation = nil;
        
        //self.sourceList = [NSMutableArray array];
    }
}

-(bool) isActive
{
    return _isActive;
}

*/





-(InputSource *)sourceUnder:(InputSource *)source
{
    
    NSRect sourceFrame = source.layer.frame;
    
    InputSource *ret = nil;
    
    NSArray *listCopy = [self sourceListOrdered];

    for (InputSource *src in listCopy)
    {
        if (src == source)
        {
            continue;
        }
        
        NSRect candidateFrame = src.layer.frame;
        
        NSRect tryFrame;
        
        tryFrame = [self.rootLayer convertRect:candidateFrame fromLayer:src.layer.superlayer];

        if (NSIntersectsRect(sourceFrame, tryFrame))
        {
            if (source.layer.zPosition >= src.layer.zPosition)
            {
                if (!ret || src.layer.zPosition > ret.layer.zPosition || src.layer.superlayer == ret.layer)
                {
                    ret = src;
                }
            }
        }
        
    }
    
    return ret;
}


-(id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return (id<CAAction>)[NSNull null];
}


-(void)updateCanvasWidth:(int)width height:(int)height 
{
    int old_height = self.canvas_height;
    int old_width = self.canvas_width;
    
    self.canvas_height = height;
    self.canvas_width = width;
    
    if ((old_height != height) || (old_width != width))
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationLayoutCanvasChanged object:self userInfo:nil];
    }
}


-(void)frameTick
{
    @autoreleasepool {
        
        bool needsResize = NO;
        NSSize curSize = NSMakeSize(self.canvas_width, self.canvas_height);
        
        if (!NSEqualSizes(curSize, _rootSize))
        {
            
            self.rootLayer.bounds = CGRectMake(0, 0, self.canvas_width, self.canvas_height);
            _rootSize = curSize;
            needsResize = YES;
        }
        
        
        NSArray *listCopy;
        
        listCopy = [self sourceListOrdered];
        
        
        
        for (InputSource *isource in listCopy)
        {
            if (needsResize)
            {
                isource.needsAdjustPosition = YES;
                isource.needsAdjustment = YES;
            }
            
            if (isource.active)
            {
                [isource frameTick];
            }
            
        }
    }
    
}


-(void)didBecomeVisible
{
    if (self.in_staging)
    {
        return;
    }
    
}



-(void)modifyUUID:(NSString *)uuid withBlock:(void (^)(InputSource *input))withBlock
{
    InputSource *useSource = [self inputForUUID:uuid];
    if (useSource)
    {
        withBlock(useSource);
    }
}




-(InputSource *)inputForName:(NSString *)name
{
    for (InputSource *tSrc in self.sourceList)
    {
        if (tSrc.name && [tSrc.name isEqualToString:name])
        {
            return tSrc;
        }
    }
    return nil;
}


-(InputSource *)inputForUUID:(NSString *)uuid
{
    return [_uuidMap objectForKey:uuid];
}


-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

@end
