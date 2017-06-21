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

#import "OnboardingLanguageViewController.h"
#import "LanguageSelectionViewController.h"
#import "MarqueeLabel.h"

#define kDefaultLanguageCode @""
#define kGlobeImageName @"language"
#define kRightChevronImageName @"right-chevron"
#define kLanguageBoxFont @"SanFranciscoDisplay-Regular"

#define knextButtonHeight 40.0f

@interface PortraitNavigationController : UINavigationController
@end

@implementation PortraitNavigationController : UINavigationController

// Force portrait orientation during onboarding
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown);
}

@end

// First view in the app on first run (onboarding)
// (i.e. [[NSUserDefaults standardUserDefaults] boolForKey:kHasBeenOnboardedKey] == NO).
// Allow user to choose their desired language before continuing.
@implementation OnboardingLanguageViewController {
	UIButton *nextButton;

	UIImageView *arrow;
	UIImageView *globe;

	MarqueeLabel *availableLanguages;

	UIView *languageBox;

	UILabel *currentLanguage;
	UILabel *languageBoxHeader;

	BOOL isRTL;
}

@synthesize index = _index;
@synthesize delegate = _delegate;

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	[self.view layoutIfNeeded]; // ensure views have been laid out

	nextButton.layer.cornerRadius = nextButton.frame.size.height / 2;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	[self.view setBackgroundColor:[UIColor whiteColor]];

	[self setupLanguageBox];
	[self setupLanguageBoxHeader];
	[self setupLanguageBoxSubviews];
	[self setupnextButton];

	[languageBox addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
																			  action:@selector(handleLanguageBoxClick)]];
}

- (void)setupLanguageBox {
	// Setup language box (subviews: arrow, availableLanguages and currentLanguage)
	languageBox = [[UIView alloc] init];
	languageBox.translatesAutoresizingMaskIntoConstraints = NO;
	languageBox.layer.borderColor = [UIColor colorWithRed:0.84 green:0.84 blue:0.84 alpha:1.0].CGColor;
	languageBox.layer.borderWidth = 1.5f;

	[self.view addSubview:languageBox];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:languageBox
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:languageBox
														  attribute:NSLayoutAttributeBottom
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeBottom
														 multiplier:.85f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:languageBox
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:.86f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:languageBox
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeHeight
														 multiplier:.085f
														   constant:0]];
}

- (void)setupLanguageBoxHeader {
	// Setup globe (left or right of language box header depending on isRTL)
	globe = [[UIImageView alloc] initWithImage:[UIImage imageNamed:kGlobeImageName]];
	globe.translatesAutoresizingMaskIntoConstraints = NO;
	globe.contentMode = UIViewContentModeScaleAspectFit;
	[self.view addSubview:globe];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:globe
														  attribute:NSLayoutAttributeBottom
														  relatedBy:NSLayoutRelationEqual
															 toItem:languageBox
														  attribute:NSLayoutAttributeTop
														 multiplier:1.f
														   constant:-5]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:globe
														  attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
														  relatedBy:NSLayoutRelationEqual
															 toItem:languageBox
														  attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
														 multiplier:1.f
														   constant:0]];

	// Setup language box header text
	languageBoxHeader = [[UILabel alloc] init];
	languageBoxHeader.adjustsFontSizeToFitWidth = YES;
	languageBoxHeader.text = NSLocalizedString(@"Language", @"Title above language box which displays the current app language and all available languages that the app is localized for");
	languageBoxHeader.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
	languageBoxHeader.font = [UIFont fontWithName:kLanguageBoxFont size:16.0f];
	languageBoxHeader.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:languageBoxHeader];

	CGFloat headerSpacing = isRTL ? -5 : 5; // Header to closest languageBox side spacing

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:languageBoxHeader
														  attribute:NSLayoutAttributeCenterY
														  relatedBy:NSLayoutRelationEqual
															 toItem:globe
														  attribute:NSLayoutAttributeCenterY
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:languageBoxHeader
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:languageBox
														  attribute:NSLayoutAttributeWidth
														 multiplier:1.f
																	constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:languageBoxHeader
														  attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
														  relatedBy:NSLayoutRelationEqual
															 toItem:globe
														  attribute:isRTL ? NSLayoutAttributeLeft : NSLayoutAttributeRight
														 multiplier:1.f
														   constant:headerSpacing]];
}

- (void)setupLanguageBoxSubviews {
	// Current language setup
	currentLanguage = [[UILabel alloc] init];
	currentLanguage.translatesAutoresizingMaskIntoConstraints = NO;
	currentLanguage.font = [UIFont fontWithName:kLanguageBoxFont size:16.0f];
	[languageBox addSubview:currentLanguage];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:currentLanguage
														  attribute:NSLayoutAttributeCenterY
														  relatedBy:NSLayoutRelationEqual
															 toItem:languageBox
														  attribute:NSLayoutAttributeCenterY
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:currentLanguage
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:languageBox
														  attribute:NSLayoutAttributeHeight
														 multiplier:.9f
														   constant:0]];

	[currentLanguage setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
	[currentLanguage setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

	// Available languages setup
	availableLanguages = [[MarqueeLabel alloc] init];
	availableLanguages.translatesAutoresizingMaskIntoConstraints = NO;
	availableLanguages.font = [UIFont fontWithName:kLanguageBoxFont size:16.0f];
	availableLanguages.textColor = [UIColor colorWithRed:0.90 green:0.90 blue:0.90 alpha:1.0];
	availableLanguages.fadeLength = 10.0f;
	availableLanguages.rate = 40.0f;
	[languageBox addSubview:availableLanguages];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:availableLanguages
														  attribute:NSLayoutAttributeCenterY
														  relatedBy:NSLayoutRelationEqual
															 toItem:currentLanguage
														  attribute:NSLayoutAttributeCenterY
														 multiplier:1.f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:availableLanguages
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:currentLanguage
														  attribute:NSLayoutAttributeHeight
														 multiplier:1.f
														   constant:0]];

	// Right arrow view
	arrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:kRightChevronImageName]];
	arrow.translatesAutoresizingMaskIntoConstraints = NO;
	arrow.contentMode = UIViewContentModeScaleAspectFit;
	if (isRTL) {
		arrow.transform = CGAffineTransformMakeRotation(M_PI); // Rotate pi radians (180 degrees)
	}

	[languageBox addSubview:arrow];

	// Language box subview constraints
	NSDictionary *viewsDictionary = @{
									  @"arrow": arrow,
									  @"availableLanguages": availableLanguages,
									  @"currentLanguage": currentLanguage,
									  @"languageBox": languageBox
									  };
	NSDictionary *metrics = @{
							  @"arrowWidth": [NSNumber numberWithFloat:[UIImage imageNamed:@"arrow_right"].size.width]
							  };

	[languageBox addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[currentLanguage]-1-[availableLanguages]-3-[arrow(==arrowWidth)]-10-|" options:NSLayoutFormatAlignAllCenterY metrics:metrics views:viewsDictionary]];

	// Setup current language and available languages text
	LanguageSettings *languageSettings = [[LanguageSettings alloc] init];
	NSArray<NSString*> *languageNames = [languageSettings getLanguageNames];
	NSArray<NSString*> *languageCodes = [languageSettings getLanguageCodes];

	// Get current language
	NSString *currentLanguageCode = [[NSUserDefaults standardUserDefaults] stringForKey:appLanguage];
	NSString *currentLanguageText;

	if ([currentLanguageCode isEqualToString:kDefaultLanguageCode]) { // Default language is set
		currentLanguageCode = [[NSLocale preferredLanguages] objectAtIndex:0];
		currentLanguageText = [[NSLocale currentLocale] displayNameForKey:NSLocaleLanguageCode value:currentLanguageCode];
	} else {
		NSUInteger index = [languageCodes indexOfObject:currentLanguageCode];
		if (index == NSNotFound) {
			currentLanguageText = @"";
		} else {
			// There must be a 1 to 1 mapping between language codes and language names arrays (LanguageSettings will raise an exception if not)
			currentLanguageText = [languageNames objectAtIndex:index];
		}
	}
	currentLanguage.text = [currentLanguageText stringByAppendingString:@" |"];

	// Get available languages and construct string for display
	availableLanguages.text = @"\u202D"; // left-to-right override, unicode 202D
	for (int i = 0; i < languageNames.count; i++) {
		NSString *languageName = [languageNames objectAtIndex:i];

		// Skip default and current language strings
		if (i == kDefaultLanguageRow || [languageName isEqualToString:currentLanguageText]) {
			continue;
		}

		NSString *delimiter = i != languageNames.count - 1 ? @", " : @"";
		availableLanguages.text = [[availableLanguages.text stringByAppendingString:languageName] stringByAppendingString:delimiter];
	}
}

- (void)setupnextButton {
	/* Setup lets go button */
	nextButton = [[UIButton alloc] init];
	nextButton.backgroundColor = [UIColor colorWithRed:0.83 green:0.25 blue:0.16 alpha:1.0];
	nextButton.hidden = false;
	[nextButton setTitle:NSLocalizedString(@"Next", @"Text of the button that the user presses to proceed to the next screen of onboarding") forState:UIControlStateNormal];
	nextButton.layer.cornerRadius = knextButtonHeight / 2;
	nextButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16.0f];
	nextButton.titleLabel.adjustsFontSizeToFitWidth = YES;

	[nextButton addTarget:self
					 action:@selector(moveToNextView)
		   forControlEvents:UIControlEventTouchUpInside];

	nextButton.translatesAutoresizingMaskIntoConstraints = NO;

	/* add nextButton to view */
	[self.view addSubview:nextButton];


	/* nextButton.width = 0.55 * self.view.width */
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:nextButton
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:.55f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:nextButton
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeHeight
														 multiplier:.076f
														   constant:0]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:nextButton
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f
														   constant:0]];

	NSDictionary *viewsDictionary = @{
									 @"nextButton": nextButton
									 };

	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[nextButton]|" options:NSLayoutFormatAlignAllCenterX metrics:0 views:viewsDictionary]];
}

- (void)handleLanguageBoxClick {
	LanguageSelectionViewController *targetViewController = [[LanguageSelectionViewController alloc] init];
	PortraitNavigationController *navController = [[PortraitNavigationController alloc] initWithRootViewController:targetViewController];
	[self presentViewController:navController animated:YES completion:nil];
}

- (void)languageSelectionEnded {
	OnboardingViewController *onboarding = [[OnboardingViewController alloc] init];
	[self presentViewController:onboarding animated:NO completion:nil];
}

- (void)moveToNextView {
	id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(moveToViewAtIndex:)]) {
		[strongDelegate moveToViewAtIndex:self.index+1];
	}
	[self dismissViewControllerAnimated:NO completion:nil];
}

@end
