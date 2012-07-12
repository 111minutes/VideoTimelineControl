//
//  TimelineControl.m
//  VideoTimelineControl
//
//  Created by Maxim Letushov on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TimelineControl.h"

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

static const int timelineHeight = 37;
static const int timelineLeft = 20;

static const int trimViewHeight = 58;
static const int trimViewLeft = 0;

static const int sliderWidth = 11;
static const int sliderHeight = 47;

static const int minDistanceBetweenActiveTrimParts = 21;

static const int numberThumbnailsPortrait = 10;
static const int numberThumbnailsLandscape = 20;


typedef enum {
    MovingElementNone,
    MovingElementSlider,
    MovingElementLeftBorder,
    MovingElementRightBorder
} MovingElement;



@interface TimelineControl ()
- (CGImageRef)cgImageForTime:(CMTime)time;
- (void)generateThumbnails:(NSInteger) count start:(NSInteger) start;
- (CGImageRef)resizeCGImage:(CGImageRef)image toWidth:(int)width andHeight:(int)height;
- (void)showAlreadyLoadedImages;
- (void)setExtractedImage:(UIImage *) image forImageViewWithNumber:(NSInteger) number;
- (void)processNextExtractedImage:(UIImage *)image;
- (NSInteger)thumbnailImageViewWidthInCurrentOrientation;
- (void)determineCurrentMovingElementWithTouch:(UITouch *)touch;
- (void)processMoveOfLeftTrimPartWithTouch:(UITouch *)touch;
- (void)processMoveOfRightTrimPartWithTouch:(UITouch *)touch;
- (void)processMoveOfSliderWithTouch:(UITouch *)touch;
- (void)setLeftOverlappedViewCorrectPosition;
- (void)setRightOverlappedViewCorrectPosition;
- (void)setSliderCorrectPosition;
- (CMTime) getTimelineTimeFromPosition:(NSInteger) x;
- (NSInteger)getTimelinePositionForTime:(CMTime)time;
- (void) checkCurrentThumbnailNumberChanged;
- (void) checkStartPositionThumbnailChanged;
- (void) checkEndPositionThumbnailChanged;
- (void) recalculateMovingElementsPosition;
@end


@implementation TimelineControl {
    
    NSURL *_fileURL;
    AVURLAsset *_asset;
    AVAssetImageGenerator *_generator;
    AVAssetImageGenerator *_secondGenerator;
    
    UIImageView *_backgroundImageView;
    UIImageView *_timelineBackgroundImageView;
    UIView *_trimTimelineView;
    UIImageView *_leftOverlappedImageView;
    UIImageView *_rightOverlappedImageView;
    UIImageView *_slider;
    
    NSMutableArray *_timelineThumbnailsPortrait;
    NSMutableArray *_timelineThumbnailsLandscape;
    BOOL _isLastOrientationPortrait;
    
    MovingElement _currentMovingElement;
    CGPoint _prevLocationInCurentMovingElement;
    int _prevThumbnailNumber;
    int _prevStartThumbnailNumber;
    int _prevEndThumbnailNumber;
    
    NSTimer *_timer;
}


@synthesize editing = _editing;
@synthesize sliderHidden = _sliderHidden;
@synthesize delegate;
@synthesize touchedDelayToGenerateNewFrame = _touchedDelayToGenerateNewFrame;

#pragma makr Properties

- (void)expandTimelineAnimated:(BOOL)animated animationFinishBlock:(void(^)(void))finishBlock {
    int width = CGRectGetWidth(self.frame);
    CGRect rect = CGRectMake(trimViewLeft, (CGRectGetHeight(self.frame)-trimViewHeight)/2, width-2*trimViewLeft, trimViewHeight);
    if (animated) {
        [UIView animateWithDuration:0.4 animations:^{
            [_trimTimelineView setFrame:rect];    
        } completion:^(BOOL finished) {
            if (finishBlock) {
                [self recalculateMovingElementsPosition];
                [self setLeftOverlappedViewCorrectPosition];
                [self setRightOverlappedViewCorrectPosition];
                finishBlock();
            }
        }];
    }
    else {
        [_trimTimelineView setFrame:rect];
        [self recalculateMovingElementsPosition];
        [self setLeftOverlappedViewCorrectPosition];
        [self setRightOverlappedViewCorrectPosition];
    }
}

- (void)setEditing:(BOOL)editing {
    if (!editing && _editing) {
        
        UIView *blockView = [[UIView new] initWithFrame:self.bounds];
        [blockView setBackgroundColor:[UIColor clearColor]];
        [blockView setUserInteractionEnabled:NO];
        [self addSubview:blockView];

        [UIView animateWithDuration:0.4 animations:^{
            int width = CGRectGetWidth(self.frame);
            [_trimTimelineView setFrame:CGRectMake(trimViewLeft, (CGRectGetHeight(self.frame)-trimViewHeight)/2, width-2*trimViewLeft, trimViewHeight)];
        } completion:^(BOOL finished) {
            [blockView removeFromSuperview];
        }];
    }
    _editing = editing;
}

- (void)setSliderHidden:(BOOL)sliderHidden {
    _sliderHidden = sliderHidden;
    [_slider setHidden:_sliderHidden];
}


#pragma mark Init

- (id)initWithFrame:(CGRect)frame fileURL:(NSURL *)fileUrl imagesDictionary:(NSDictionary*)imagesDictionary{
    self = [self initWithFrame:frame imagesDictionary:imagesDictionary];
    if (self) {
        
        _fileURL = fileUrl; 
        _asset = [[AVURLAsset alloc] initWithURL:_fileURL options:nil];
        _generator = [[AVAssetImageGenerator alloc] initWithAsset:_asset];
        [_generator setAppliesPreferredTrackTransform:YES];

        _secondGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_asset];
        [_secondGenerator setAppliesPreferredTrackTransform:YES];
        
        self.editing = NO;
        self.sliderHidden = NO;

        _prevThumbnailNumber = 0;
        _prevStartThumbnailNumber = 0;
        _prevEndThumbnailNumber = 0;
        _touchedDelayToGenerateNewFrame = NSIntegerMax;
        
        _timelineThumbnailsPortrait = [NSMutableArray new];
        _timelineThumbnailsLandscape = [NSMutableArray new];
        
        [self reloadTimelineInCurrentInterfaceOrientation];
        NSInteger framesCount = _isLastOrientationPortrait ? numberThumbnailsPortrait : numberThumbnailsLandscape;
        _prevEndThumbnailNumber = framesCount - 1;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame imagesDictionary:(NSDictionary*)imagesDictionary{
    self = [super initWithFrame:frame];
    if (self) {      
        UIImage *timelinePlaceholderImage = nil;
        UIImage *trimViewImage = nil;
        UIImage *timelineSliderImage = nil;
        
        
        if(imagesDictionary){
            timelinePlaceholderImage = (UIImage*)[imagesDictionary objectForKey:TimelinePlaceholderKey];
            trimViewImage = (UIImage*)[imagesDictionary objectForKey:TimelineTrimViewKey];
            timelineSliderImage = (UIImage*)[imagesDictionary objectForKey:TimelineSliderKey];
        }
        else{
            timelinePlaceholderImage = [UIImage imageNamed:@"timelinePlaceholder.png"];
            trimViewImage = [UIImage imageNamed:@"trimView.png"];
            timelineSliderImage = [UIImage imageNamed:@"TimelineSlider.png"];
        }
        
        
        self.multipleTouchEnabled = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        NSInteger width = CGRectGetWidth(self.frame);
        NSInteger height = CGRectGetHeight(self.frame);
        
        // backgroun view
        _backgroundImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        [_backgroundImageView setImage:[UIImage imageNamed:@"edit-timeline-background"]];
        [_backgroundImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self addSubview:_backgroundImageView];
        
        
        
        
        // timeline view
        UIImage *timeLineBGImage = timelinePlaceholderImage;
//        timeLineBGImage = [timeLineBGImage stretchableImageWithLeftCapWidth:timeLineBGImage.size.width/2
//                                                               topCapHeight:timeLineBGImage.size.height/2];
        
        timeLineBGImage = [timeLineBGImage resizableImageWithCapInsets:UIEdgeInsetsMake(timeLineBGImage.size.height/2, timeLineBGImage.size.width/2, timeLineBGImage.size.height/2-1, timeLineBGImage.size.width/2-1)];
        
        _timelineBackgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width - 2 * timelineLeft, timelineHeight)];
        [_timelineBackgroundImageView setCenter:CGPointMake(width/2, height/2)];
        [_timelineBackgroundImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [_timelineBackgroundImageView setImage:timeLineBGImage];
        [self addSubview:_timelineBackgroundImageView];

        // trim view
//        trimViewImage = [trimViewImage stretchableImageWithLeftCapWidth:trimViewImage.size.width/2
//                                                           topCapHeight:trimViewImage.size.height/2];
        
        trimViewImage = [trimViewImage resizableImageWithCapInsets:UIEdgeInsetsMake(trimViewImage.size.height/2, trimViewImage.size.width/2, trimViewImage.size.height/2-1, trimViewImage.size.width/2-1)];
        
        _trimTimelineView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width - 2 * trimViewLeft, trimViewHeight)];
        [_trimTimelineView setBackgroundColor:[UIColor clearColor]];
        [_trimTimelineView setCenter:CGPointMake(width/2, height/2)];
        [_trimTimelineView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth];
        UIImageView *trimImageView = [[UIImageView alloc] initWithFrame:_trimTimelineView.bounds];
        [trimImageView setImage:trimViewImage];
        [trimImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [_trimTimelineView addSubview:trimImageView];
        [self addSubview:_trimTimelineView];
        
        // slider
        _slider = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, sliderWidth, sliderHeight)];
        [_slider setImage:timelineSliderImage];
        [_slider setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
        [_slider setCenter:CGPointMake(0, height/2)];
        [self setSliderCorrectPosition];
        
        [self addSubview:_slider];
        
        //overlapped
        float alpha = 0.5;
        
        _leftOverlappedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, trimViewHeight)];
        [_leftOverlappedImageView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:alpha]];
        [_timelineBackgroundImageView addSubview:_leftOverlappedImageView];
        
        _rightOverlappedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(width-timelineLeft, 0, 0, trimViewHeight)];
        [_rightOverlappedImageView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:alpha]];
        [_timelineBackgroundImageView addSubview:_rightOverlappedImageView];
    }
    return self;
}

- (void)stopAllImagesGeneration {
    [_generator cancelAllCGImageGeneration];
    [_secondGenerator cancelAllCGImageGeneration];
}

- (void)dealloc {
    [self stopAllImagesGeneration];
    _generator = nil;
    _secondGenerator = nil;
    
    _backgroundImageView = nil;
    _timelineBackgroundImageView = nil;
    _trimTimelineView = nil;
    _leftOverlappedImageView = nil;
    _rightOverlappedImageView = nil;
    _slider = nil;
    
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
}

#pragma mark Generate Thumbnails

- (void) reloadTimelineInCurrentInterfaceOrientation {
    
    NSArray *subviews = _timelineBackgroundImageView.subviews;
    for (UIImageView *imageView in subviews) {
        [imageView removeFromSuperview];
    }
    
    _isLastOrientationPortrait = UIDeviceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]);
    NSInteger framesCount = _isLastOrientationPortrait ? numberThumbnailsPortrait : numberThumbnailsLandscape;
    NSInteger width = _timelineBackgroundImageView.frame.size.width / framesCount;
    
    for (int i = 0; i < framesCount; i++) {
        UIImageView *thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(i*width, 0, width, timelineHeight)];
        [thumbnailImageView setBackgroundColor:[UIColor clearColor]];
        [thumbnailImageView setTag:i + 100];
        [_timelineBackgroundImageView addSubview:thumbnailImageView];
    }
    [_timelineBackgroundImageView insertSubview:_leftOverlappedImageView atIndex:100];
    [_timelineBackgroundImageView insertSubview:_rightOverlappedImageView atIndex:100];
    
    [self showAlreadyLoadedImages];
    NSInteger start = _isLastOrientationPortrait ? _timelineThumbnailsPortrait.count : _timelineThumbnailsLandscape.count;
    [self generateThumbnails:framesCount start:start];
    
    [self setSliderCorrectPosition];
    [self setLeftOverlappedViewCorrectPosition];
    [self setRightOverlappedViewCorrectPosition];
    [self recalculateMovingElementsPosition];
}

- (void)generateThumbnails:(NSInteger) count start:(NSInteger) start {
        
    CMTime assetDuration = _asset.duration;
    float delta = assetDuration.value;
    delta /= (assetDuration.timescale * count);

        NSMutableArray *times = [NSMutableArray new];
        for (int i = start; i < count; i++) {
            CMTime start = CMTimeMake(assetDuration.timescale*i*delta, assetDuration.timescale);
            [times addObject:[NSValue valueWithCMTime:start]];
        }
        [_generator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
            
            @autoreleasepool {
                NSInteger imageWidth = CGImageGetWidth(image);
                NSInteger imageHeight = CGImageGetHeight(image);
                NSInteger newWidth = [self thumbnailImageViewWidthInCurrentOrientation] * 2;
            
                NSInteger newHeight = newWidth*imageHeight/imageWidth;
                CGImageRef newImage = [self resizeCGImage:image toWidth:newWidth andHeight:newHeight];
                UIImage *thumbnail = [[UIImage alloc] initWithCGImage:newImage]; //scale:1.0 orientation:UIImageOrientationRight];
                [self performSelectorOnMainThread:@selector(processNextExtractedImage:) withObject:thumbnail waitUntilDone:YES];
            //        [self processNextExtractedImage:thumbnail];
                CGImageRelease(newImage);
            }
        }];
}

- (CGImageRef)resizeCGImage:(CGImageRef)image toWidth:(int)width andHeight:(int)height {
    // create context, keeping original image properties
    CGContextRef context = CGBitmapContextCreate(NULL, width, height,
                                                 CGImageGetBitsPerComponent(image),
                                                 0,
                                                 CGImageGetColorSpace(image),
                                                 CGImageGetAlphaInfo(image));
    
    if(context == NULL)
        return nil;
    
    // draw image to context (resizing it)
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    // extract resulting image from context
    CGImageRef imgRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    return imgRef;
}

- (void)showAlreadyLoadedImages {
    NSArray *images = nil;
    if (_isLastOrientationPortrait) {
        images = _timelineThumbnailsPortrait;
    }
    else {
        images = _timelineThumbnailsLandscape;
    }
    int count = images.count;
    for (int i = 0; i < count; i++) {
        [self setExtractedImage:[images objectAtIndex:i] forImageViewWithNumber:i];
    }
}     

- (void)setExtractedImage:(UIImage *) image forImageViewWithNumber:(NSInteger) number {
    if (_isLastOrientationPortrait) {
        UIImageView *imageView = (UIImageView *)[_timelineBackgroundImageView viewWithTag:number + 100];
        [imageView setImage:image];
    }
    else {
        UIImageView *imageView = (UIImageView *)[_timelineBackgroundImageView viewWithTag:number + 100];
        [imageView setImage:image];
    }
}

- (void)processNextExtractedImage:(UIImage *)image {
    if (_isLastOrientationPortrait) {
        [self setExtractedImage:image forImageViewWithNumber:_timelineThumbnailsPortrait.count];
        [_timelineThumbnailsPortrait addObject:image];        
    }
    else {
        [self setExtractedImage:image forImageViewWithNumber:_timelineThumbnailsLandscape.count];
        [_timelineThumbnailsLandscape addObject:image];        
    }
}

- (NSInteger)thumbnailImageViewWidthInCurrentOrientation {
    NSInteger framesCount = _isLastOrientationPortrait ? numberThumbnailsPortrait : numberThumbnailsLandscape;
    NSInteger width = (_timelineBackgroundImageView.frame.size.width / framesCount);
    return width;
}


#pragma mark Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    [self determineCurrentMovingElementWithTouch:touch];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [_timer invalidate];
    _timer = nil;
    
    [super touchesMoved:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    
    switch (_currentMovingElement) {
        case MovingElementLeftBorder:
            [self processMoveOfLeftTrimPartWithTouch:touch];
            [self checkStartPositionThumbnailChanged];
            _timer = [NSTimer scheduledTimerWithTimeInterval:self.touchedDelayToGenerateNewFrame target:self selector:@selector(timerFireMethodStart:) userInfo:nil repeats:NO];
            break;
        case MovingElementRightBorder:
            [self processMoveOfRightTrimPartWithTouch:touch];
            [self checkEndPositionThumbnailChanged];
            _timer = [NSTimer scheduledTimerWithTimeInterval:self.touchedDelayToGenerateNewFrame target:self selector:@selector(timerFireMethodEnd:) userInfo:nil repeats:NO];
            break;
        case MovingElementSlider:
            [self processMoveOfSliderWithTouch:touch];
            [self checkCurrentThumbnailNumberChanged];
            _timer = [NSTimer scheduledTimerWithTimeInterval:self.touchedDelayToGenerateNewFrame target:self selector:@selector(timerFireMethodSlider:) userInfo:nil repeats:NO];
            break;
        case MovingElementNone:
            break;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    if (_currentMovingElement != MovingElementSlider) {
        [self setSliderCorrectPosition];
    }

    if (!self.sliderHidden) {
        [self checkCurrentThumbnailNumberChanged];
        [_slider setHidden:NO];
    }
    
    switch (_currentMovingElement) {
        case MovingElementLeftBorder:
            if (delegate && [delegate respondsToSelector:@selector(timelineControl:startMovingEnded:)]) {
                [delegate timelineControl:self startMovingEnded:[self timelineStartTime]];
            }
            break;
        case MovingElementRightBorder:
            if (delegate && [delegate respondsToSelector:@selector(timelineControl:endMovingEnded:)]) {
                [delegate timelineControl:self endMovingEnded:[self timelineEndTime]];
            }
            break;
        case MovingElementSlider:
            if (delegate && [delegate respondsToSelector:@selector(timelineControl:sliderMovingEnded:)]) {
                [delegate timelineControl:self sliderMovingEnded:[self timelineSliderTime]];
            }
            break;
        case MovingElementNone:
            break;
    }
    
    _currentMovingElement = MovingElementNone;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    if (_currentMovingElement != MovingElementSlider) {
        [self setSliderCorrectPosition];    
    }

    if (!self.sliderHidden) {
        [self checkCurrentThumbnailNumberChanged];
        [_slider setHidden:NO];
    }
    
    _currentMovingElement = MovingElementNone;
}


#pragma mark Touches Processing

- (void)determineCurrentMovingElementWithTouch:(UITouch *)touch {
    
    CGPoint point = [touch locationInView:self];
    _prevLocationInCurentMovingElement = point;
    _currentMovingElement = MovingElementNone;
    
    int expandDx = 5;
    
    if (!self.sliderHidden) {
        CGRect sliderFrame = _slider.frame;
        sliderFrame.origin.x -= expandDx;
        sliderFrame.size.width += expandDx * 2;
        if (CGRectContainsPoint(sliderFrame, point)) {
            _currentMovingElement = MovingElementSlider;
            return ;
        }
    }
        
    if (!self.editing) {
        _currentMovingElement = MovingElementNone;
        return ;
    }
    
    CGRect rect = _trimTimelineView.frame;
    rect.origin.x -= expandDx;
    rect.size.width = (timelineLeft - trimViewLeft) + expandDx * 2;
    if (CGRectContainsPoint(rect, point)) {
        _currentMovingElement = MovingElementLeftBorder;
    }
    else {
        rect = _trimTimelineView.frame;
        rect.origin.x += rect.size.width - (timelineLeft - trimViewLeft) - expandDx;
        rect.size.width = (timelineLeft - trimViewLeft) + expandDx * 2;
        if (CGRectContainsPoint(rect, point)) {
            _currentMovingElement = MovingElementRightBorder;
        }
        else {
            _currentMovingElement = MovingElementNone;
        }
    }
}

- (void)processMoveOfLeftTrimPartWithTouch:(UITouch *)touch {
    
    [_slider setHidden:YES];
    
    CGPoint point = [touch locationInView:self];
    
    int r = point.x - _prevLocationInCurentMovingElement.x;
    CGRect frame = _trimTimelineView.frame;
    if (r < 0) {
        // moving left
        int left = MAX(trimViewLeft, frame.origin.x + r);
        [_trimTimelineView setFrame:CGRectMake(left, frame.origin.y, CGRectGetMaxX(frame)-left, trimViewHeight)];
    }
    else {
        int canStep = frame.size.width  - (timelineLeft - trimViewLeft)*2 - minDistanceBetweenActiveTrimParts;
        if (canStep > 0) {
            int dx =  MIN(canStep, r);
            [_trimTimelineView setFrame:CGRectMake(frame.origin.x + dx, frame.origin.y, CGRectGetWidth(frame)-dx, trimViewHeight)];
        }
    }
    
    [self setLeftOverlappedViewCorrectPosition];
    
    _prevLocationInCurentMovingElement = point;
}

- (void)processMoveOfRightTrimPartWithTouch:(UITouch *)touch {
    
    [_slider setHidden:YES];
    
    CGPoint point = [touch locationInView:self];
    
    int r = point.x - _prevLocationInCurentMovingElement.x;
    CGRect frame = _trimTimelineView.frame;
    if (r < 0) {
        // moving left
        int canStep = frame.size.width  - (timelineLeft - trimViewLeft)*2 - minDistanceBetweenActiveTrimParts;
        int dx = MIN(-r, canStep);
        [_trimTimelineView setFrame:CGRectMake(frame.origin.x, frame.origin.y, CGRectGetWidth(frame)-dx, trimViewHeight)];
    }
    else {
        int right = MIN(CGRectGetWidth(self.frame) - trimViewLeft, CGRectGetMaxX(frame) + r);
        [_trimTimelineView setFrame:CGRectMake(frame.origin.x, frame.origin.y, right-frame.origin.x, trimViewHeight)];
    }
    
    [self setRightOverlappedViewCorrectPosition];
    
    _prevLocationInCurentMovingElement = point;
}

- (void)processMoveOfSliderWithTouch:(UITouch *)touch {
    CGPoint point = [touch locationInView:self];
    int r = point.x - _prevLocationInCurentMovingElement.x;
    CGRect frame = _slider.frame;
    
    if (r < 0) {
        // moving left
        int left =  CGRectGetMinX(_trimTimelineView.frame) + (timelineLeft - trimViewLeft) - sliderWidth/2;
        [_slider setFrame:CGRectMake(MAX(left, frame.origin.x + r) , frame.origin.y, sliderWidth, sliderHeight)];
    }
    else {
        int left = CGRectGetMaxX(_trimTimelineView.frame) - (timelineLeft - trimViewLeft) - sliderWidth/2;
        [_slider setFrame:CGRectMake(MIN(left, frame.origin.x + r), frame.origin.y, sliderWidth, sliderHeight)];
    }
    
    _prevLocationInCurentMovingElement = point;
}

- (void)setLeftOverlappedViewCorrectPosition {
    [_leftOverlappedImageView setFrame:CGRectMake(0, 0, MAX(0, CGRectGetMinX(_trimTimelineView.frame) - CGRectGetMinX(_timelineBackgroundImageView.frame)), timelineHeight)];
}

- (void)setRightOverlappedViewCorrectPosition {
    int left = MIN(CGRectGetMaxX(_trimTimelineView.frame), CGRectGetWidth(self.frame)-timelineLeft) - timelineLeft;
    [_rightOverlappedImageView setFrame:CGRectMake(left, 0, CGRectGetWidth(self.frame)-left-timelineLeft, timelineHeight)];
}

- (void)setSliderCorrectPosition {
    
    CGRect frame = [_trimTimelineView frame];
    frame.origin.x += (timelineLeft - trimViewLeft);
    frame.size.width -= (timelineLeft - trimViewLeft)*2;
    
    CGRect sliderFrame = _slider.frame;
    
    if (!CGRectContainsPoint(frame, _slider.center)) {
        int r = frame.origin.x - _slider.center.x;
        if (r > 0) {
//            [_slider setFrame:CGRectOffset(_slider.frame, r, 0)];    
            int left =  CGRectGetMinX(_trimTimelineView.frame) + (timelineLeft - trimViewLeft) - sliderWidth/2;
            [_slider setFrame:CGRectMake(MAX(left, sliderFrame.origin.x + r) , sliderFrame.origin.y, sliderWidth, sliderHeight)];
        }
        else {
            r = CGRectGetMaxX(frame)-_slider.center.x;
            [_slider setFrame:CGRectOffset(_slider.frame, r, 0)];
        }
    }
}


#pragma mark Get Time

- (CMTime)videoDuration {
    return _asset.duration;
}

- (CMTime) timelineSliderTime {
    CGPoint point = [_slider center];
    return [self getTimelineTimeFromPosition:point.x - timelineLeft];
}

- (CMTime) timelineStartTime {
    int left = CGRectGetMinX(_trimTimelineView.frame);
    left -= timelineLeft;    
    left += (timelineLeft - trimViewLeft);
    return [self getTimelineTimeFromPosition:left];
}

- (CMTime) timelineEndTime {
    int right = CGRectGetMaxX(_trimTimelineView.frame);
    right -= (timelineLeft - trimViewLeft);
    right -= timelineLeft;
    return [self getTimelineTimeFromPosition:right];
}

- (CMTime) getTimelineTimeFromPosition:(NSInteger) x {
    CMTime duration = _asset.duration;
    int width = CGRectGetWidth(_timelineBackgroundImageView.frame);
    float part = x;
    part /= width;
    
    CMTimeValue currentValue = duration.value * part;
    currentValue = MIN(currentValue, duration.value);
    currentValue = MAX(0, currentValue);
    return CMTimeMake(currentValue, duration.timescale);
}

- (NSInteger)getTimelinePositionForTime:(CMTime)time {
    CMTime duration = _asset.duration;
    
    if (time.timescale != duration.timescale) {
        NSLog(@"Can't calculate correct timeline position for time with timescale %d. Expected %d timescale", time.timescale, duration.timescale);
        return 0;
    }
    
    int width = CGRectGetWidth(_timelineBackgroundImageView.frame);
    float value = time.value;
    value = (value * width) / duration.value;
    
    NSInteger position = (NSInteger)value;
    position = MIN(width, position);
    position = MAX(0, position);
    return position;
}

- (void)setTimelineSliderTime:(CMTime)time {
    
    if(_currentMovingElement == MovingElementSlider){
        return;
    }
    
    NSInteger position = [self getTimelinePositionForTime:time];
    [_slider setCenter:CGPointMake(timelineLeft + position, _slider.center.y)];

    [self setSliderCorrectPosition];    
    [self recalculateMovingElementsPosition];
}

- (void)setTimelineStartTime:(CMTime)time {
    NSInteger position = [self getTimelinePositionForTime:time];
    
    position += timelineLeft;
    position -= (timelineLeft - trimViewLeft);
    
    CGRect rect = _trimTimelineView.frame;
    if (rect.origin.x > position) {
        rect.size.width += ABS(rect.origin.x - position);
    }
    else {
        rect.size.width -= ABS(rect.origin.x - position);
    }
    
    rect.origin.x = position;
    
    _trimTimelineView.frame = rect;
    
    [self setSliderCorrectPosition];
    [self setLeftOverlappedViewCorrectPosition];
    [self recalculateMovingElementsPosition];
}

- (void)setTimelineEndTime:(CMTime)time {
    NSInteger position = [self getTimelinePositionForTime:time];
    
    position += timelineLeft;
    position += (timelineLeft - trimViewLeft);
    
    CGRect rect = _trimTimelineView.frame;
    
    if (CGRectGetMaxX(_trimTimelineView.frame) > position) {
        rect.size.width -= ABS(CGRectGetMaxX(_trimTimelineView.frame) - position);
    }
    else {
        rect.size.width += ABS(CGRectGetMaxX(_trimTimelineView.frame) - position);
    }
    
    _trimTimelineView.frame = rect;
    [self setSliderCorrectPosition];
    [self setRightOverlappedViewCorrectPosition];
    [self recalculateMovingElementsPosition];    
}


#pragma mark Get Image

// asynchronously
- (void)imageForTime:(CMTime)time completionHandler:(void(^)(UIImage *image))completionHandler {
    [_secondGenerator cancelAllCGImageGeneration];    
    [_secondGenerator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:time]] completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        UIImage *uiImage = nil;
        if (image) {
            uiImage = [[UIImage alloc] initWithCGImage:image];     
        }        
        completionHandler(uiImage);
    }];
}

- (void)imageForTime:(CMTime)time size:(CGSize)size completionHandler:(void(^)(UIImage *image))completionHandler {
    [_secondGenerator cancelAllCGImageGeneration];    
    [_secondGenerator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:time]] completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        UIImage *uiImage = nil;
        if (image) {
            CGImageRef newImage = [self resizeCGImage:image toWidth:size.width andHeight:size.height];
            uiImage = [[UIImage alloc] initWithCGImage:newImage]; 
        }
        completionHandler(uiImage);
    }];    
}

- (void)imageForTime:(CMTime)time width:(NSInteger)width completionHandler:(void(^)(UIImage *image))completionHandler {
    [_secondGenerator cancelAllCGImageGeneration];
    [_secondGenerator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:time]] completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        UIImage *uiImage = nil;
        if (image) {
            int imageWidth = CGImageGetWidth(image);
            int imageHeight = CGImageGetHeight(image);
            int newWidth = width;
            int newHeight = width *  imageHeight / imageWidth;
            
            CGImageRef newImage = [self resizeCGImage:image toWidth:newWidth andHeight:newHeight];
            uiImage = [[UIImage alloc] initWithCGImage:newImage];
            CGImageRelease(newImage);
        }
        completionHandler(uiImage);
    }];
}

- (void)imageForTime:(CMTime)time height:(NSInteger)height completionHandler:(void(^)(UIImage *image))completionHandler {
    [_secondGenerator cancelAllCGImageGeneration];
    [_secondGenerator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:time]] completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        UIImage *uiImage = nil;
        if (image) {
            int imageWidth = CGImageGetWidth(image);
            int imageHeight = CGImageGetHeight(image);
            int newWidth =  height * imageWidth / imageHeight;
            int newHeight = height;
            
            CGImageRef newImage = [self resizeCGImage:image toWidth:newWidth andHeight:newHeight];
            uiImage = [[UIImage alloc] initWithCGImage:newImage];
        }
        completionHandler(uiImage);
    }];
}

// synchronously

- (CGImageRef)cgImageForTime:(CMTime) time {
    NSError *error = nil;
    CMTime actualTime;
    [_secondGenerator cancelAllCGImageGeneration];
    CGImageRef image = [_secondGenerator copyCGImageAtTime:time actualTime:&actualTime error:&error];
    return (image != NULL) ? image : nil;
}

- (UIImage *)imageForTime:(CMTime)time {
    CGImageRef image = [self cgImageForTime:time];
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return uiImage;
}

- (UIImage *)imageForTime:(CMTime)time size:(CGSize)size {
    CGImageRef image = [self cgImageForTime:time];
    CGImageRef newImage = [self resizeCGImage:image toWidth:size.width andHeight:size.height];
    CGImageRelease(image);
    
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:newImage];
    CGImageRelease(newImage);
    return uiImage;
}

- (UIImage *)imageForTime:(CMTime)time width:(NSInteger)width {
    CGImageRef image = [self cgImageForTime:time];
    
    int imageWidth = CGImageGetWidth(image);
    int imageHeight = CGImageGetHeight(image);
    
    int newWidth = width;
    int newHeight = width *  imageHeight / imageWidth;
    
    CGImageRef newImage = [self resizeCGImage:image toWidth:newWidth andHeight:newHeight];
    CGImageRelease(image);
    
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:newImage];
    CGImageRelease(newImage);
    return uiImage;
}

- (UIImage *)imageForTime:(CMTime)time height:(NSInteger)height {
    CGImageRef image = [self cgImageForTime:time];
    
    int imageWidth = CGImageGetWidth(image);
    int imageHeight = CGImageGetHeight(image);
    
    int newWidth =  height * imageWidth / imageHeight;
    int newHeight = height;
    
    CGImageRef newImage = [self resizeCGImage:image toWidth:newWidth andHeight:newHeight];
    CGImageRelease(image);
    
    UIImage *uiImage = [UIImage imageWithCGImage:newImage];
    CGImageRelease(newImage);
    return uiImage;
}

#pragma mark 

- (void) checkCurrentThumbnailNumberChanged {
    int position = _slider.center.x - timelineLeft;
    int thumbWidth = [self thumbnailImageViewWidthInCurrentOrientation];
    int  thumbnailNumber = position / thumbWidth;
    if (thumbnailNumber != _prevThumbnailNumber) {
        if (delegate && [delegate respondsToSelector:@selector(timelineControl:sliderThumbnailChanged:)]) {
            [delegate timelineControl:self sliderThumbnailChanged:[self timelineSliderTime]];
        }
        _prevThumbnailNumber = thumbnailNumber;
    }
    if(delegate && [delegate respondsToSelector:@selector(timelineControl:sliderMoved:)]){
        [delegate timelineControl:self sliderMoved:[self timelineSliderTime]];
    }
}

- (void) checkStartPositionThumbnailChanged {
    int left = CGRectGetMinX(_trimTimelineView.frame);
    left -= timelineLeft;    
    left += (timelineLeft - trimViewLeft);
    int thumbWidth = [self thumbnailImageViewWidthInCurrentOrientation];
    int thumbNumber = left / thumbWidth;
    if (thumbNumber != _prevStartThumbnailNumber) {
        if (delegate && [delegate respondsToSelector:@selector(timelineControl:startThumbnailChanged:)]) {
            [delegate timelineControl:self startThumbnailChanged:[self timelineStartTime]];
        }
        _prevStartThumbnailNumber = thumbNumber;
    }
}

- (void) checkEndPositionThumbnailChanged {
    int right = CGRectGetMaxX(_trimTimelineView.frame);
    right -= (timelineLeft - trimViewLeft);
    right -= timelineLeft;
    int thumbWidth = [self thumbnailImageViewWidthInCurrentOrientation];
    int thumbNumber = (right-thumbWidth) / thumbWidth;
    if (thumbNumber != _prevEndThumbnailNumber) {
        if (delegate && [delegate respondsToSelector:@selector(timelineControl:endThumbnailChanged:)]) {
            [delegate timelineControl:self endThumbnailChanged:[self timelineEndTime]];
        }
        _prevEndThumbnailNumber = thumbNumber;
    }
}

- (void) recalculateMovingElementsPosition {
    
    int thumbWidth = [self thumbnailImageViewWidthInCurrentOrientation];

    int position = _slider.center.x - timelineLeft;
    int thumbnailNumber = position / thumbWidth;
    _prevThumbnailNumber = thumbnailNumber;
    
    int left = CGRectGetMinX(_trimTimelineView.frame);
    left -= timelineLeft;    
    left += (timelineLeft - trimViewLeft);
    thumbnailNumber = left / thumbWidth;
    _prevStartThumbnailNumber = thumbnailNumber;
    
    int right = CGRectGetMaxX(_trimTimelineView.frame);
    right -= (timelineLeft - trimViewLeft);
    right -= timelineLeft;
    thumbnailNumber = (right-thumbWidth) / thumbWidth;
    _prevEndThumbnailNumber = thumbnailNumber;
}


#pragma mark Hovering timers

- (void)timerFireMethodSlider:(NSTimer*)theTimer {   
    if (delegate && [delegate respondsToSelector:@selector(timelineControl:sliderHovered:)]) {
        [delegate timelineControl:self sliderHovered:[self timelineSliderTime]];
    }
    _timer = nil;
}

- (void)timerFireMethodStart:(NSTimer*)theTimer {
    if (delegate && [delegate respondsToSelector:@selector(timelineControl:startHovered:)]) {
        [delegate timelineControl:self startHovered:[self timelineStartTime]];
    }
    _timer = nil;
}

- (void)timerFireMethodEnd:(NSTimer*)theTimer {  
    if (delegate && [delegate respondsToSelector:@selector(timelineControl:endHovered:)]) {
        [delegate timelineControl:self endHovered:[self timelineEndTime]];
    }
    _timer = nil;
}



@end
