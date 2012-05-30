//
//  ViewController.m
//  VideoTimelineControl
//
//  Created by Maxim Letushov on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController {
    TimelineControl *_timelineControl;
    UIImageView *_imageView;
}

@synthesize control = _timelineControl;

- (id)init {
    self = [super init];
    if (self) {
        // TODO : add file aaa.mov into the project
        NSString *filepath = [[NSBundle mainBundle] pathForResource:@"aaa" ofType:@"MOV"];
        NSURL *fileURL = [NSURL fileURLWithPath:filepath];
        _timelineControl = [[TimelineControl alloc] initWithFrame:CGRectMake(0, 0, 320, 60) fileURL:fileURL];
        [_timelineControl setDelegate:self];
        
        // This is need for generate random values below
        srand(time(NULL));
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor blackColor]];
    
    [self.view addSubview:_timelineControl];
    
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonSystemItemCancel target:self action:@selector(cancelEditing:)];
    self.navigationItem.rightBarButtonItem = cancel;
    
    int top = CGRectGetMaxY(_timelineControl.frame) + 10;
    int left = 5;
    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(left, top, CGRectGetWidth(self.view.frame)- 2 * left, CGRectGetHeight(self.view.frame)-top - 10)];
    [_imageView setBackgroundColor:[UIColor blackColor]];
    [_imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_imageView setContentMode:UIViewContentModeScaleAspectFit];
    [self.view addSubview:_imageView];
    
    [_timelineControl imageForTime:[_timelineControl timelineSliderTime] completionHandler:^(UIImage *image) {
        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];        
    }];
    
    [self addTestButtons];
}

- (void)addTestButtons {
    UIButton *button = nil;
    button =[UIButton buttonWithType:(UIButtonTypeRoundedRect)];
    [button setFrame:CGRectMake(20, 100, 100, 30)];
    [button setTitle:@"Move Slider" forState:(UIControlStateNormal)];
    [button addTarget:self action:@selector(setSliderTime:) forControlEvents:(UIControlEventTouchDown)];
    [self.view addSubview:button];
    
    button =[UIButton buttonWithType:(UIButtonTypeRoundedRect)];
    [button setFrame:CGRectMake(20, 150, 100, 30)];
    [button setTitle:@"Move Left" forState:(UIControlStateNormal)];
    [button addTarget:self action:@selector(setLeftTime:) forControlEvents:(UIControlEventTouchDown)];
    [self.view addSubview:button];

    button =[UIButton buttonWithType:(UIButtonTypeRoundedRect)];
    [button setFrame:CGRectMake(20, 200, 100, 30)];
    [button setTitle:@"Move Right" forState:(UIControlStateNormal)];
    [button addTarget:self action:@selector(setRightTime:) forControlEvents:(UIControlEventTouchDown)];
    [self.view addSubview:button];
    
    button =[UIButton buttonWithType:(UIButtonTypeRoundedRect)];
    [button setFrame:CGRectMake(20, 250, 100, 30)];
    [button setTitle:@"Expand" forState:(UIControlStateNormal)];
    [button addTarget:self action:@selector(expand:) forControlEvents:(UIControlEventTouchDown)];
    [self.view addSubview:button];
}

- (void)setSliderTime:(UIButton *)button {
    CMTime duration = [_timelineControl videoDuration];
    CMTime time = CMTimeMake(duration.value * (rand() % 10)/10, duration.timescale);    
    
    [_timelineControl setTimelineSliderTime:time];
}

- (void)setLeftTime:(UIButton *)button {
    CMTime duration = [_timelineControl videoDuration];
    CMTime time = CMTimeMake(duration.value * (rand() % 10)/10, duration.timescale);
    [_timelineControl setTimelineStartTime:time];
}

- (void)setRightTime:(UIButton *)button {
    CMTime duration = [_timelineControl videoDuration];
    CMTime time = CMTimeMake(duration.value * (rand() % 10)/10, duration.timescale);    
    [_timelineControl setTimelineEndTime:time];
}

- (void)expand:(UIButton *)button {
    [_timelineControl expandTimelineAnimated:YES animationFinishBlock:^{
        NSLog(@"BLA"); 
    }];
}


- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [_timelineControl reloadTimelineInCurrentInterfaceOrientation];
}

#pragma mark -

- (void) cancelEditing:(UIBarButtonItem *)cancelButton {
    _timelineControl.editing = NO;
}


#pragma mark -

- (void) timelineControl:(TimelineControl *)control sliderThumbnailChanged:(CMTime)time {
    int width = CGRectGetWidth(_imageView.frame) * 2;
    [_timelineControl imageForTime:time width:width completionHandler:^(UIImage *image) {
        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
    }];
}

//- (void) timelineControl:(TimelineControl *)control startThumbnailChanged:(CMTime)time {
//
//}
//
//- (void) timelineControl:(TimelineControl *)control endThumbnailChanged:(CMTime)time {
//
//}

// end of moving
- (void) timelineControl:(TimelineControl *)control sliderMovingEnded:(CMTime)time {
    int width = CGRectGetWidth(_imageView.frame);
    [_timelineControl imageForTime:time width:width completionHandler:^(UIImage *image) {
        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
    }];
}

//- (void) timelineControl:(TimelineControl *)control startMovingEnded:(CMTime)time {
//    int width = CGRectGetWidth(_imageView.frame);
//    [_timelineControl imageForTime:[_timelineControl timelineSliderTime] width:width completionHandler:^(UIImage *image) {
//        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
//    }];
//}
//
//- (void) timelineControl:(TimelineControl *)control endMovingEnded:(CMTime)time {
//    int width = CGRectGetWidth(_imageView.frame);
//    [_timelineControl imageForTime:[_timelineControl timelineSliderTime] width:width completionHandler:^(UIImage *image) {
//        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
//    }];    
//}


- (void) timelineControl:(TimelineControl *)control sliderHovered:(CMTime)time {
    int width = CGRectGetWidth(_imageView.frame);
    [_timelineControl imageForTime:time width:width completionHandler:^(UIImage *image) {
        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
    }];
}

//- (void) timelineControl:(TimelineControl *)control startHovered:(CMTime)time {
//    int width = CGRectGetWidth(_imageView.frame);
//    [_timelineControl imageForTime:time width:width completionHandler:^(UIImage *image) {
//        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
//    }];
//}
//
//- (void) timelineControl:(TimelineControl *)control endHovered:(CMTime)time {
//    int width = CGRectGetWidth(_imageView.frame);
//    [_timelineControl imageForTime:time width:width completionHandler:^(UIImage *image) {
//        [_imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
//    }];
//}



@end
