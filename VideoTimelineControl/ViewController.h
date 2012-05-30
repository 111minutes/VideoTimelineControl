//
//  ViewController.h
//  VideoTimelineControl
//
//  Created by Maxim Letushov on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TimelineControlDelegate.h"
#import "TimelineControl.h"

@interface ViewController : UIViewController <TimelineControlDelegate>

@property (nonatomic, strong) TimelineControl *control;

@end
