//
//  TimelineControlDelegate.h
//  VideoTimelineControl
//
//  Created by Maxim Letushov on 4/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class TimelineControl;

@protocol TimelineControlDelegate <NSObject>

@optional

//moved
- (void) timelineControl:(TimelineControl *)control sliderMoved:(CMTime)time;
- (void) timelineControl:(TimelineControl *)control sliderTapped:(CMTime)time;

// moving through thumbnails
- (void) timelineControl:(TimelineControl *)control sliderThumbnailChanged:(CMTime)time;
- (void) timelineControl:(TimelineControl *)control startThumbnailChanged:(CMTime)time;
- (void) timelineControl:(TimelineControl *)control endThumbnailChanged:(CMTime)time;

// end of moving
- (void) timelineControl:(TimelineControl *)control sliderMovingEnded:(CMTime)time;
- (void) timelineControl:(TimelineControl *)control startMovingEnded:(CMTime)time;
- (void) timelineControl:(TimelineControl *)control endMovingEnded:(CMTime)time;

// hovering
- (void) timelineControl:(TimelineControl *)control sliderHovered:(CMTime)time;
- (void) timelineControl:(TimelineControl *)control startHovered:(CMTime)time;
- (void) timelineControl:(TimelineControl *)control endHovered:(CMTime)time;

@end
