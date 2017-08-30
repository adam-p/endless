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

#import "OnboardingInfoViewController.h"

#define k5sScreenWidth 320.f

// 2nd to Nth onboarding screen(s) after the language
// selection screen (OnboardingLanguageViewController).
// These views display onboarding text describing
// Psiphon Browser to the user.
// Note: we should have the full screen to work with
// because OnboardingViewController should not be presenting
// any other views.
@implementation OnboardingInfoViewController {
	UIView *contentView;
	UIImageView *graphic;
	UILabel *titleView;
	UILabel *textView;
	UIButton *letsGoButton;

	NSLayoutConstraint *graphicYOffsetConstraint;
}

@synthesize index = _index;
@synthesize delegate = delegate;

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	[self.view layoutIfNeeded]; // ensure views have been laid out

	letsGoButton.layer.cornerRadius = letsGoButton.frame.size.height / 2;

	CGFloat titleOffset = 0;

	id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(getTitleOffset)]) {
		titleOffset = [strongDelegate getTitleOffset];
	}

	[graphicYOffsetConstraint setConstant:titleOffset + 40.f];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	/* setup graphic view */
	graphic = [[UIImageView alloc] init];
	UIImage *graphicImage = [UIImage imageNamed:[NSString stringWithFormat:@"onboarding-%ld", (long)self.index]];
	if (graphicImage != nil) {
		graphic.image = graphicImage;
	}
	graphic.contentMode = UIViewContentModeScaleAspectFit;
	[graphic.layer setMinificationFilter:kCAFilterTrilinear]; // Prevent aliasing

	/* Setup title view */
	titleView = [[UILabel alloc] init];
	titleView.numberOfLines = 0;
	titleView.adjustsFontSizeToFitWidth = YES;
	titleView.userInteractionEnabled = NO;
	titleView.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:(self.view.frame.size.width - k5sScreenWidth) * 0.0134f + 19.0f];
	titleView.textColor = [UIColor colorWithRed:0.27 green:0.27 blue:0.28 alpha:1.0];
	titleView.textAlignment = NSTextAlignmentCenter;

	/* Setup text view */
	textView = [[UILabel alloc] init];
	textView.numberOfLines = 0;
	textView.adjustsFontSizeToFitWidth = YES;
	textView.userInteractionEnabled = NO;
	textView.font = [UIFont fontWithName:@"HelveticaNeue" size:(self.view.frame.size.width - k5sScreenWidth) * 0.0112f + 18.0f];
	textView.textColor = [UIColor colorWithRed:0.56 green:0.57 blue:0.58 alpha:1.0];
	textView.textAlignment = NSTextAlignmentCenter;

	/* Setup lets go button */
	letsGoButton = [[UIButton alloc] init];
	letsGoButton.backgroundColor = [UIColor colorWithRed:0.83 green:0.25 blue:0.16 alpha:1.0];
	letsGoButton.hidden = false;
	[letsGoButton setTitle:NSLocalizedStringWithDefaultValue(@"START_TUTORIAL_BUTTON", nil, [NSBundle mainBundle], @"Start Tutorial", @"Text of button that user presses to complete onboarding and start tutorial") forState:UIControlStateNormal];
	letsGoButton.titleLabel.textAlignment = NSTextAlignmentCenter;
	letsGoButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:(self.view.frame.size.width - k5sScreenWidth) * 0.0112f + 16.0f];
	letsGoButton.titleLabel.adjustsFontSizeToFitWidth = YES;

	[letsGoButton addTarget:self
					 action:@selector(onboardingEnded)
		   forControlEvents:UIControlEventTouchUpInside];

	/* Setup contentView and its subviews */
	[self.view addSubview:graphic];
	contentView = [[UIView alloc] init];
	[contentView addSubview:titleView];
	[contentView addSubview:textView];
	[self.view addSubview:contentView];

	/* Setup autolayout */
	graphic.translatesAutoresizingMaskIntoConstraints = NO;
	contentView.translatesAutoresizingMaskIntoConstraints = NO;
	titleView.translatesAutoresizingMaskIntoConstraints = NO;
	textView.translatesAutoresizingMaskIntoConstraints = NO;
	letsGoButton.translatesAutoresizingMaskIntoConstraints = NO;

	NSDictionary *viewsDictionary = @{
									  @"graphic": graphic,
									  @"contentView": contentView,
									  @"titleView": titleView,
									  @"textView": textView,
									  @"letsGoButton": letsGoButton
									  };

	/* graphic's constraints */

	graphicYOffsetConstraint = [NSLayoutConstraint constraintWithItem:graphic
															attribute:NSLayoutAttributeTop
															relatedBy:NSLayoutRelationEqual
															   toItem:self.view
															attribute:NSLayoutAttributeTop
														   multiplier:1.f
															 constant:0];
	[self.view addConstraint:graphicYOffsetConstraint];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:graphic
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeHeight
														 multiplier:.55f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:graphic
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:.8f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:graphic
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f
														   constant:0]];

	/* contentView's constraints */
	CGFloat contentViewWidthRatio = 0.7f;
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:contentView
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:contentViewWidthRatio
														   constant:0]];

	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[graphic][contentView]|" options:0 metrics:nil views:viewsDictionary]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:contentView
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f constant:0.f]];

	/* titleView's constraints */
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															attribute:NSLayoutAttributeWidth
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeWidth
														   multiplier:1.f
															 constant:0]];

	titleView.preferredMaxLayoutWidth = contentViewWidthRatio * self.view.frame.size.width;
	[titleView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[titleView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															attribute:NSLayoutAttributeHeight
															relatedBy:NSLayoutRelationLessThanOrEqual
															   toItem:contentView
															attribute:NSLayoutAttributeHeight
														   multiplier:0.3f
															 constant:0]];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															attribute:NSLayoutAttributeCenterX
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeCenterX
														   multiplier:1.f constant:0.f]];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															attribute:NSLayoutAttributeCenterY
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeCenterY
														   multiplier:.5f constant:0.f]];

	/* textView's constraints */
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:textView
															attribute:NSLayoutAttributeWidth
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeWidth
														   multiplier:1.f
															 constant:0]];

	textView.preferredMaxLayoutWidth = 0.9 * contentViewWidthRatio * self.view.frame.size.width;
	[textView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[textView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:textView
															attribute:NSLayoutAttributeCenterX
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeCenterX
														   multiplier:1.f constant:0.f]];


	/* add vertical constraints for contentView's subviews */
	[contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[titleView]-[textView]-(>=0)-|" options:0 metrics:nil views:viewsDictionary]];

	/* Set page specific content */
	switch (self.index) {
		case PsiphonOnboardingPage1Index: {
			titleView.text = NSLocalizedStringWithDefaultValue(@"ONBOARDING_ACCESS_TITLE", nil, [NSBundle mainBundle], @"Access the Web", @"Title text on one of the on-boarding screens");
			textView.text = NSLocalizedStringWithDefaultValue(@"ONBOARDING_ACCESS_TEXT", nil, [NSBundle mainBundle], @"The Internet at your fingertips", @"Body text on one of the on-boarding screens. It is indicating to the user that Psiphon Browser allows them to access the Internet (without censorship).");
			break;
		}
		case PsiphonOnboardingPage2Index: {
			titleView.text = NSLocalizedStringWithDefaultValue(@"ONBOARDING_APPS_TITLE", nil, [NSBundle mainBundle], @"Your Apps in Your Browser", @"Title text on one of the on-boarding screens. The intention of this screen is to let the user know that their sites and services -- Facebook, Twitter, etc. -- can be accessed within Psiphon Browser via web pages.");
			textView.text =  NSLocalizedStringWithDefaultValue(@"ONBOARDING_APPS_TEXT", nil, [NSBundle mainBundle], @"Your favorite apps have a web interface that works great in Psiphon Browser", @"Body text on one of the on-boarding screens. The intention of this screen is to let the user know that their sites and services -- Facebook, Twitter, etc. -- can be accessed within Psiphon Browser via web pages.");
			break;
		}
		case PsiphonOnboardingPage3Index: {
			titleView.text = NSLocalizedStringWithDefaultValue(@"ONBOARDING_BROWSING_TITLE", nil, [NSBundle mainBundle], @"Happy Browsing!", @"Title text on one of the on-boarding screens. This is the final page of the on-boarding and is sending the user off on their journey across the Internet.");
			textView.text = @"";

			/* add letsGoButton to view */
			[contentView addSubview:letsGoButton];

			/* letsGoButton.width = 0.55 * self.view.width */
			CGFloat letsGoButtonWidth = self.view.frame.size.width * 0.55f;
			letsGoButtonWidth = letsGoButtonWidth > 300 ? 300 : letsGoButtonWidth;
			[self.view addConstraint:[NSLayoutConstraint constraintWithItem:letsGoButton
																  attribute:NSLayoutAttributeWidth
																  relatedBy:NSLayoutRelationEqual
																	 toItem:nil
																  attribute:NSLayoutAttributeNotAnAttribute
																 multiplier:1.f
																   constant:letsGoButtonWidth]];

			[self.view addConstraint:[NSLayoutConstraint constraintWithItem:letsGoButton
																  attribute:NSLayoutAttributeHeight
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.view
																  attribute:NSLayoutAttributeHeight
																 multiplier:.076f
																   constant:0]];

			[contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[textView]-(>=0)-[letsGoButton]|" options:NSLayoutFormatAlignAllCenterX metrics:nil views:viewsDictionary]];

			break;
		}
		default:
			[self onboardingEnded];
			break;
	}
}

- (void)onboardingEnded {
	id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(onboardingEnded)]) {
		[strongDelegate onboardingEnded];
	}
}

@end
