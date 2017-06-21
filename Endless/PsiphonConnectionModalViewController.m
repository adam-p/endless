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

#import "PsiphonConnectionModalViewController.h"
#import "RegionAdapter.h"
#import "RegionSelectionViewController.h"
#import "ICDMaterialActivityIndicatorView.h"

@implementation PsiphonConnectionModalViewController {
	ConnectionState _connectionState;
	NSString *_connectionRegion;
}

- (id) initWithState:(ConnectionState)state {
	self = [super initWithNibName:nil bundle:nil];
	if(self) {
		self.dismissOnConnected = NO;
		[self setupViewsForState: state];
	}
	return self;
}

-(void) viewWillAppear:(BOOL)animated {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(psiphonConnectionStateNotified:)
												 name:kPsiphonConnectionStateNotification object:nil];
	[super viewWillAppear:animated];
}

-(void) viewWillDisappear:(BOOL)animated {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kPsiphonConnectionStateNotification object:nil];
	[super viewWillDisappear:animated];
}

- (void) psiphonConnectionStateNotified:(NSNotification *)notification
{
	ConnectionState state = [[notification.userInfo objectForKey:kPsiphonConnectionState] unsignedIntegerValue];

	Region *selectedRegion = [[RegionAdapter sharedInstance] getSelectedRegion];
	NSString *region = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:selectedRegion.code];

	if (state == _connectionState && [_connectionRegion isEqualToString:region]) {
		//Nothing has changed
		return;
	}

	_connectionState = state;
	_connectionRegion = region;

	[self updateViews];

	if(state == ConnectionStateConnected && self.dismissOnConnected == YES) {
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}
}

-(void) setupViewsForState:(ConnectionState)state {

	NSString *title = @"";
	NSString *message = @"";
	UIView *contentView = nil;

	if (state == ConnectionStateConnecting) {
		contentView = [[UIView alloc] initWithFrame:CGRectZero];

		ICDMaterialActivityIndicatorView* activityIndicator = [[ICDMaterialActivityIndicatorView alloc] initWithActivityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleLarge];
		[activityIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
		[activityIndicator startAnimating];
		[contentView addSubview:activityIndicator];

		UILabel *serverRegionTextLabel = [[UILabel alloc] init];
		[serverRegionTextLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		serverRegionTextLabel.textAlignment = NSTextAlignmentCenter;
		serverRegionTextLabel.text = NSLocalizedString(@"Server region:", @"Title that is showing above selected server region");
		[contentView addSubview:serverRegionTextLabel];

		UILabel *connectionRegionLabel = [[UILabel alloc] init];
		[connectionRegionLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		connectionRegionLabel.textAlignment = NSTextAlignmentCenter;
		UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(connectionRegionLabelTapped)];
		tapGestureRecognizer.numberOfTapsRequired = 1;
		[connectionRegionLabel addGestureRecognizer:tapGestureRecognizer];
		connectionRegionLabel.userInteractionEnabled = YES;
		connectionRegionLabel.adjustsFontSizeToFitWidth = YES;

		[contentView addSubview:connectionRegionLabel];

		Region *selectedRegion = [[RegionAdapter sharedInstance] getSelectedRegion];
		NSString *regionTitle = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:selectedRegion.code];

		NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
		textAttachment.image = [UIImage imageNamed:selectedRegion.flagResourceId];
		NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
		textAttachment.bounds = CGRectMake(0, connectionRegionLabel.font.descender - 5, textAttachment.image.size.width, textAttachment.image.size.height);

		NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@""];
		[attributedString appendAttributedString:attrStringWithImage];
		[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
		[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:regionTitle]];

		connectionRegionLabel.attributedText = attributedString;

		[contentView addConstraints:@[[NSLayoutConstraint constraintWithItem:activityIndicator
																   attribute:NSLayoutAttributeTop
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeTop
																  multiplier:1.0
																	constant:10],
									  [NSLayoutConstraint constraintWithItem:activityIndicator
																   attribute:NSLayoutAttributeCenterX
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeCenterX
																  multiplier:1.0
																	constant:0],

									  [NSLayoutConstraint constraintWithItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeCenterX
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeCenterX
																  multiplier:1.0
																	constant:0],
									  [NSLayoutConstraint constraintWithItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeTop
																   relatedBy:NSLayoutRelationEqual
																	  toItem:activityIndicator
																   attribute:NSLayoutAttributeBottom
																  multiplier:1.0
																	constant:20],
									  [NSLayoutConstraint constraintWithItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeWidth
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeWidth
																  multiplier:1.0
																	constant:-10],
									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeCenterX
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeCenterX
																  multiplier:1.0
																	constant:0],
									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeTop
																   relatedBy:NSLayoutRelationEqual
																	  toItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeBottom
																  multiplier:1.0
																	constant:10],

									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeBottom
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeBottom
																  multiplier:1.0
																	constant:-10],
									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeWidth
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeWidth
																  multiplier:1.0
																	constant:-10],
									  ]];

		title = NSLocalizedString(@"Connecting...",
								  @"Connection status initial splash modal dialog title for 'Connecting...' state");
		message = nil;
	} else if (state == ConnectionStateWaitingForNetwork) {
		contentView = [[UIView alloc] initWithFrame:CGRectZero];

		ICDMaterialActivityIndicatorView* activityIndicator = [[ICDMaterialActivityIndicatorView alloc] initWithActivityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleLarge];
		[activityIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
		[activityIndicator startAnimating];
		[contentView addSubview:activityIndicator];

		[contentView addConstraints:@[[NSLayoutConstraint constraintWithItem:activityIndicator
																   attribute:NSLayoutAttributeTop
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeTop
																  multiplier:1.0
																	constant:10],
									  [NSLayoutConstraint constraintWithItem:activityIndicator
																   attribute:NSLayoutAttributeCenterX
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeCenterX
																  multiplier:1.0
																	constant:0],
									  [NSLayoutConstraint constraintWithItem:activityIndicator
																   attribute:NSLayoutAttributeBottom
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeBottom
																  multiplier:1.0
																	constant:-10],
									  ]];

		title = NSLocalizedString(@"Waiting for network...",
								  @"Connection status initial splash modal dialog title for 'Waiting for network...' state");
		message = nil;
	} else if(state == ConnectionStateConnected){
		contentView = [[UIView alloc] initWithFrame:CGRectZero];

		UILabel *serverRegionTextLabel = [[UILabel alloc] init];
		[serverRegionTextLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		serverRegionTextLabel.textAlignment = NSTextAlignmentCenter;
		serverRegionTextLabel.text = NSLocalizedString(@"Server region:", @"Title that is showing above selected server region");
		[contentView addSubview:serverRegionTextLabel];

		UILabel *connectionRegionLabel = [[UILabel alloc] init];
		[connectionRegionLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		connectionRegionLabel.textAlignment = NSTextAlignmentCenter;
		UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(connectionRegionLabelTapped)];
		tapGestureRecognizer.numberOfTapsRequired = 1;
		[connectionRegionLabel addGestureRecognizer:tapGestureRecognizer];
		connectionRegionLabel.userInteractionEnabled = YES;
		connectionRegionLabel.adjustsFontSizeToFitWidth = YES;

		[contentView addSubview:connectionRegionLabel];

		Region *selectedRegion = [[RegionAdapter sharedInstance] getSelectedRegion];
		NSString *regionTitle = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:selectedRegion.code];

		NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
		textAttachment.image = [UIImage imageNamed:selectedRegion.flagResourceId];
		NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
		textAttachment.bounds = CGRectMake(0, connectionRegionLabel.font.descender - 5, textAttachment.image.size.width, textAttachment.image.size.height);

		NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@""];
		[attributedString appendAttributedString:attrStringWithImage];
		[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
		[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:regionTitle]];

		connectionRegionLabel.attributedText = attributedString;

		[contentView addConstraints:@[[NSLayoutConstraint constraintWithItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeCenterX
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeCenterX
																  multiplier:1.0
																	constant:0],
									  [NSLayoutConstraint constraintWithItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeTop
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeTop
																  multiplier:1.0
																	constant:10],
									  [NSLayoutConstraint constraintWithItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeWidth
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeWidth
																  multiplier:1.0
																	constant:-10],
									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeCenterX
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeCenterX
																  multiplier:1.0
																	constant:0],
									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeTop
																   relatedBy:NSLayoutRelationEqual
																	  toItem:serverRegionTextLabel
																   attribute:NSLayoutAttributeBottom
																  multiplier:1.0
																	constant:10],

									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeBottom
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeBottom
																  multiplier:1.0
																	constant:-10],
									  [NSLayoutConstraint constraintWithItem:connectionRegionLabel
																   attribute:NSLayoutAttributeWidth
																   relatedBy:NSLayoutRelationEqual
																	  toItem:contentView
																   attribute:NSLayoutAttributeWidth
																  multiplier:1.0
																	constant:-10],
									  ]];

		title = NSLocalizedString(@"Connected!",
								  @"Connection status initial splash modal dialog title for 'Connected' state");
		message = nil;
	} else if(state == ConnectionStateDisconnected) {
		title = NSLocalizedString(@"Disconnected!",
								  @"Connection status initial splash modal dialog title for 'Psiphon can not start due to an internal error' state");
		message = NSLocalizedString(@"Psiphon can not start due to an internal error, please send feedback.",
									@"Connection status initial splash modal dialog message for 'Psiphon can not start due to an internal error' state");
		// TODO: display 'can't start' icon in the contentView
		contentView = [[UIView alloc] initWithFrame:CGRectZero];
	}

	self.title = title;
	self.message = message;
	self.alertViewContentView = contentView;
}

-(void) updateViews {
	//TODO: animated transition of views
	[self setupViewsForState:_connectionState];
}

-(void) connectionRegionLabelTapped {
	RegionSelectionViewController *regionSelectionViewController = [[RegionSelectionViewController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:regionSelectionViewController];
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Title of the button that dismisses region selection dialog")
																   style:UIBarButtonItemStyleDone target:self
																  action:@selector(regionSelectionDone)];
	regionSelectionViewController.navigationItem.rightBarButtonItem = doneButton;

	if ([self.delegate respondsToSelector:@selector(regionSelectionControllerWillStart)]) {
		[self.delegate regionSelectionControllerWillStart];
	}
	[self presentViewController:navController animated:YES completion:nil];
}

-(void) regionSelectionDone {
	[self dismissViewControllerAnimated:YES completion:nil];
	if ([self.delegate respondsToSelector:@selector(regionSelectionControllerDidEnd)]) {
		[self.delegate regionSelectionControllerDidEnd];
	}
}

@end

@implementation PsiphonConnectionSplashViewController {
	BOOL dismissOnViewDidAppear;
}

- (id) initWithState:(ConnectionState)state {
	self = [super initWithState:state];
	if(self) {
		self.transitionStyle = NYAlertViewControllerTransitionStyleFade;
		self.backgroundTapDismissalGestureEnabled = NO;
		self.swipeDismissalGestureEnabled = NO;
		self.dismissOnConnected = YES;
		dismissOnViewDidAppear = NO;

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(psiphonWebTabStartLoad)
													 name:kPsiphonWebTabStartLoadNotification object:nil];
	}
	return self;
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kPsiphonWebTabStartLoadNotification object:nil];
}

-(void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if(dismissOnViewDidAppear) {
		[self dismissViewControllerAnimated:NO completion:nil];
	}
}

- (void) psiphonWebTabStartLoad {
	dismissOnViewDidAppear = YES;
}

@end

@implementation PsiphonConnectionAlertViewController {

}

- (id) initWithState:(ConnectionState)state {
	self = [super initWithState:state];
	if(self) {
		self.transitionStyle = NYAlertViewControllerTransitionStyleFade;
		self.backgroundTapDismissalGestureEnabled = YES;
		self.swipeDismissalGestureEnabled = YES;
		self.dismissOnConnected = NO;
	}
	return self;
}

@end
