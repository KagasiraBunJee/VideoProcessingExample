//
//  ObjCHelper.m
//  VideoReadEditWrite
//
//  Created by Sergei on 4/25/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

#import "ObjCHelper.h"

@implementation ObjCHelper

+ (void)help_release:(CMSampleBufferRef)sbuf
{
    CFRelease(sbuf);
}

@end
