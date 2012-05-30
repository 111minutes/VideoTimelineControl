//
//  ViewControllerBLA.m
//  VideoTimelineControl
//
//  Created by Maxim Letushov on 4/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewControllerBLA.h"
#import "ViewController.h"

@interface ViewControllerBLA ()

@end

@implementation ViewControllerBLA

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)button1DidTapped:(id)sender {
    ViewController *vc = [[ViewController alloc] init];

    vc.control.editing = YES;
    vc.control.sliderHidden = NO;
    vc.control.touchedDelayToGenerateNewFrame = 0.3;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)button2DidTapped:(id)sender {
    ViewController *vc = [[ViewController alloc] init];
    
    vc.control.editing = NO;
    vc.control.sliderHidden = NO;
    vc.control.touchedDelayToGenerateNewFrame = 0.3;
    
    [self.navigationController pushViewController:vc animated:YES];   
}

- (IBAction)button3DidTapped:(id)sender {
    ViewController *vc = [[ViewController alloc] init];
    
    vc.control.editing = YES;
    vc.control.sliderHidden = YES;  
    vc.control.touchedDelayToGenerateNewFrame = 0.3;
    
    [self.navigationController pushViewController:vc animated:YES];       
}


@end
