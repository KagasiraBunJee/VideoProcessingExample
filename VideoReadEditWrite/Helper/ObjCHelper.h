//
//  ObjCHelper.h
//  VideoReadEditWrite
//
//  Created by Sergei on 4/25/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCHelper : NSObject

+(void) help_release: (CMSampleBufferRef) sbuf;

@end

NS_ASSUME_NONNULL_END
