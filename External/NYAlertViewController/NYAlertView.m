//
//  NYAlertView.m
//
//  Created by Nealon Young on 7/13/15.
//  Copyright (c) 2015 Nealon Young. All rights reserved.
//

#import "NYAlertView.h"

#import "NYAlertViewController.h"

@interface NYAlertTextView : UITextView

@end

@implementation NYAlertTextView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer {
	self = [super initWithFrame:frame textContainer:textContainer];

	self.textContainerInset = UIEdgeInsetsZero;

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	if (!CGSizeEqualToSize(self.bounds.size, [self intrinsicContentSize])) {
		[self invalidateIntrinsicContentSize];
	}
}

- (CGSize)intrinsicContentSize {
	if ([self.text length]) {
		return self.contentSize;
	} else {
		return CGSizeZero;
	}
}

@end

@implementation UIButton (BackgroundColor)

- (void)setBackgroundColor:(UIColor *)color forState:(UIControlState)state {
	[self setBackgroundImage:[self imageWithColor:color] forState:state];
}

- (UIImage *)imageWithColor:(UIColor *)color {
	CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
	UIGraphicsBeginImageContext(rect.size);
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGContextSetFillColorWithColor(context, [color CGColor]);
	CGContextFillRect(context, rect);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return image;
}

@end

@implementation NYAlertViewButton

+ (id)buttonWithType:(UIButtonType)buttonType {
	return [super buttonWithType:UIButtonTypeCustom];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];

	if (self) {
		[self commonInit];
	}

	return self;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];

	if (self) {
		[self commonInit];
	}

	return self;
}

- (void)commonInit {
	self.layer.rasterizationScale = [[UIScreen mainScreen] scale];
	self.layer.shouldRasterize = YES;

	self.layer.borderWidth = 1.0f;
	self.layer.borderColor = [UIColor colorWithRed:224/255.0 green:224/255.0 blue:224/255.0 alpha:1.0].CGColor;

	self.clipsToBounds = YES;

	[self tintColorDidChange];
}

- (void)setHidden:(BOOL)hidden {
	[super setHidden:hidden];
	[self invalidateIntrinsicContentSize];
}

- (CGFloat)cornerRadius {
	return self.layer.cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
	self.layer.cornerRadius = cornerRadius;
}

- (CGSize)intrinsicContentSize {
	if (self.hidden) {
		return CGSizeZero;
	}

	return CGSizeMake([super intrinsicContentSize].width + 12.0f, 30.0f);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesBegan:touches withEvent:event];
	[self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesMoved:touches withEvent:event];
	[self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesEnded:touches withEvent:event];
	[self setNeedsDisplay];
}


@end

@interface NYAlertView ()

@property (nonatomic) NSLayoutConstraint *alertBackgroundWidthConstraint;
@property (nonatomic) UIView *contentViewContainerView;
@property (nonatomic) UIView *textFieldContainerView;
@property (nonatomic) UIView *actionButtonContainerView;

@end

@implementation NYAlertView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];

	if (self) {
		self.maximumWidth = 480.0f;

		_alertBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		[self.alertBackgroundView setTranslatesAutoresizingMaskIntoConstraints:NO];
		self.alertBackgroundView.backgroundColor = [UIColor colorWithWhite:0.97f alpha:1.0f];
		self.alertBackgroundView.layer.cornerRadius = 6.0f;
		self.alertBackgroundView.layer.masksToBounds = YES;
		[self addSubview:_alertBackgroundView];

		_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[self.titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		self.titleLabel.numberOfLines = 2;
		self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
		self.titleLabel.textAlignment = NSTextAlignmentCenter;
		self.titleLabel.textColor = [UIColor blackColor];
		self.titleLabel.text = NSLocalizedStringWithDefaultValue(@"NYALERT_TITLE", nil, [NSBundle mainBundle], @"Title Label", nil);
		[self.alertBackgroundView addSubview:self.titleLabel];

		_messageTextView = [[NYAlertTextView alloc] initWithFrame:CGRectZero];
		[self.messageTextView setTranslatesAutoresizingMaskIntoConstraints:NO];
		self.messageTextView.backgroundColor = [UIColor clearColor];
		[self.messageTextView setContentHuggingPriority:0 forAxis:UILayoutConstraintAxisVertical];
		[self.messageTextView setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
		self.messageTextView.editable = NO;
		self.messageTextView.textAlignment = NSTextAlignmentCenter;
		self.messageTextView.textColor = [UIColor blackColor];
		self.messageTextView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
		self.messageTextView.text = NSLocalizedStringWithDefaultValue(@"NYALERT_TEXT", nil, [NSBundle mainBundle], @"Message Text View", nil);
		[self.alertBackgroundView addSubview:self.messageTextView];

		_contentViewContainerView = [[UIView alloc] initWithFrame:CGRectZero];
		[self.contentViewContainerView setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self.contentView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
		[self.alertBackgroundView addSubview:self.contentViewContainerView];

		_textFieldContainerView = [[UIView alloc] initWithFrame:CGRectZero];
		[self.textFieldContainerView setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self.textFieldContainerView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
		[self.alertBackgroundView addSubview:self.textFieldContainerView];

		_actionButtonContainerView = [[UIView alloc] initWithFrame:CGRectZero];
		[self.actionButtonContainerView setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self.actionButtonContainerView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
		[self.alertBackgroundView addSubview:self.actionButtonContainerView];
	}
	self.clipsToBounds = YES;
	return self;
}

- (void) didMoveToSuperview {
	[self addConstraint:[NSLayoutConstraint constraintWithItem:self.alertBackgroundView
													 attribute:NSLayoutAttributeCenterX
													 relatedBy:NSLayoutRelationEqual
														toItem:self
													 attribute:NSLayoutAttributeCenterX
													multiplier:1.0f
													  constant:0.0f]];

	CGFloat alertBackgroundViewWidth = MIN(CGRectGetWidth([UIApplication sharedApplication].keyWindow.bounds),
										   CGRectGetHeight([UIApplication sharedApplication].keyWindow.bounds)) * 0.8f;

	if (alertBackgroundViewWidth > self.maximumWidth) {
		alertBackgroundViewWidth = self.maximumWidth;
	}

	_alertBackgroundWidthConstraint = [NSLayoutConstraint constraintWithItem:self.alertBackgroundView
																   attribute:NSLayoutAttributeWidth
																   relatedBy:NSLayoutRelationEqual
																	  toItem:nil
																   attribute:NSLayoutAttributeNotAnAttribute
																  multiplier:0.0f
																	constant:alertBackgroundViewWidth];

	[self addConstraint:self.alertBackgroundWidthConstraint];

	_backgroundViewVerticalCenteringConstraint = [NSLayoutConstraint constraintWithItem:self.alertBackgroundView
																			  attribute:NSLayoutAttributeCenterY
																			  relatedBy:NSLayoutRelationEqual
																				 toItem:self
																			  attribute:NSLayoutAttributeCenterY
																			 multiplier:1.0f
																			   constant:0.0f];

	[self addConstraint:self.backgroundViewVerticalCenteringConstraint];

	[self addConstraint:[NSLayoutConstraint constraintWithItem:self.alertBackgroundView
													 attribute:NSLayoutAttributeHeight
													 relatedBy:NSLayoutRelationLessThanOrEqual
														toItem:self
													 attribute:NSLayoutAttributeHeight
													multiplier:0.9f
													  constant:0.0f]];

	[self.alertBackgroundView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_titleLabel]-|"
																					 options:0
																					 metrics:nil
																					   views:NSDictionaryOfVariableBindings(_titleLabel)]];

	[self.alertBackgroundView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_messageTextView]-|"
																					 options:0
																					 metrics:nil
																					   views:NSDictionaryOfVariableBindings(_messageTextView)]];

	[self.alertBackgroundView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_contentViewContainerView]|"
																					 options:0
																					 metrics:nil
																					   views:NSDictionaryOfVariableBindings(_contentViewContainerView)]];

	[self.alertBackgroundView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_textFieldContainerView]|"
																					 options:0
																					 metrics:nil
																					   views:NSDictionaryOfVariableBindings(_textFieldContainerView)]];

	[self.alertBackgroundView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_actionButtonContainerView]|"
																					 options:0
																					 metrics:nil
																					   views:NSDictionaryOfVariableBindings(_actionButtonContainerView)]];

	[self.alertBackgroundView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_titleLabel]-2-[_messageTextView][_contentViewContainerView][_textFieldContainerView][_actionButtonContainerView]|"
																					 options:0
																					 metrics:nil
																					   views:NSDictionaryOfVariableBindings(_titleLabel,
																															_messageTextView,
																															_contentViewContainerView,
																															_textFieldContainerView,
																															_actionButtonContainerView)]];
}

// Pass through touches outside the backgroundView for the presentation controller to handle dismissal
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
	for (UIView *subview in self.subviews) {
		if ([subview hitTest:[self convertPoint:point toView:subview] withEvent:event]) {
			return YES;
		}
	}

	return NO;
}

- (void)setMaximumWidth:(CGFloat)maximumWidth {
	_maximumWidth = maximumWidth;
	self.alertBackgroundWidthConstraint.constant = maximumWidth;
}

- (void)setContentView:(UIView *)contentView {
	[self.contentView removeFromSuperview];

	_contentView = contentView;

	if (contentView) {
		[self.contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self.contentViewContainerView addSubview:self.contentView];

		[self.contentViewContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_contentView]|"
																							  options:0
																							  metrics:nil
																								views:NSDictionaryOfVariableBindings(_contentView)]];

		[self.contentViewContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-8-[_contentView]-8-|"
																							  options:0
																							  metrics:nil
																								views:NSDictionaryOfVariableBindings(_contentView)]];
	}
}

- (void)setTextFields:(NSArray *)textFields {
	for (UITextField *textField in self.textFields) {
		[textField removeFromSuperview];
	}

	_textFields = textFields;

	for (int i = 0; i < [textFields count]; i++) {
		UITextField *textField = textFields[i];
		[textField setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self.textFieldContainerView addSubview:textField];

		[self.textFieldContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textField]-|"
																							options:0
																							metrics:nil
																							  views:NSDictionaryOfVariableBindings(textField)]];

		// Pin the first text field to the top of the text field container view
		if (i == 0) {
			[self.textFieldContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[textField]"
																								options:0
																								metrics:nil
																								  views:NSDictionaryOfVariableBindings(_contentViewContainerView, textField)]];
		} else {
			UITextField *previousTextField = textFields[i - 1];

			[self.textFieldContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[previousTextField]-[textField]"
																								options:0
																								metrics:nil
																								  views:NSDictionaryOfVariableBindings(previousTextField, textField)]];
		}

		// Pin the final text field to the bottom of the text field container view
		if (i == ([textFields count] - 1)) {
			[self.textFieldContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[textField]-|"
																								options:0
																								metrics:nil
																								  views:NSDictionaryOfVariableBindings(textField)]];
		}
	}
}

- (void)setActionButtons:(NSArray *)actionButtons {
	for (UIButton *button  in self.actionButtons) {
		[button removeFromSuperview];
	}

	_actionButtons = actionButtons;
	UIButton *firstButton = nil;
	UIButton *lastButton = nil;

	// If there are 2 actions, display the buttons next to each other. Otherwise, stack the buttons vertically at full width
	if ([actionButtons count] == 2) {
		//flip buttons for RTL languages
		if ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) {
			firstButton = actionButtons[1];
			lastButton = actionButtons[0];
		} else {
			firstButton = actionButtons[0];
			lastButton = actionButtons[1];
		}

		[self.actionButtonContainerView addSubview:firstButton];
		[self.actionButtonContainerView addSubview:lastButton];
		[self.actionButtonContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[firstButton(40)]"
																							   options:0
																							   metrics:nil
																								 views:NSDictionaryOfVariableBindings(firstButton)]];
		[self.actionButtonContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastButton(40)]"
																							   options:0
																							   metrics:nil
																								 views:NSDictionaryOfVariableBindings(lastButton)]];


		[self.actionButtonContainerView addConstraints:@[
														 [NSLayoutConstraint constraintWithItem:firstButton
																					  attribute:NSLayoutAttributeTop
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:self.actionButtonContainerView
																					  attribute:NSLayoutAttributeTop
																					 multiplier:1.0
																					   constant:0],
														 [NSLayoutConstraint constraintWithItem:firstButton
																					  attribute:NSLayoutAttributeBottom
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:self.actionButtonContainerView
																					  attribute:NSLayoutAttributeBottom
																					 multiplier:1.0
																					   constant:1],
														 [NSLayoutConstraint constraintWithItem:firstButton
																					  attribute:NSLayoutAttributeLeft
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:self.actionButtonContainerView
																					  attribute:NSLayoutAttributeLeft
																					 multiplier:1.0
																					   constant:-1],

														 [NSLayoutConstraint constraintWithItem:lastButton
																					  attribute:NSLayoutAttributeTop
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:self.actionButtonContainerView
																					  attribute:NSLayoutAttributeTop
																					 multiplier:1.0
																					   constant:0],
														 [NSLayoutConstraint constraintWithItem:lastButton
																					  attribute:NSLayoutAttributeBottom
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:self.actionButtonContainerView
																					  attribute:NSLayoutAttributeBottom
																					 multiplier:1.0
																					   constant:1],
														 [NSLayoutConstraint constraintWithItem:lastButton
																					  attribute:NSLayoutAttributeRight
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:self.actionButtonContainerView
																					  attribute:NSLayoutAttributeRight
																					 multiplier:1.0
																					   constant:1],

														 [NSLayoutConstraint constraintWithItem:lastButton
																					  attribute:NSLayoutAttributeLeft
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:firstButton
																					  attribute:NSLayoutAttributeRight
																					 multiplier:1.0
																					   constant:-1],
														 [NSLayoutConstraint constraintWithItem:lastButton
																					  attribute:NSLayoutAttributeWidth
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:firstButton
																					  attribute:NSLayoutAttributeWidth
																					 multiplier:1.0
																					   constant:0],
														 ]];
	} else if ([actionButtons count] > 0){
		for (int i = 0; i < [actionButtons count]; i++) {
			UIButton *actionButton = actionButtons[i];

			[self.actionButtonContainerView addSubview:actionButton];

			[self.actionButtonContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[actionButton(40)]"
																								   options:0
																								   metrics:nil
																									 views:NSDictionaryOfVariableBindings(actionButton)]];

			[self.actionButtonContainerView addConstraints:@[
															 [NSLayoutConstraint constraintWithItem:actionButton
																						  attribute:NSLayoutAttributeRight
																						  relatedBy:NSLayoutRelationEqual
																							 toItem:self.actionButtonContainerView
																						  attribute:NSLayoutAttributeRight
																						 multiplier:1.0
																						   constant:1],

															 [NSLayoutConstraint constraintWithItem:actionButton
																						  attribute:NSLayoutAttributeLeft
																						  relatedBy:NSLayoutRelationEqual
																							 toItem:self.actionButtonContainerView
																						  attribute:NSLayoutAttributeLeft
																						 multiplier:1.0
																						   constant:-1],
															 ]];

			if(!firstButton) {
				firstButton = actionButton;
				[self.actionButtonContainerView addConstraints:@[
																 [NSLayoutConstraint constraintWithItem:firstButton
																							  attribute:NSLayoutAttributeTop
																							  relatedBy:NSLayoutRelationEqual
																								 toItem:self.actionButtonContainerView
																							  attribute:NSLayoutAttributeTop
																							 multiplier:1.0
																							   constant:0],
																 ]];
			} else {
				[self.actionButtonContainerView addConstraints:@[
																 [NSLayoutConstraint constraintWithItem:actionButton
																							  attribute:NSLayoutAttributeTop
																							  relatedBy:NSLayoutRelationEqual
																								 toItem:lastButton
																							  attribute:NSLayoutAttributeBottom
																							 multiplier:1.0
																							   constant:-1],
																 ]];
			}

			lastButton = actionButton;
		}

		[self.actionButtonContainerView addConstraints:@[
														 [NSLayoutConstraint constraintWithItem:lastButton
																					  attribute:NSLayoutAttributeBottom
																					  relatedBy:NSLayoutRelationEqual
																						 toItem:self.actionButtonContainerView
																					  attribute:NSLayoutAttributeBottom
																					 multiplier:1.0
																					   constant:1],
														 ]];

	}
}

@end
