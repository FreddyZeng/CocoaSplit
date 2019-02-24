//
//  AVFCapture.m
//  H264Streamer
//
//  Created by Zakk on 9/3/12.
//  Copyright (c) 2012 Zakk. All rights reserved.
//

#import "AVFCapture.h"
#import "CSAbstractCaptureDevice.h"
#import "AVCaptureDeviceFormat+CocoaSplitAdditions.h"
#import "AVFrameRateRange+CocoaSplitAdditions.m"
#import <CoreMediaIO/CMIOHardware.h>

@implementation AVFCapture         


@synthesize activeVideoFormat = _activeVideoFormat;
@synthesize activeVideoDevice = _activeVideoDevice;
@synthesize activeVideoFramerate = _activeVideoFramerate;
@synthesize renderType = _renderType;




-(void)saveWithCoder:(NSCoder *)aCoder
{
    [super saveWithCoder:aCoder];
    
    if (self.activeVideoDevice)
    {
        [aCoder encodeObject:self.activeVideoFormat.saveDictionary forKey:@"activeVideoFormat"];
    }
    
    if (self.activeVideoFramerate)
    {
        [aCoder encodeObject:self.activeVideoFramerate.localizedName forKey:@"activeVideoFramerate"];
    }
    
    [aCoder encodeInt:self.renderType forKey:@"renderType"];
    
}


-(void)restoreWithCoder:(NSCoder *)aDecoder
{
    [super restoreWithCoder:aDecoder];
    
        _savedFormatData = [aDecoder decodeObjectForKey:@"activeVideoFormat"];
        _savedFrameRateData = [aDecoder decodeObjectForKey:@"activeVideoFramerate"];
        [self restoreFormatAndFrameRate];
        self.renderType = (frame_render_behavior)[aDecoder decodeIntForKey:@"renderType"];
}


+(NSString *)label
{
    return @"Webcam Capture";
}


-(void) restoreFormatAndFrameRate
{
    if (_selectedVideoCaptureDevice)
    {
        for (AVCaptureDeviceFormat *fmt in _selectedVideoCaptureDevice.formats)
        {
            if ([fmt compareToDictionary:_savedFormatData])
            {
                self.activeVideoFormat = fmt;
                break;
            }
            
        }
        
        if (self.activeVideoFormat)
        {
            for (AVFrameRateRange *frr in self.activeVideoFormat.videoSupportedFrameRateRanges)
            {
                if ([frr.localizedName isEqualToString:_savedFrameRateData])
                {
                    self.activeVideoFramerate = frr;
                    break;
                }
            }
        }
    }

    
}

-(id) init
{
    if (self = [super init])
    {
        _lastFrameTime = 0;
        _lastSize = CGSizeZero;
        
        
         CMIOObjectPropertyAddress prop = { kCMIOHardwarePropertyAllowScreenCaptureDevices, kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMaster };
         UInt32 allow = 1;
         CMIOObjectSetPropertyData( kCMIOObjectSystemObject, &prop, 0, NULL, sizeof(allow), &allow );

        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDeviceChange:) name:AVCaptureDeviceWasConnectedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDeviceChange:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];

        [self changeAvailableVideoDevices];
        self.canProvideTiming = YES;
    }
    return self;
}


-(void) handleDeviceChange:(NSNotification *)notification
{
    
    [self changeAvailableVideoDevices];
    
    
}



-(void)dealloc
{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_capture_session)
    {
        [_capture_session removeOutput:self];
    }
}




-(AVFrameRateRange *)activeVideoFramerate
{
    return _activeVideoFramerate;
    
}



-(void) setActiveVideoFramerate:(AVFrameRateRange *)activeVideoFramerate
{
    _activeVideoFramerate = activeVideoFramerate;
  
    //TODO: ERROR HANDLING
/*    [self.activeVideoDevice lockForConfiguration:nil];
    self.activeVideoDevice.activeVideoMinFrameDuration = _activeVideoFramerate.minFrameDuration;
    [self.activeVideoDevice unlockForConfiguration];
  */
    
    
    if([[[_selectedVideoCaptureDevice activeFormat] videoSupportedFrameRateRanges] containsObject:_activeVideoFramerate])
    {
        if([_selectedVideoCaptureDevice lockForConfiguration:nil])
        {
            [_selectedVideoCaptureDevice setActiveVideoMinFrameDuration:_activeVideoFramerate.minFrameDuration];
            [_selectedVideoCaptureDevice unlockForConfiguration];
        }
    }
    
    self.videoCaptureFPS = _activeVideoFramerate.minFrameRate;
    
}


-(AVCaptureDeviceFormat *) activeVideoFormat
{
    return _activeVideoFormat;
}


-(void) setActiveVideoFormat:(id)activeVideoFormat
{
    _activeVideoFormat = activeVideoFormat;
    //TODO: Error handling here
/*    [self.activeVideoDevice lockForConfiguration:nil];
    self.activeVideoDevice.activeFormat = _activeVideoFormat;
    [self.activeVideoDevice unlockForConfiguration];
*/
    
    
    if ([_selectedVideoCaptureDevice lockForConfiguration:nil])
    {
        
        [_selectedVideoCaptureDevice setActiveFormat:_activeVideoFormat];
        [_selectedVideoCaptureDevice unlockForConfiguration];
    }
    
    self.videoFramerates = self.activeVideoFormat.videoSupportedFrameRateRanges;
}




-(id) activeVideoDevice
{
    return _activeVideoDevice;
}


-(void) setActiveVideoDevice:(CSAbstractCaptureDevice *)newDev
{
    
    _activeVideoDevice = newDev;
    _selectedVideoCaptureDevice = [newDev captureDevice];
    
    if (_capture_session)
    {
        [_capture_session removeOutput:self];
    }
    
    if (!_selectedVideoCaptureDevice)
    {
        return;
    }
    
    
    _capture_session = [[AVFSession alloc] initWithDevice:_selectedVideoCaptureDevice];
    
    if (!_capture_session)
    {
        return;
    }
    
    [_capture_session registerOutput:self];
    
    
    self.captureName = newDev.captureName;
    
    self.videoFormats = _selectedVideoCaptureDevice.formats;
    
    self.videoFramerates = _selectedVideoCaptureDevice.activeFormat.videoSupportedFrameRateRanges;

    [self restoreFormatAndFrameRate];
    if (!_activeVideoFormat)
    {
        [self switchToDefaultFormat];
    }
}


-(void)switchToDefaultFormat
{
    NSSize captureSize = CSPluginServices.sharedPluginServices.streamSizeHint;
    NSInteger pixelCnt = captureSize.width * captureSize.height;
    
    NSArray *sortedFormats = [self.videoFormats sortedArrayUsingSelector:@selector(compare:)];
    
    
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFramerate = nil;
    
    for (AVCaptureDeviceFormat *cFmt in sortedFormats)
    {
        if (!bestFormat)
        {
            bestFormat = cFmt;
            bestFramerate = cFmt.maxFramerate;
            continue;
        }
        
        if (pixelCnt == cFmt.pixelCount)
        {
                bestFormat = cFmt;
                bestFramerate = cFmt.maxFramerate;
        } else if ((cFmt.pixelCount < pixelCnt) && (cFmt.pixelCount >= bestFormat.pixelCount)) {
            bestFormat = cFmt;
        }
    }
    
    
    self.activeVideoFormat = bestFormat;
    self.activeVideoFramerate = bestFormat.maxFramerate;
}

-(void)setIsLive:(bool)isLive
{
    super.isLive = isLive;
    
    if (!isLive)
    {
        if (_pcmPlayer)
        {
            [[CSPluginServices sharedPluginServices] removePCMInput:_pcmPlayer];
            _pcmPlayer = nil;
        }
    }
}


-(void) changeAvailableVideoDevices
{
    
    NSArray *devices = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] arrayByAddingObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeMuxed]];
    
    NSMutableArray *retArray = [[NSMutableArray alloc] init];
    
    
    AVCaptureDevice *devinstance;

    for(devinstance in devices)
    {
        [retArray addObject:[[CSAbstractCaptureDevice alloc] initWithName:[devinstance localizedName] device:devinstance uniqueID:devinstance.uniqueID]];
    }
    
    self.availableVideoDevices = retArray;
    /*
    The blackmagic driver is weird and there's a delay before the device shows up in the available list. So the initial restore of the config
    can't find the unique ID because it doesn't exist yet. So instead we always save the restored UniqueID to a property and then try to restore
    it when we get a notification of a device change. Only restore if we don't already have a source set, though.
     */
    
    if (!self.activeVideoDevice && self.savedUniqueID)
    {
        [self setDeviceForUniqueID:self.savedUniqueID];
        [self restoreFormatAndFrameRate];
    }
    
}





-(void) removeAudioOutput
{
    
    if (_pcmPlayer)
    {
        [[CSPluginServices sharedPluginServices] removePCMInput:_pcmPlayer];
    }
}





-(frame_render_behavior)renderType
{
    return _renderType;
}


-(CALayer *)createNewLayer
{
    
    return [CALayer layer];
 }


-(void)frameTick
{
    
    if (self.renderType == kCSRenderOnFrameTick)
    {
        
        [self updateLayersWithBlock:^(CALayer *layer) {
            [layer setNeedsDisplay];
        }];
    }
    
    

}


-(NSSize)captureSize
{
    return _lastSize;
}


-(void)captureVideoOutput:(CMSampleBufferRef)sampleBuffer
{
        CVImageBufferRef videoFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    

        if (videoFrame)
        {
            
            _lastSize = CVImageBufferGetDisplaySize(videoFrame);
            
            //CFRetain(sampleBuffer);
            [self updateLayersWithFramedataBlock:^(CALayer *layer) {
                if (@available(macOS 10.12, *))
                {
                    layer.contents = (__bridge id _Nullable)videoFrame;
                } else {
                    layer.contents = (__bridge id _Nullable)(CVPixelBufferGetIOSurface(videoFrame));
                }
            } withPreuseBlock:^{
                CFRetain(sampleBuffer);
            } withPostuseBlock:^{
                CFRelease(sampleBuffer);
            }];
            
            [self frameArrived];
        }
}

-(void)captureAudioOutput:(CMSampleBufferRef)sampleBuffer
{
    
        if (self.isLive && !_pcmPlayer)
        {
            CMFormatDescriptionRef sDescr = CMSampleBufferGetFormatDescription(sampleBuffer);
            const AudioStreamBasicDescription *asbd =  CMAudioFormatDescriptionGetStreamBasicDescription(sDescr);
            _pcmPlayer = [[CSPluginServices sharedPluginServices] createPCMInput:self.activeVideoDevice.uniqueID withFormat:asbd];
            _pcmPlayer.name = _selectedVideoCaptureDevice.localizedName;
        }
        
        if (_pcmPlayer)
        {
            [_pcmPlayer scheduleBuffer:sampleBuffer];
        }
}


@end
