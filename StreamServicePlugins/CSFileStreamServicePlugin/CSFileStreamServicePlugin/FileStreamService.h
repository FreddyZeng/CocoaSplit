//
//  FileStreamService.h
//  CSFileStreamServicePlugin
//
//  Created by Zakk on 8/29/14.
//  Copyright (c) 2014 Zakk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSStreamServiceProtocol.h"

@interface FileStreamService : NSObject <CSStreamServiceProtocol>


@property bool isReady;
@property (strong) NSString *fileName;

@property (assign) BOOL useTimestamp;
@property (assign) BOOL noClobber;



-(NSViewController  *)getConfigurationView;
-(NSString *)getServiceDestination;
+(NSString *)label;
+(NSString *)serviceDescription;
+(NSImage *)serviceImage;



@end
