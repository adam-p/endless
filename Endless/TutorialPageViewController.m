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

#import <math.h>
#import "AdjustableLabel.h"
#import "TutorialPageViewController.h"

@implementation TutorialPageViewController {
	UIImageView *arrowView;
	UILabel *titleView;
	AdjustableLabel *textView;
	UIButton *letsGo;

	CAShapeLayer *fillLayer;

	NSLayoutConstraint *arrowViewTop;
	NSLayoutConstraint *arrowViewLeft;

	BOOL isRTL;
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	[self.view layoutIfNeeded];

	if (self.index == PsiphonTutorialPage1Index || self.index == PsiphonTutorialPage2Index) {
		[self layoutArrowForPage];
		[self animateArrow];
	} else if (self.index == PsiphonTutorialPage3Index) {
		letsGo.layer.cornerRadius = letsGo.frame.size.height / 2;
	}

	[self setSpotlightFrame:[self getCurrentSpotlightFrame] withView:self.view];
}

- (void)layoutArrowForPage {
	if (self.index == PsiphonTutorialPage1Index) {
		[self pointArrowAtConnectionIndicator];
	} else if (self.index == PsiphonTutorialPage2Index) {
		[self pointArrowViewAtBottomToolbar];
	}
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	arrowView.alpha = 0;
	titleView.alpha = 0;
	textView.alpha = 0;

	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
	 {
		 [self setSpotlightFrame:CGRectNull withView:self.view];
	 } completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
	 {
		 [self layoutArrowForPage];

		 [UIView animateWithDuration:0.2 animations:^{
			 [self setSpotlightFrame:[self getCurrentSpotlightFrame] withView:self.view];

			 arrowView.alpha = 1;
			 titleView.alpha = 1;
			 textView.alpha = 1;
		 }];
	 }];

	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	if (self.index == PsiphonTutorialOnboardingIndex) {
		OnboardingViewController *onboarding = [[OnboardingViewController alloc] init];
		onboarding.delegate = self;
		[self addChildViewController:onboarding];
		[self.view addSubview:onboarding.view];
		[onboarding didMoveToParentViewController:self];
	} else {

		/* Setup and add views */
		[self setupTransparentBackground];
		[self setupTitleView];
		[self setupTextView];
		[self setupArrowView];

		[self.view.layer addSublayer:fillLayer];
		[self.view addSubview:titleView];
		[self.view addSubview:textView];
		[self.view addSubview:arrowView];

		[self setSpotlightFrame:[self getCurrentSpotlightFrame] withView:self.view];

		/* Setup autolayout */
		// titleView
		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															  attribute:NSLayoutAttributeWidth
															  relatedBy:NSLayoutRelationEqual
																 toItem:self.view
															  attribute:NSLayoutAttributeWidth
															 multiplier:.68f
															   constant:0.f]];

		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															  attribute:NSLayoutAttributeCenterX
															  relatedBy:NSLayoutRelationEqual
																 toItem:self.view
															  attribute:NSLayoutAttributeCenterX
															 multiplier:1.f
															   constant:0.f]];

		// textView
		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:textView
															  attribute:NSLayoutAttributeWidth
															  relatedBy:NSLayoutRelationEqual
																 toItem:self.view
															  attribute:NSLayoutAttributeWidth
															 multiplier:.68f
															   constant:0.f]];

		NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:textView
																   attribute:NSLayoutAttributeCenterY
																   relatedBy:NSLayoutRelationEqual
																	  toItem:self.view
																   attribute:NSLayoutAttributeCenterY
																  multiplier:1.f
																	constant:20.f];
		centerY.priority = UILayoutPriorityDefaultLow;
		[self.view addConstraint:centerY];
	}

	if (self.index == PsiphonTutorialPage1Index) {
		NSDictionary *viewsDictionary = @{
										  @"titleView": titleView,
										  @"textView": textView,
										  @"arrowView": arrowView
										  };

		[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[titleView]-(==24)-[textView]" options:NSLayoutFormatAlignAllCenterX metrics:nil views:viewsDictionary]];
	} else if (self.index == PsiphonTutorialPage2Index) {
		NSDictionary *viewsDictionary = @{
										  @"titleView": titleView,
										  @"textView": textView,
										  @"arrowView": arrowView
										  };

		[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[titleView]-(==24)-[textView]-(>=0)-[arrowView]" options:NSLayoutFormatAlignAllCenterX metrics:nil views:viewsDictionary]];
	} else if (self.index == PsiphonTutorialPage3Index) {
		// Setup lets go button
		[self setupLetsGo];
		[self.view addSubview:letsGo];

		CGFloat buttonWidth = (self.view.frame.size.width) / 3;
		buttonWidth = buttonWidth > 120 ? buttonWidth : 120;

		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:letsGo
															  attribute:NSLayoutAttributeWidth
															  relatedBy:NSLayoutRelationEqual
																 toItem:nil
															  attribute:NSLayoutAttributeNotAnAttribute
															 multiplier:1.f
															   constant:buttonWidth]];

		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:letsGo
															  attribute:NSLayoutAttributeHeight
															  relatedBy:NSLayoutRelationEqual
																 toItem:nil
															  attribute:NSLayoutAttributeNotAnAttribute
															 multiplier:1.f
															   constant:40.f]];

		NSDictionary *viewsDictionary = @{
										  @"titleView": titleView,
										  @"textView": textView,
										  @"letsGo": letsGo
										  };

		[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[titleView]-(==24)-[textView]-(==24)-[letsGo]" options:NSLayoutFormatAlignAllCenterX metrics:nil views:viewsDictionary]];
	}
}

#pragma mark - TutorialPageViewController helper functions

- (void)setupTransparentBackground {
	fillLayer = [CAShapeLayer layer];
	fillLayer.fillRule = kCAFillRuleEvenOdd;
	fillLayer.fillColor = [UIColor blackColor].CGColor;
	fillLayer.opacity = 0.85;
}

- (void)animateArrow {
	[UIView animateWithDuration:0.6f
						  delay:0.0f
						options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
						 [arrowView setTransform:CGAffineTransformMakeTranslation(0.0, 20.0)];
					 }
					 completion:nil];
}

- (void)setupArrowView {
	if (self.index == PsiphonTutorialPage1Index) {
		UIImage *arrow = [UIImage imageNamed:@"arrow"];
		arrowView = [[UIImageView alloc] initWithImage:arrow];
	} else if (self.index == PsiphonTutorialPage2Index) {
		UIImage *arrow = [UIImage imageNamed:@"arrow-down"];
		arrowView = [[UIImageView alloc] initWithImage:arrow];
	} else {
		return;
	}
	arrowView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)setupTitleView {
	titleView = [[UILabel alloc] init];
	titleView.numberOfLines = 0;
	titleView.textColor = [UIColor whiteColor];
	titleView.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:19.0f];
	titleView.backgroundColor = [UIColor clearColor];
	titleView.textAlignment = NSTextAlignmentCenter;
	titleView.adjustsFontSizeToFitWidth = YES;
	titleView.text = [self getTitleTextForPage];

	titleView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)setupTextView {
	textView = [[AdjustableLabel alloc] initWithDesiredFontSize:16.0f];

	NSAttributedString *bodyText = [self getBodyTextForPage];
	NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:bodyText];
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	[style setLineSpacing:5];
	[attributedString addAttribute:NSParagraphStyleAttributeName
							 value:style
							 range:NSMakeRange(0, [bodyText length])];
	textView.attributedText = attributedString;
	textView.textAlignment = NSTextAlignmentCenter;
	textView.textColor = [UIColor whiteColor];
	textView.font = [UIFont fontWithName:@"HelveticaNeue" size:16.0f];
	textView.backgroundColor = [UIColor clearColor];
	textView.adjustsFontSizeToFitFrame = YES;

	textView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)setupLetsGo {
	letsGo = [[UIButton alloc] init];

	[letsGo setBackgroundColor:[UIColor colorWithRed:0.83 green:0.25 blue:0.16 alpha:1.0]];
	[letsGo setTitle:NSLocalizedString(@"Let's Go!", @"") forState:UIControlStateNormal];

	[letsGo.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.0f]];
	[letsGo.titleLabel setAdjustsFontSizeToFitWidth:YES];

	[letsGo addTarget:self
			   action:@selector(tutorialEnded)
	 forControlEvents:UIControlEventTouchUpInside];
	letsGo.translatesAutoresizingMaskIntoConstraints = NO;
}

- (NSString*)getTitleTextForPage
{
	NSArray<NSString*>* titleText = @[
									  @"",
									  NSLocalizedString(@"Status Indicator", @""),
									  NSLocalizedString(@"Settings", @""),
									  NSLocalizedString(@"You're all set!", @"")
									  ];

	if (self.index < titleText.count) {
		return [titleText objectAtIndex:self.index];
	}
	return @"";
}

- (NSAttributedString*)getBodyTextForPage
{
	NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"This is where you can find information about the status of your connection", @"")];
	NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
	textAttachment.image = [UIImage imageNamed:@"small-status-connected"];
	NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
	[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];
	[attributedString appendAttributedString:attrStringWithImage];
	[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
	[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"The green checkmark indicates everything is working beautifully and you're good to go!", @"")]];

	NSArray<NSAttributedString*>* bodyText = @[
											   [[NSAttributedString alloc] initWithString:@""],
											   attributedString,
											   [[NSAttributedString alloc] initWithString:NSLocalizedString(@"This is where you can access Browser and Proxy Settings, find Help, change the VPN server country, and more!", @"")],
											   [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Happy browsing!\nExplore beyond your borders.", @"")]
											   ];

	if (self.index < bodyText.count) {
		return [bodyText objectAtIndex:self.index];
	}
	return [[NSAttributedString alloc] initWithString:@""];
}

- (void)pointArrowViewAtBottomToolbar {
	CGRect frame = [self getBottomToolbarFrame];

	if (arrowViewLeft != nil) {
		[self.view removeConstraint:arrowViewLeft];
	}
	if (arrowViewTop != nil) {
		[self.view removeConstraint:arrowViewTop];
	}

	arrowViewTop = [NSLayoutConstraint constraintWithItem:arrowView
												attribute:NSLayoutAttributeTop
												relatedBy:NSLayoutRelationEqual
												   toItem:self.view
												attribute:NSLayoutAttributeTop
											   multiplier:1.f
												 constant:frame.origin.y - 85.f];
	[self.view addConstraint:arrowViewTop];
}

- (void)pointArrowAtConnectionIndicator {
	CGRect frame = [self getConnectionIndicatorFrame];

	if (arrowViewLeft != nil) {
		[self.view removeConstraint:arrowViewLeft];
	}

	if (arrowViewTop != nil) {
		[self.view removeConstraint:arrowViewTop];
	}

	arrowViewTop = [NSLayoutConstraint constraintWithItem:arrowView
												attribute:NSLayoutAttributeCenterY
												relatedBy:NSLayoutRelationEqual
												   toItem:self.view
												attribute:NSLayoutAttributeTop
											   multiplier:1.f
												 constant: CGRectGetMidY(frame) + 65.f];
	[self.view addConstraint:arrowViewTop];

	arrowViewLeft = [NSLayoutConstraint constraintWithItem:arrowView
												 attribute:NSLayoutAttributeCenterX
												 relatedBy:NSLayoutRelationEqual
													toItem:self.view
												 attribute:NSLayoutAttributeLeft
												multiplier:1.f
												  constant:CGRectGetMidX(frame)];
	[self.view addConstraint:arrowViewLeft];
}

- (void)setSpotlightFrame:(CGRect)frame withView:(UIView*)view {
	BOOL isOnboarding = [[NSUserDefaults standardUserDefaults] boolForKey:kHasBeenOnboardedKey];
	CGFloat spotlightRadius = frame.size.width / 2;

	UIBezierPath *path;
	if (self.index == PsiphonTutorialPage1Index && isOnboarding) {
		// Prevent swiping back exposing webViewController.
		// Only needed if not onboarding, otherwise user swipes
		// back to onboarding.
		path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(isRTL ? 0 : -view.bounds.size.width, 0, view.bounds.size.width*2, view.bounds.size.height) cornerRadius:0];
	} else {
		path = [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:0];
	}

	if (!CGRectEqualToRect(frame, CGRectNull)) {
		if (self.index == PsiphonTutorialPage1Index && !isOnboarding) {
			// Ensure that spotlight doesn't bleed over into the next page view controller (onboarding)
			// Only needed if onboarding.
			if (CGRectGetMidX(frame) >= spotlightRadius) {
				/* spotlight is fully contained within page view controller's frame */
				UIBezierPath *circlePath = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:spotlightRadius];
				[path appendPath:circlePath];
			} else {
				/*
				 * If spotlight will bleed into adjacent page view controller we will calculate
				 * angles of intersect to the (isRTL ? right : left) side and draw a circle into
				 * the view starting and ending at those points. All calculations are in radians.
				 *
				 */
				CGFloat alpha = asinf(CGRectGetMidX(frame) / spotlightRadius);
				CGFloat startAngle = 3 * M_PI_2 - alpha;
				CGFloat endAngle = M_PI_2 + alpha;

				UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame)) radius:spotlightRadius startAngle:startAngle endAngle:endAngle clockwise:YES];
				[path appendPath:circlePath];
			}
		} else {
			UIBezierPath *circlePath = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:spotlightRadius];
			[path appendPath:circlePath];
		}
	}

	// set background
	fillLayer.path = path.CGPath;
}

#pragma mark - TutorialPageViewController delegate calls

- (CGRect)getBottomToolbarFrame {
	CGRect frame = CGRectZero;

	id<TutorialPageViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(getBottomToolbarFrame)]) {
		frame = [strongDelegate getBottomToolbarFrame];
	}

	return frame;
}

- (CGRect)getConnectionIndicatorFrame {
	CGRect frame = CGRectZero;

	id<TutorialPageViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(getConnectionIndicatorFrame)]) {
		frame = [strongDelegate getConnectionIndicatorFrame];
	}

	return frame;
}

- (CGRect)getCurrentSpotlightFrame {
	CGRect frame = CGRectNull;

	id<TutorialPageViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(getCurrentSpotlightFrame:)]) {
		frame = [strongDelegate getCurrentSpotlightFrame:self.index];
	}

	return frame;
}

- (void)tutorialEnded {
	id<TutorialPageViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(tutorialEnded)]) {
		[strongDelegate tutorialEnded];
	}
}

#pragma mark - OnboardingViewController delegate methods

- (void)onboardingEnded {
	id<TutorialPageViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(onboardingEnded)]) {
		[strongDelegate onboardingEnded];
	}
}

@end
