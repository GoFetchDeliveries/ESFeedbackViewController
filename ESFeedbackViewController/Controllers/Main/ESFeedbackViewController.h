//
//  ESFeedbackViewController.h
//
//  Created by Ezequiel Scaruli on 4/8/15.
//

#import <UIKit/UIKit.h>

#import "ESFeedbackPromptViewController.h"


@interface ESFeedbackViewController : UIViewController

/**
 Shows the controller if the amount of application launches is enough.
 */
+ (void)showIfNecessary;

/**
 Registers an app launch. This should be called in the application delegate,
 preferently in application:didFinishLaunchingWithOptions: method.
 */
+ (void)registerAppLaunch;

/**
 Sets the number of launches necessary for the controller to be shown.
 */
+ (void)setNumberOfLaunchesToShow:(NSInteger)numberOfLaunches;

/**
 Sets the app id. Necessary to redirect the user to the App Store.
 */
+ (void)setAppID:(NSString *)appID;

/*
 The font used when displaying texts. If not set, defaults to the system one.
 */
+ (UIFont *)textFont;
+ (void)setTextFont:(UIFont *)font;

/**
 The font used when displaying buttons. If not set, defaults to the bold system
 one.
 */
+ (UIFont *)buttonsFont;
+ (void)setButtonsFont:(UIFont *)font;

+ (void)setTintColor:(UIColor *)tintColor;

/**
 This block called when the OK or Cancel button is pressed in each of the
 prompt screens. Receives the controller for the screen, and a boolean
 indicating if the OK button was pressed.
 */
+ (void)setOnPromptWasDismissed:(void (^)(ESFeedbackPromptViewController *, BOOL))block;

@end
