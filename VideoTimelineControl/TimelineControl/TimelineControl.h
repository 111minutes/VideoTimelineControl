//
//  TimelineControl.h
//  VideoTimelineControl
//
//  Created by Maxim Letushov on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "TimelineControlDelegate.h"


#define TimelinePlaceholderKey @"TimelinePlaceholderKey"
#define TimelineTrimViewKey @"TimelineTrimViewKey"
#define TimelineSliderKey @"TimelineSliderKey"

@interface TimelineControl : UIView

- (id)initWithFrame:(CGRect)frame fileURL:(NSURL *)fileUrl imagesDictionary:(NSDictionary*)imagesDictionary;
- (id)initWithFrame:(CGRect)frame imagesDictionary:(NSDictionary*)imagesDictionary;
- (void)reloadTimelineInCurrentInterfaceOrientation;        //must be call inside didRotateFromInterfaceOrientation 

- (CMTime)timelineSliderTime;     // slider time
- (CMTime)timelineStartTime;    // start time
- (CMTime)timelineEndTime;      // end time

- (CMTime)videoDuration;    //duration of video file with url fileUrl

- (void)setTimelineSliderTime:(CMTime)time;
- (void)setTimelineStartTime:(CMTime)time;
- (void)setTimelineEndTime:(CMTime)time;

- (void)expandTimelineAnimated:(BOOL)animated animationFinishBlock:(void(^)(void))finishBlock;

- (void)stopAllImagesGeneration;    //stops all images creation

// synchronously
- (UIImage *)imageForTime:(CMTime)time;
- (UIImage *)imageForTime:(CMTime)time size:(CGSize)size;
- (UIImage *)imageForTime:(CMTime)time width:(NSInteger)width;
- (UIImage *)imageForTime:(CMTime)time height:(NSInteger)height;

// asynchronously
- (void)imageForTime:(CMTime)time completionHandler:(void(^)(UIImage *image))completionHandler;
- (void)imageForTime:(CMTime)time size:(CGSize)size completionHandler:(void(^)(UIImage *image))completionHandler;
- (void)imageForTime:(CMTime)time width:(NSInteger)width completionHandler:(void(^)(UIImage *image))completionHandler;
- (void)imageForTime:(CMTime)time height:(NSInteger)height completionHandler:(void(^)(UIImage *image))completionHandler;

//properties
@property (nonatomic, assign) BOOL editing;         // default NO   allow movement of left and right parts
@property (nonatomic, assign) BOOL sliderHidden;    // default NO
@property (nonatomic, assign) id<TimelineControlDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval touchedDelayToGenerateNewFrame;   //default NSIntegerMax, recomended 0.3

@end
