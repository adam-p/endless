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

#import "TutorialViewController.h"

@implementation TutorialViewController {
	UIButton *skipButton;
	NSLayoutConstraint *skipButtonCenterY;

	TutorialViewController *onboarding;

	BOOL showOnboarding;
	BOOL isRTL;
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	// skipButton.centerY == navigationBar.centerY
	skipButtonCenterY.constant = [self getSkipButtonFrame].origin.y;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	skipButton.alpha = 0;
	[coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
	 {
		 skipButtonCenterY.constant = [self getSkipButtonFrame].origin.y;

		 if ([self getCurrentPageIndex] > PsiphonTutorialOnboardingIndex && [self getCurrentPageIndex] < PsiphonTutorialPage3Index) {
			 [UIView animateWithDuration:0.5 animations:^{
				 skipButton.alpha = 1;
			 }];
		 }
	 }];

	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
	showOnboarding = ![[NSUserDefaults standardUserDefaults] boolForKey:kHasBeenOnboardedKey];

	self.delegate = self;
	self.dataSource = self;

	/* Setup and present initial TutorialPageViewController */
	UIViewController *initialViewController = [self viewControllerAtIndex:showOnboarding ? PsiphonTutorialOnboardingIndex : PsiphonTutorialPage1Index];
	if (showOnboarding && [initialViewController isKindOfClass:[TutorialPageViewController class]]) {
		onboarding = (TutorialViewController*)initialViewController;
	}

	NSArray *viewControllers = [NSArray arrayWithObject:initialViewController];
	[self setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];

	/* Setup views and constraints */
	[self setupSkipButton];
	[self.view addSubview:skipButton];

	NSDictionary *viewsDictionary = @{ @"skipButton": skipButton };
	[skipButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[skipButton]-30-|" options:0 metrics:nil views:viewsDictionary]];

	skipButtonCenterY = [NSLayoutConstraint constraintWithItem:skipButton
													 attribute:NSLayoutAttributeTop
													 relatedBy:NSLayoutRelationEqual
														toItem:self.view
													 attribute:NSLayoutAttributeTop
													multiplier:1.f constant:1.f];
	[self.view addConstraint:skipButtonCenterY];

	UITapGestureRecognizer *tutorialPress =
	[[UITapGestureRecognizer alloc] initWithTarget:self
											action:@selector(moveToNextPage)];
	[self.view addGestureRecognizer:tutorialPress];

	[self presentedViewControllerChanged];
}

#pragma mark - UIPageViewControllerDelegate methods and helper functions

- (void)moveToNextPage {
	__weak TutorialViewController *weakSelf = self;

	[self setViewControllers:@[[self viewControllerAtIndex:[self getCurrentPageIndex]+1]] direction:isRTL ? UIPageViewControllerNavigationDirectionReverse: UIPageViewControllerNavigationDirectionForward animated:YES completion:^(BOOL finished) {
		[weakSelf presentedViewControllerChanged];
	}];
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {

	if (completed) {
		// Notify delegate that the presented TutorialPageViewController has changed
		[self presentedViewControllerChanged];
	}

	if ([self getCurrentPageIndex] > PsiphonTutorialOnboardingIndex && [self getCurrentPageIndex] < PsiphonTutorialPage3Index) {
		skipButton.alpha = 1;
	}
}

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers {
	TutorialPageViewController *tc = (TutorialPageViewController*)[pendingViewControllers objectAtIndex:0];

	if (tc != nil && (tc.index < PsiphonTutorialPage1Index || tc.index >= PsiphonTutorialPage3Index)) {
		// Hide skip tutorial button on the last page
		skipButton.alpha = 0;
	}
}

- (NSInteger)getCurrentPageIndex {
	TutorialPageViewController *presentedViewController = (TutorialPageViewController*)[self.viewControllers objectAtIndex:0];
	return presentedViewController.index;
}

// Notify delegate to perform necessary operations required
// for new tutorial step.
- (void)presentedViewControllerChanged {
	id<TutorialViewControllerDelegate> strongDelegate = self.webViewController;

	if ([strongDelegate respondsToSelector:@selector(moveToStep:)]) {
		[strongDelegate moveToStep:[self getCurrentPageIndex]];
	}

	if ([self getCurrentPageIndex] < PsiphonTutorialPage1Index || [self getCurrentPageIndex] >= PsiphonTutorialPage3Index) {
		skipButton.alpha = 0;
	}
}

#pragma mark - UIPageViewControllerDataSource methods and helper functions

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
	NSUInteger index = [(TutorialPageViewController*)viewController index];

	if (showOnboarding) {
		if (index <= PsiphonTutorialOnboardingIndex) {
			return nil;
		} else if (index == PsiphonTutorialPage1Index) {
			return onboarding;
		}
	} else {
		if (index <= PsiphonTutorialPage1Index) {
			return nil;
		}
	}

	index--;

	return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
	NSUInteger index = [(TutorialPageViewController*)viewController index];

	index++;

	if (index == PsiphonTutorialPageFinalIndex + 1) {
		return nil;
	}

	return [self viewControllerAtIndex:index];
}

- (UIViewController*)viewControllerAtIndex:(NSUInteger)index {
	TutorialPageViewController *childViewController = [[TutorialPageViewController alloc] init];

	childViewController.index = index;
	childViewController.delegate = self;

	return childViewController;
}

#pragma mark - TutorialViewController helper functions

- (void)setupSkipButton {
	skipButton = [[UIButton alloc] init];
	[skipButton setTitle:NSLocalizedString(@"SKIP TUTORIAL", @"") forState:UIControlStateNormal];
	[skipButton setTitleColor:[UIColor colorWithRed:0.56 green:0.57 blue:0.58 alpha:1.0] forState:UIControlStateNormal];
	[skipButton.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:17.0f]];
	[skipButton.titleLabel setAdjustsFontSizeToFitWidth:YES];
	[skipButton.titleLabel setTextAlignment:NSTextAlignmentLeft];

	skipButton.translatesAutoresizingMaskIntoConstraints = NO;

	[skipButton addTarget:self
				   action:@selector(tutorialEnded)
		 forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - TutorialViewController delegate calls

- (CGRect)getBottomToolbarFrame {
	CGRect frame = CGRectZero;

	id<TutorialViewControllerDelegate> strongDelegate = self.webViewController;

	if ([strongDelegate respondsToSelector:@selector(getBottomToolbarFrame)]) {
		frame = [strongDelegate getBottomToolbarFrame];
	}

	return frame;
}

- (CGRect)getConnectionIndicatorFrame {
	CGRect frame = CGRectZero;

	id<TutorialViewControllerDelegate> strongDelegate = self.webViewController;

	if ([strongDelegate respondsToSelector:@selector(getConnectionIndicatorFrame)]) {
		frame = [strongDelegate getConnectionIndicatorFrame];
	}

	return frame;
}

- (CGRect)getCurrentSpotlightFrame:(NSUInteger)step {
	CGRect frame = CGRectNull;

	id<TutorialViewControllerDelegate> strongDelegate = self.webViewController;

	if ([strongDelegate respondsToSelector:@selector(getCurrentSpotlightFrame:)]) {
		frame = [strongDelegate getCurrentSpotlightFrame:step];
	}

	return frame;
}

- (CGRect)getSkipButtonFrame {
	CGRect frame = CGRectZero;

	id<TutorialViewControllerDelegate> strongDelegate = self.webViewController;

	if ([strongDelegate respondsToSelector:@selector(getSkipButtonFrame)]) {
		frame = [strongDelegate getSkipButtonFrame];
	}

	return frame;
}

- (void)tutorialEnded {
	id<TutorialViewControllerDelegate> strongDelegate = self.webViewController;

	if ([strongDelegate respondsToSelector:@selector(tutorialEnded)]) {
		[strongDelegate tutorialEnded];
	}
}

- (void)onboardingEnded {
	// Move from onboarding to tutorial
	[self moveToNextPage];
}

@end
