//
//  ESFeedbackViewController.m
//
//  Created by Ezequiel Scaruli on 4/8/15.
//

#import <StoreKit/StoreKit.h>
#import <UIView+ESBlur.h>

#import "ESFeedbackViewController.h"
#import "ESFeedbackPromptViewController.h"
#import "ESFeedbackNavigationController.h"

#import "UIColor+Hex.h"
#import "ESFeedbackViewController+Navigation.h"
#import "ESFeedbackViewController+Keyboard.h"
#import "ESFeedbackViewController+Constraints.h"


// NSUserDefauls keys.
static NSString *const _appLaunchCountKey = @"ESFeedbackAppLaunchCount";
static NSString *const _feedbackWasShownKey = @"ESFeedbackWasShown";

static NSInteger _numberOfLaunchesToShow = 0;
static UIFont *_textFont;
static UIFont *_buttonsFont;
static UIColor *_cancelButtonBackgroundColour;
static UIColor *_okButtonBackgroundColour;
static UIColor *_windowTintColour;
static NSString *_appID;
static void (^_onPromptWasDismissed)(ESFeedbackPromptViewController *, BOOL);

// A reference to the main window of the app.
static UIWindow *_mainWindow;

// The window that shows the controller.
static UIWindow *_presentingWindow;

static ESFeedbackViewController *_currentInstance;

NSString *templateReviewURL = @"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=APP_ID";
NSString *templateReviewURLiOS7 = @"itms-apps://itunes.apple.com/app/idAPP_ID";
NSString *templateReviewURLiOS8 = @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=APP_ID&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software";

@interface ESFeedbackViewController () <SKStoreProductViewControllerDelegate>

@property (nonatomic, weak) IBOutlet UIView *navigationContainer;
@property (nonatomic, weak) IBOutlet UIView *buttonsContainer;
@property (nonatomic, weak) IBOutlet UIButton *cancelButton;
@property (nonatomic, weak) IBOutlet UIButton *OKButton;
@property (nonatomic, weak) IBOutlet UIView *loadingView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *generalContainerHeightContraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *generalContainerCenterContraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *navigationContainerBottomContraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *buttonsContainerHeightConstraint;

@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) ESFeedbackNavigationController *feedbackNavigationController;
@property (nonatomic, strong) SKStoreProductViewController *storeViewController;

@end


@implementation ESFeedbackViewController


#pragma mark - Class methods


+ (void)registerAppLaunch {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger launchCount = [userDefaults integerForKey:_appLaunchCountKey];
    ++launchCount;
    
    [userDefaults setInteger:launchCount forKey:_appLaunchCountKey];
    [userDefaults synchronize];
}


+ (void)setNumberOfLaunchesToShow:(NSInteger)numberOfLaunches {
    _numberOfLaunchesToShow = numberOfLaunches;
}


+ (void)setAppID:(NSString *)appID {
    _appID = appID;
}


+ (void)showIfNecessary {
    if ([self shouldShow]) {
        [self show];
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:YES forKey:_feedbackWasShownKey];
        [userDefaults synchronize];
    }
}


+ (UIFont *)textFont {
    return _textFont ?: [UIFont systemFontOfSize:14.0];
}


+ (void)setTextFont:(UIFont *)font {
    _textFont = font;
}


+ (UIFont *)buttonsFont {
    return _buttonsFont ?: [UIFont boldSystemFontOfSize:14.0];
}


+ (void)setButtonsFont:(UIFont *)font {
    _buttonsFont = font;
}

+ (UIColor *)cancelButtonBackgroundColour {
    return _cancelButtonBackgroundColour;
}

+ (void)setCancelButtonBackgroundColour:(UIColor *)colour {
    _cancelButtonBackgroundColour = colour;
}

+ (UIColor *)okButtonBackgroundColour {
    return _okButtonBackgroundColour;
}

+ (void)setOkButtonBackgroundColour:(UIColor *)colour {
    _okButtonBackgroundColour = colour;
}

+ (void)setTintColor:(UIColor *)tintColor {
    _windowTintColour = tintColor;
}


+ (void)setOnPromptWasDismissed:(void (^)(ESFeedbackPromptViewController *, BOOL))block {
    _onPromptWasDismissed = block;
}


#pragma mark - Init / Deinit


- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self != nil) {
        [self subscribeToKeyboardNotifications];
    }
    
    return self;
}


- (void)dealloc {
    [self unsubscribeFromKeyboardNotifications];
}


#pragma mark - UIViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupStyles];
    [self setupFeedbackNavigationController];
    [self setupWithCurrentPromptAnimated:NO];
}


- (void)viewWillAppear:(BOOL)animated {
    self.blurView.alpha = 0.0;
    self.view.alpha = 0.0;
    [self fadeInBlurView];
}


- (BOOL)shouldAutorotate {
    return NO;
}


#pragma mark - Action


- (IBAction)cancelButtonAction {
    ESFeedbackPromptViewController *currentPromptVC = (ESFeedbackPromptViewController *) [self.feedbackNavigationController topViewController];
    [currentPromptVC performCancelAction];
}


- (IBAction)OKButtonAction {
    ESFeedbackPromptViewController *currentPromptVC = (ESFeedbackPromptViewController *) [self.feedbackNavigationController topViewController];
    [currentPromptVC performOKAction];
}


#pragma mark - SKStoreProductViewControllerDelegate


- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:^{
        [ESFeedbackViewController clearCurrentInstance];
    }];
}


#pragma mark - Private methods


+ (BOOL)shouldShow {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger launchCount = [userDefaults integerForKey:_appLaunchCountKey];
    BOOL wasShown = [userDefaults boolForKey:_feedbackWasShownKey];
    
    return launchCount >= _numberOfLaunchesToShow && !wasShown;
}


+ (void)show {
    // First of all, hold a reference to the main window.
    _mainWindow = [[[UIApplication sharedApplication] delegate] window];
    _mainWindow.tintColor = _windowTintColour;
    
    // Then create a new window to present the feedback view controller.
    _presentingWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _presentingWindow.backgroundColor = [UIColor clearColor];
    _presentingWindow.rootViewController = [ESFeedbackViewController instance];
    
    [_presentingWindow makeKeyAndVisible];
}


+ (instancetype)instance {
    if (_currentInstance == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Feedback" bundle:nil];
        _currentInstance = [storyboard instantiateInitialViewController];
    }
    
    return _currentInstance;
}


+ (void)clearCurrentInstance {
    _currentInstance = nil;
}


- (void)fadeInBlurView {
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.blurView.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         [self fadeInView];
                     }];
}


- (void)fadeInView {
    [UIView animateWithDuration:0.5 animations:^{
        self.view.alpha = 1.0;
    }];
}


- (void)dismissClearingCurrentInstance:(BOOL)clear {
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.alpha = 0.0;
                     } completion:^(BOOL finished) {
                         [_mainWindow makeKeyAndVisible];
                         _presentingWindow = nil;
                         
                         if (clear) {
                             [ESFeedbackViewController clearCurrentInstance];
                         }
                     }];
}


- (void)setupStyles {
    [self setupBlurView];
    [self setupCancelButton];
    [self setupOKButton];
    
    self.loadingView.hidden = YES;
}


- (void)setupBlurView {
    UIColor *tintColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    self.blurView = [_mainWindow viewByApplyingBlurWithTintColor:tintColor];
    
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.blurView];
    [self setupEdgeConstraintsForView:self.blurView];
    
    [self.view sendSubviewToBack:self.blurView];
}


- (void)setupCancelButton {
    self.cancelButton.backgroundColor = _cancelButtonBackgroundColour ?: [UIColor colorWithHex:0xFAF6F5];
    self.cancelButton.tintColor = [UIColor colorWithHex:0x595250];
    
    self.cancelButton.titleLabel.font = [ESFeedbackViewController buttonsFont];
}


- (void)setupOKButton {
    self.OKButton.backgroundColor = _okButtonBackgroundColour ?: [UIColor colorWithHex:0x68BD4E];
    self.OKButton.tintColor = [UIColor whiteColor];
    
    self.OKButton.titleLabel.font = [ESFeedbackViewController buttonsFont];
}


- (void)setupWithCurrentPromptAnimated:(BOOL)animated {
    ESFeedbackPromptViewController *currentPromptVC = (ESFeedbackPromptViewController *) [self.feedbackNavigationController topViewController];
    
    [self.cancelButton setTitle:[currentPromptVC textForCancelButton]
                       forState:UIControlStateNormal];
    
    [self.OKButton setTitle:[currentPromptVC textForOKButton]
                   forState:UIControlStateNormal];
    
    [self setupGeneralContainerHeightAnimated:animated];
}


- (void)setupGeneralContainerHeightAnimated:(BOOL)animated {
    ESFeedbackPromptViewController *currentPromptVC = (ESFeedbackPromptViewController *) [self.feedbackNavigationController topViewController];
    
    [currentPromptVC.view setNeedsLayout];
    [currentPromptVC.view layoutIfNeeded];
    
    CGFloat heightConstant = [currentPromptVC heightForNavigationController];
    heightConstant += self.navigationContainerBottomContraint.constant;
    heightConstant += self.buttonsContainerHeightConstraint.constant;
    
    void (^animations)(void) = ^{
        self.generalContainerHeightContraint.constant = heightConstant;
        [self.view layoutIfNeeded];
    };
    
    if (animated) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.5 animations:animations];
    } else {
        animations();
    }
}


- (void)goToAppStoreAndPerformOnCompletion:(void (^)(void))completion {
    if (_appID == nil) {
        // Nothing to do.
        return;
    }
    
    self.storeViewController = [[SKStoreProductViewController alloc] init];
    self.storeViewController.delegate = self;
    
    NSNumber *appID = @(_appID.integerValue);
    NSDictionary *parameters = @{SKStoreProductParameterITunesItemIdentifier: appID};
    
    self.loadingView.hidden = NO;
    
    __weak typeof (self) weakSelf = self;
    
    [self.storeViewController loadProductWithParameters:parameters completionBlock:^(BOOL result, NSError *error) {
        weakSelf.loadingView.hidden = YES;
        
        if (completion != nil) {
            completion();
        }
        
        BOOL openInAppStore = [[UIDevice currentDevice].systemVersion floatValue] >= 7.0;
        if (openInAppStore) {
            NSString *reviewURL = [templateReviewURL stringByReplacingOccurrencesOfString:@"APP_ID" withString:[NSString stringWithFormat:@"%@", appID]];
            
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0 && [[[UIDevice currentDevice] systemVersion] floatValue] < 8.0) {
                reviewURL = [templateReviewURLiOS7 stringByReplacingOccurrencesOfString:@"APP_ID" withString:[NSString stringWithFormat:@"%@", appID]];
            }
            // iOS 8 needs a different templateReviewURL also @see https://github.com/arashpayan/appirater/issues/182
            else if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
            {
                reviewURL = [templateReviewURLiOS8 stringByReplacingOccurrencesOfString:@"APP_ID" withString:[NSString stringWithFormat:@"%@", appID]];
            }
            
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:reviewURL]];
        } else {
            UIViewController *rootVC = [UIApplication sharedApplication].delegate.window.rootViewController;
            [rootVC presentViewController:weakSelf.storeViewController animated:YES completion:nil];
        }
    }];
}

- (void)promptViewController:(ESFeedbackPromptViewController *)promptVC wasDismissedChoosingOK:(BOOL)ok {
    if (_onPromptWasDismissed != nil) {
        _onPromptWasDismissed(promptVC, ok);
    }
}


@end
