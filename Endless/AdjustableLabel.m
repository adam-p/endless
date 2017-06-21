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

// Based on https://stackoverflow.com/questions/2038975/resize-font-size-to-fill-uitextview/2943331#2943331

#import "AdjustableLabel.h"

@interface AdjustableLabel ()
@property(nonatomic) BOOL fontSizeAdjusted;
@end

#define MIN_FONT_SIZE 5.0f

@implementation AdjustableLabel

- (id)initWithDesiredFontSize:(CGFloat)fontSize {
	self = [super init];

	if (self) {
		self.desiredFontSize = fontSize;
	}

	return self;
}

- (void)setAdjustsFontSizeToFitFrame:(BOOL)adjustsFontSizeToFitFrame
{
	_adjustsFontSizeToFitFrame = adjustsFontSizeToFitFrame;

	if (adjustsFontSizeToFitFrame) {
		self.scrollEnabled = NO;
		self.userInteractionEnabled = NO;
		self.textContainerInset = UIEdgeInsetsZero;
		self.textContainer.lineFragmentPadding = 0;
	}
}

- (void)layoutSubviews
{
	[super layoutSubviews];

	if (self.adjustsFontSizeToFitFrame)
	{
		[self adjustFontSizeToFrame];
	}
}

- (void)adjustFontSizeToFrame
{
	CGFloat fontSize = _desiredFontSize;

	self.font = [self.font fontWithSize:fontSize];

	CGSize constraintSize = CGSizeMake(self.frame.size.width, MAXFLOAT);
	CGRect requiredRect = [self.attributedText boundingRectWithSize:constraintSize options:NSStringDrawingUsesLineFragmentOrigin context:nil];

	while (requiredRect.size.height >= self.frame.size.height)
	{
		if (fontSize <= MIN_FONT_SIZE)
			break;

		fontSize -= 1.0;
		self.font = [self.font fontWithSize:fontSize];
		requiredRect = [self.attributedText boundingRectWithSize:constraintSize options:NSStringDrawingUsesLineFragmentOrigin context:nil];
	}
}

@end
