/*
 * Copyright (c) 2016, Psiphon Inc.
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

#import "PsiphonConnectionIndicator.h"

@implementation PsiphonConnectionIndicator {
	UIImageView *_imgConnected;
	UIImageView *_imgDisconnected;
	UIActivityIndicatorView *_activityIndicator;
}

- (id) initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];

	_imgConnected = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"psiphon_connected"]];
	[self addSubview:_imgConnected];

	_imgDisconnected = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"psiphon_disconnected"]];
	_imgDisconnected.alpha = 0.0;
	[self addSubview:_imgDisconnected];

	_activityIndicator = [[UIActivityIndicatorView alloc]
						  initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_activityIndicator.alpha = 0.0;
	[self addSubview:_activityIndicator];

	_imgConnected.alpha = _imgDisconnected.alpha = _activityIndicator.alpha = 0.0;
	_imgConnected.center = _imgDisconnected.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);

	// Calculate offset so the spinner doesn't appear off center of the main logo circle
	// The tiny circle on the bottom right sticks out about 1/11 of the image width
	float offset = (_imgDisconnected.frame.size.width / 11.0)/2;
	_activityIndicator.center = CGPointMake(self.bounds.size.width / 2 - offset, self.bounds.size.height/2 - offset);


	[self displayConnectionState:ConnectionStateDisconnected];
	return self;
}

- (void) displayConnectionState:(ConnectionState)state {
	CGFloat activityIndicatorAlpha, imgConnectedAlpha, imgDisconnectedAlpha = 0.0f;
	void (^animationCompleted)(BOOL finished);
	switch (state) {
		case ConnectionStateConnected:
		{
			activityIndicatorAlpha = 0.0f;
			imgConnectedAlpha = 1.0f;
			imgDisconnectedAlpha = 0.0f;
			animationCompleted = ^(BOOL finished){
				[_activityIndicator stopAnimating];
				[_activityIndicator setUserInteractionEnabled:NO];
			};
			break;
		}
		case ConnectionStateConnecting:
		{
			activityIndicatorAlpha = 1.0f;
			imgConnectedAlpha = 0.0f;
			imgDisconnectedAlpha = 0.2f;
			animationCompleted = ^(BOOL finished){
				[_activityIndicator startAnimating];
				[_activityIndicator setUserInteractionEnabled:NO];
			};
			break;
		}
		case ConnectionStateWaitingForNetwork:
		{
			activityIndicatorAlpha = 1.0f;
			imgConnectedAlpha = 0.0f;
			imgDisconnectedAlpha = 0.2f;
			animationCompleted = ^(BOOL finished){
				[_activityIndicator startAnimating];
				[_activityIndicator setUserInteractionEnabled:NO];
			};
			break;
		}
		case ConnectionStateDisconnected:
		{
			activityIndicatorAlpha = 0.0f;
			imgConnectedAlpha = 0.0f;
			imgDisconnectedAlpha = 1.0f;
			animationCompleted = ^(BOOL finished){
				[_activityIndicator stopAnimating];
				[_activityIndicator setUserInteractionEnabled:NO];
			};
			break;
		}
		default:
			break;
	}

	[UIView animateWithDuration:0.1
					 animations:^{
						 _activityIndicator.alpha = activityIndicatorAlpha;
						 _imgConnected.alpha = imgConnectedAlpha;
						 _imgDisconnected.alpha = imgDisconnectedAlpha;
					 }
					 completion: animationCompleted];
}

@end
