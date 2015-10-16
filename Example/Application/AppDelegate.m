//
//  AppDelegate.m
//  Example
//
//  Created by Ezequiel Scaruli on 4/24/15.
//  Copyright (c) 2015 Ezequiel Scaruli. All rights reserved.
//

#import <ESFeedbackViewController/ESFeedbackViewController.h>

#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window setRootViewController:[ViewController new]];
    [self.window makeKeyAndVisible];
    
    [ESFeedbackViewController setNumberOfLaunchesToShow:1];
    [ESFeedbackViewController registerAppLaunch];
    
    return YES;
}


@end
