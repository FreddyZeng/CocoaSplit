//
//  MIKMIDIMetaInstrumentNameEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaInstrumentNameEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaInstrumentNameEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMappingManager.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaInstrumentNameEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (BOOL)supportsMIKMIDIEventType:(MIKMIDIEventType)type { return type == MIKMIDIEventTypeMetaInstrumentName; }
+ (Class)immutableCounterpartClass { return [MIKMIDIMetaInstrumentNameEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIMetaInstrumentNameEvent class]; }
+ (BOOL)isMutable { return NO; }

@end

@implementation MIKMutableMIDIMetaInstrumentNameEvent

+ (BOOL)isMutable { return YES; }

@end