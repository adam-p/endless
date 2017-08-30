/*
 * Copyright (c) 2017, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "AppDelegate.h"
#import "OnboardingViewController.h"
#import "OnboardingInfoViewController.h"
#import "OnboardingLanguageViewController.h"

#define kNumOnboardingViews 4
#define kSubtitleFontName @"SanFranciscoDisplay-Regular"

@implementation OnboardingViewController {
	UIButton *skipButton;

	UIView *titleView;
	UIView *subtitleView;

	UILabel *title;
	UILabel *subtitle;

	UIImageView *backDrop;
	UIImageView *logo;
	CGFloat bannerOffset;

	NSLayoutConstraint *titleViewTopConstraint;

	BOOL isRTL;
}

// Force portrait orientation during onboarding
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown);
}

- (void)viewDidLoad {
	[super viewDidLoad];

	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	[self.view setBackgroundColor:[UIColor whiteColor]];
	[[UIApplication sharedApplication] setStatusBarHidden:YES]; // Full screen onboarding

	/* Customize UIPageControl */
	UIPageControl *pageControl = [UIPageControl appearance];
	pageControl.pageIndicatorTintColor = [UIColor colorWithRed:0.89 green:0.89 blue:0.89 alpha:1.0];
	pageControl.currentPageIndicatorTintColor = [UIColor colorWithRed:0.93 green:0.25 blue:0.21 alpha:1.0];
	pageControl.backgroundColor = [UIColor clearColor];
	pageControl.opaque = NO;

	/* Setup UIPageViewController */
	self.pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	self.pageController.dataSource = self;
	self.pageController.delegate = self;
	self.pageController.view.frame = self.view.bounds;

	/* Setup and present initial OnboardingChildViewController */
	UIViewController<OnboardingChildViewController> *initialViewController = [self viewControllerAtIndex:0];
	NSArray *viewControllers = [NSArray arrayWithObject:initialViewController];

	[self.pageController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
	[self addChildViewController:self.pageController];

	[self.view addSubview:self.pageController.view];
	[self.pageController didMoveToParentViewController:self];

	/* Add static views to OnboardingViewController */

	/* Setup bannerLogoView */

	// ChildViewController will call getBannerOffset to determine
	// how much space the banner consumes and layout accordingly.
	bannerOffset = 0;

	// Add backdrop
	UIImage *background = [UIImage imageNamed:@"background"];
	backDrop = [[UIImageView alloc] initWithImage:background];
	backDrop.translatesAutoresizingMaskIntoConstraints = NO;
	backDrop.contentMode = UIViewContentModeScaleAspectFill;
	[backDrop.layer setMinificationFilter:kCAFilterTrilinear];

	[self.view addSubview:backDrop];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:backDrop
														  attribute:NSLayoutAttributeTop
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeTop
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:backDrop
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:backDrop
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:backDrop
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeHeight
														 multiplier:.4f
														   constant:0]];

	// Add logo
	logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"language-selector-logo"]];
	logo.translatesAutoresizingMaskIntoConstraints = NO;
	logo.contentMode = UIViewContentModeScaleAspectFit;
	[logo.layer setMinificationFilter:kCAFilterTrilinear];

	[backDrop addSubview:logo];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:logo
														  attribute:NSLayoutAttributeCenterY
														  relatedBy:NSLayoutRelationEqual
															 toItem:backDrop
														  attribute:NSLayoutAttributeBottom
														 multiplier:UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? .90f :.82f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:logo
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:logo
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:.5f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:logo
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:logo
														  attribute:NSLayoutAttributeWidth
														 multiplier:1.f
														   constant:0]];

	// Setup containers which will hold title and subtitle
	titleView = [[UIView alloc] init];
	titleView.translatesAutoresizingMaskIntoConstraints = NO;
	[backDrop addSubview:titleView];

	titleViewTopConstraint = [NSLayoutConstraint constraintWithItem:titleView
														  attribute:NSLayoutAttributeTop
														  relatedBy:NSLayoutRelationEqual
															 toItem:backDrop
														  attribute:NSLayoutAttributeTop
														 multiplier:1.f
														   constant:0];
	[self.view addConstraint:titleViewTopConstraint];

	subtitleView = [[UIView alloc] init];
	subtitleView.translatesAutoresizingMaskIntoConstraints = NO;
	[backDrop addSubview:subtitleView];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subtitleView
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:backDrop
														  attribute:NSLayoutAttributeWidth
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:titleView
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:backDrop
														  attribute:NSLayoutAttributeWidth
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subtitleView
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:titleView
														  attribute:NSLayoutAttributeHeight
														 multiplier:.8f
														   constant:0]];

	// Add title
	title = [[UILabel alloc] init];
	title.numberOfLines = 0;
	title.adjustsFontSizeToFitWidth = YES;
	title.userInteractionEnabled = NO;
	title.font = [UIFont fontWithName:@"Bourbon-Oblique" size:self.view.frame.size.width * 0.10625f];
	title.textColor = [UIColor whiteColor];
	title.textAlignment = NSTextAlignmentCenter;
	title.text = NSLocalizedStringWithDefaultValue(@"ONBOARDING_APP_NAME", nil, [NSBundle mainBundle], @"PSIPHON BROWSER", @"Title displayed at top of all onboarding screens. This should be in all-caps if that makes sense in your language.");
	if ([self unsupportedCharactersForFont:title.font.fontName withString:title.text]) {
		title.font = [UIFont systemFontOfSize:self.view.frame.size.width * 0.075f];
	}
	title.translatesAutoresizingMaskIntoConstraints = NO;
	[titleView addSubview:title];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:title
														  attribute:NSLayoutAttributeBottom
														  relatedBy:NSLayoutRelationEqual
															 toItem:titleView
														  attribute:NSLayoutAttributeBottom
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:title
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:title
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:.9f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:title
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationLessThanOrEqual
															 toItem:titleView
														  attribute:NSLayoutAttributeHeight
														 multiplier:1.f
														   constant:0]];

	// Add subtitle
	subtitle = [[UILabel alloc] init];
	subtitle.translatesAutoresizingMaskIntoConstraints = NO;
	[subtitleView addSubview:subtitle];

	subtitle.adjustsFontSizeToFitWidth = YES;
	subtitle.font = [UIFont fontWithName:kSubtitleFontName size:18.0f];
	subtitle.text = NSLocalizedStringWithDefaultValue(@"ONBOARDING_APP_SUBTITLE", nil, [NSBundle mainBundle], @"BROWSE BEYOND BORDERS", @"Title displayed at the top of all onboardings screens. This should be in all-caps if that makes sense in your language. This is a slogan and should be kept short and punchy.");
	subtitle.textAlignment = NSTextAlignmentCenter;
	subtitle.textColor = [UIColor whiteColor];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subtitle
														  attribute:NSLayoutAttributeCenterY
														  relatedBy:NSLayoutRelationEqual
															 toItem:subtitleView
														  attribute:NSLayoutAttributeCenterY
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subtitle
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subtitle
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:title
														  attribute:NSLayoutAttributeWidth
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subtitle
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:backDrop
														  attribute:NSLayoutAttributeHeight
														 multiplier:.066f
														   constant:0]];

	// Vertical layout constraints within backdrop
	NSDictionary *views = @{
							@"logo": logo,
							@"titleView": titleView,
							@"subtitleView": subtitleView
							};

	[backDrop addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[titleView][subtitleView][logo]" options:0 metrics:nil views:views]];

	/* Setup skip button */
	skipButton = [[UIButton alloc] init];
	[skipButton setTitle:NSLocalizedStringWithDefaultValue(@"ONBOARDING_SKIP_BUTTON", nil, [NSBundle mainBundle], @"SKIP", @"Text of button at the top right or left (depending on rtl) of the onboarding screens which allows user to skip onboarding") forState:UIControlStateNormal];
	[skipButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
	[skipButton.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.0f]];
	[skipButton.titleLabel setAdjustsFontSizeToFitWidth:YES];
	skipButton.alpha = 0; // initially hidden

	[skipButton addTarget:self
				   action:@selector(onboardingEnded)
		 forControlEvents:UIControlEventTouchUpInside];

	[self.view addSubview:skipButton];

	skipButton.translatesAutoresizingMaskIntoConstraints = NO;

	id <UILayoutSupport> topLayoutGuide =  self.topLayoutGuide;

	NSDictionary *viewsDictionary = @{
									  @"topLayoutGuide": topLayoutGuide,
									  @"skipButton": skipButton,
									  };

	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topLayoutGuide]-[skipButton]" options:0 metrics:nil views:viewsDictionary]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[skipButton]-|" options:0 metrics:nil views:viewsDictionary]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:skipButton
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeHeight
														 multiplier:.04f
														   constant:0]];

	UITapGestureRecognizer *tutorialPress =
	[[UITapGestureRecognizer alloc] initWithTarget:self
											action:@selector(moveToNextPage)];
	[self.view addGestureRecognizer:tutorialPress];
}
#pragma mark - UIPageViewControllerDelegate methods and helper functions

- (BOOL)unsupportedCharactersForFont:(NSString*)font withString:(NSString*)string {
	for (NSInteger charIdx = 0; charIdx < string.length; charIdx++) {
		NSString *character = [NSString stringWithFormat:@"%C", [string characterAtIndex:charIdx]];
		// TODO: need to enumerate a longer list of special characters for this to be more correct.
		if ([character isEqualToString:@" "]) {
			// Skip special characters
			continue;
		}
		CGFontRef cgFont = CGFontCreateWithFontName((CFStringRef)font);
		if (CGFontGetGlyphWithGlyphName(cgFont,  (__bridge CFStringRef)character) == 0) {
			return YES;
		}
	}
	return NO;
}

- (void)beginHideLanguageScreenHeader {
	if (backDrop.image == nil) {
		backDrop.image = [UIImage imageNamed:@"background"];
	}
	title.textColor = [UIColor whiteColor];
	if ([self getCurrentPageIndex] == PsiphonOnboardingPage1Index) {
		backDrop.alpha = 0; // should start hidden
	}
	titleViewTopConstraint.constant = 0;
	[UIView animateWithDuration:0.3 animations:^{
		skipButton.alpha = 0;
		titleView.alpha = 0.5;
		subtitleView.alpha = 0.5;
		backDrop.alpha = 0.5;
		logo.alpha = 0.5;
	}];
}

- (void)hideLanguageScreenHeader {
	backDrop.image = nil; // remove backdrop
	title.textColor = [UIColor colorWithRed:0.76 green:0.29 blue:0.21 alpha:1.0];
	titleViewTopConstraint.constant = 40;

	[UIView animateWithDuration:0.3 animations:^{
		skipButton.alpha = 1;
		titleView.alpha = 1;
		subtitleView.alpha = 0;
		backDrop.alpha = 1;
		logo.alpha = 0;
	}];
}

- (void)showLanguageScreenHeader {
	if (backDrop.image == nil) {
		backDrop.image = [UIImage imageNamed:@"background"];
	}
	title.textColor = [UIColor whiteColor];
	titleViewTopConstraint.constant = 0;
	[UIView animateWithDuration:0.3 animations:^{
		skipButton.alpha = 0;
		titleView.alpha = 1;
		subtitleView.alpha = 1;
		backDrop.alpha = 1;
		logo.alpha = 1;
	}];
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {
	UIViewController <OnboardingChildViewController>*presentedViewController = [_pageController.viewControllers objectAtIndex:0];

	if (presentedViewController.index > PsiphonOnboardingLanguageSelectionScreenIndex) {
		[self hideLanguageScreenHeader];
	} else {
		[self showLanguageScreenHeader];
	}
}

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers {
	UIViewController <OnboardingChildViewController>*presentedViewController = [_pageController.viewControllers objectAtIndex:0];
	UIViewController <OnboardingChildViewController>*pendingViewController = (UIViewController <OnboardingChildViewController> *)[pendingViewControllers objectAtIndex:0];

	if ((presentedViewController.index == PsiphonOnboardingLanguageSelectionScreenIndex && pendingViewController.index == PsiphonOnboardingPage1Index ) || (presentedViewController.index == PsiphonOnboardingPage1Index && pendingViewController.index == PsiphonOnboardingLanguageSelectionScreenIndex)) {
		// If we are transitioning from language selection screen to first onboarding screen or vice versa
		[self beginHideLanguageScreenHeader];
	}
}


- (NSInteger)getCurrentPageIndex {
	if ([_pageController.viewControllers count] == 0) {
		return 0;
	}

	UIViewController <OnboardingChildViewController>*presentedViewController = [_pageController.viewControllers objectAtIndex:0];
	return presentedViewController.index;
}

#pragma mark - UIPageViewControllerDataSource methods and helper functions

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {

	NSUInteger index = [(UIViewController <OnboardingChildViewController>*)viewController index];

	if (index == 0) {
		return nil;
	}

	index--;

	return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {

	NSUInteger index = [(UIViewController <OnboardingChildViewController>*)viewController index];

	index++;

	if (index == kNumOnboardingViews) {
		return nil;
	}

	return [self viewControllerAtIndex:index];
}

- (UIViewController <OnboardingChildViewController>*)viewControllerAtIndex:(NSUInteger)index {
	UIViewController<OnboardingChildViewController> *childViewController;
	if (index == 0) {
		childViewController = [[OnboardingLanguageViewController alloc] init];
	} else {
		childViewController = [[OnboardingInfoViewController alloc] init];
	}
	childViewController.delegate = self;
	childViewController.index = index;

	return childViewController;
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
	// The number of items in the UIPageControl
	return kNumOnboardingViews + 1; // extra dot which signifies tutorial screens
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
	// The selected dot in the UIPageControl
	return [self getCurrentPageIndex];
}

#pragma mark - OnboardingChildViewController delegate methods

- (CGFloat)getBannerOffset {
	return logo.frame.origin.y + logo.frame.size.height;
}

- (CGFloat)getTitleOffset {
	return titleView.frame.origin.y + titleView.frame.size.height;
}

- (void)moveToNextPage {
	[self moveToViewAtIndex:[self getCurrentPageIndex]+1];
}

- (void)moveToViewAtIndex:(NSInteger)index {
	if (index >= kNumOnboardingViews) {
		[self onboardingEnded];
	} else {
		if (index == PsiphonOnboardingLanguageSelectionScreenIndex) {
			[self showLanguageScreenHeader];
		} else {
			[self hideLanguageScreenHeader];
		}
		[self.pageController setViewControllers:@[[self viewControllerAtIndex:index]] direction:isRTL ? UIPageViewControllerNavigationDirectionReverse : UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
	}
}

- (void)onboardingEnded {
	id<OnboardingViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(onboardingEnded)]) {
		[strongDelegate onboardingEnded];
	}
}

@end
