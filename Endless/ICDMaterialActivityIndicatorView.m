//
//  ICDMaterialProgressView.m
//  ICDUI
//
//  Created by LEI on 12/28/14.
//  Copyright (c) 2014 TouchingApp. All rights reserved.
//
/*
 The MIT License (MIT)

 Copyright (c) 2014 touchingapp.com

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */


#import "ICDMaterialActivityIndicatorView.h"

@interface ICDMaterialActivityIndicatorLayer : CAShapeLayer
@property (nonatomic) CGFloat radius;

@end

@implementation ICDMaterialActivityIndicatorLayer

- (instancetype)init{
	self = [super init];
	if (self){
		self.fillColor = [[UIColor clearColor] CGColor];
		self.lineCap = kCALineJoinRound;
	}
	return self;
}

- (void)setRadius:(CGFloat)radius{
	_radius = radius;
	self.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 2.0 * self.radius, 2.0 * self.radius) cornerRadius:self.radius].CGPath;
}

@end

@interface ICDMaterialActivityIndicatorView ()
@property(nonatomic, readwrite, getter=isAnimating) BOOL animating;
@property(nonatomic, readwrite, getter=shouldBeAnimating) BOOL shouldBeAnimating;
@property(strong, nonatomic) ICDMaterialActivityIndicatorLayer *indicatorLayer;
@end

@implementation ICDMaterialActivityIndicatorView

- (instancetype)init{
	return [self initWithActivityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleSmall];
}

- (instancetype)initWithActivityIndicatorStyle:(ICDMaterialActivityIndicatorViewStyle)style{
	return [self initWithFrame:CGRectZero activityIndicatorStyle:style];
}

- (instancetype)initWithFrame:(CGRect)frame{
	return [self initWithFrame:frame activityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleSmall];
}

- (instancetype)initWithFrame:(CGRect)frame activityIndicatorStyle:(ICDMaterialActivityIndicatorViewStyle)style{
	CGFloat radius;
	switch (style) {
		case ICDMaterialActivityIndicatorViewStyleSmall:
			radius = 10;
			break;
		case ICDMaterialActivityIndicatorViewStyleMedium:
			radius = 15;
			break;
		case ICDMaterialActivityIndicatorViewStyleLarge:
			radius = 30;
			break;
	}
	if (CGRectEqualToRect(frame, CGRectZero)){
		frame = CGRectMake(0, 0, radius * 2, radius * 2);
	}
	self = [super initWithFrame:frame];
	if (self){

		[self commonInit];
		[self setupForStyle:style];
		self.indicatorLayer.radius = radius;
	}
	return self;
}

- (void)setupForStyle: (ICDMaterialActivityIndicatorViewStyle) style {

	switch (style) {
		case ICDMaterialActivityIndicatorViewStyleSmall:
			self.lineWidth = 1.0;
			self.duration = 0.8;
			break;
		case ICDMaterialActivityIndicatorViewStyleMedium:
			self.lineWidth = 3.0;
			self.duration = 0.8;
			break;
		case ICDMaterialActivityIndicatorViewStyleLarge:
			self.lineWidth = 8.0;
			self.duration = 1.0;
			break;
	}
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)commonInit {
	_hidesWhenStopped = YES;
	_animating = NO;
	self.hidden = YES;
	[self.layer addSublayer:self.indicatorLayer];
	self.color = [UIColor lightGrayColor];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)awakeFromNib {
	[super awakeFromNib];
	[self commonInit];
	ICDMaterialActivityIndicatorViewStyle style = ICDMaterialActivityIndicatorViewStyleLarge;
	float radius = self.frame.size.width / 2.;
	if (radius <= 10.) {
		style = ICDMaterialActivityIndicatorViewStyleSmall;
	}
	if (radius <= 20.) {
		style = ICDMaterialActivityIndicatorViewStyleMedium;
	}
	[self setupForStyle:style];
	self.indicatorLayer.radius = self.frame.size.width / 2.;
}

- (void)onAppWillEnterForeground {
	if (self.shouldBeAnimating) {
		[self startAnimating];
	}
}

- (void)onAppDidEnterBackground {
	self.animating = NO;
}

- (void)layoutSubviews{
	[super layoutSubviews];
	self.indicatorLayer.frame = CGRectMake((self.bounds.size.width - 2.0 * self.indicatorLayer.radius) / 2.0 , (self.bounds.size.height - 2.0 * self.indicatorLayer.radius) / 2.0, 2.0 * self.indicatorLayer.radius, 2.0 * self.indicatorLayer.radius);
}

- (ICDMaterialActivityIndicatorLayer *)indicatorLayer{
	if (!_indicatorLayer){
		_indicatorLayer = [[ICDMaterialActivityIndicatorLayer alloc]init];
	}
	return _indicatorLayer;
}

- (void)setColor:(UIColor *)color{
	_color = color;
	self.indicatorLayer.strokeColor = self.color.CGColor;
	[self setNeedsDisplay];
}

- (void)setLineWidth:(CGFloat)lineWidth{
	_lineWidth = lineWidth;
	self.indicatorLayer.lineWidth = self.lineWidth;
	[self setNeedsDisplay];
}

- (void)setDuration:(CGFloat)duration{
	_duration = duration;
	[self resetAnimations];
}

- (void)resetAnimations{
	[self.indicatorLayer removeAllAnimations];
	[self.indicatorLayer addAnimation:[self createNewStrokeAnimation] forKey:@"rotation"];
	[self.indicatorLayer addAnimation:[self createNewRotateAnimation] forKey:@"stroke"];
}

- (CAAnimationGroup *)createNewStrokeAnimation{
	CAKeyframeAnimation *inAnimation = [CAKeyframeAnimation animationWithKeyPath:@"strokeEnd"];
	inAnimation.duration = self.duration;
	inAnimation.values = @[@(0), @(1)];

	CAKeyframeAnimation *outAnimation = [CAKeyframeAnimation animationWithKeyPath:@"strokeStart"];
	outAnimation.duration = self.duration;
	outAnimation.values = @[@(0), @(0.8), @(1)];
	outAnimation.beginTime = self.duration / 1.5;

	CAAnimationGroup *strokeAnimation = [CAAnimationGroup animation];
	strokeAnimation.animations = @[inAnimation, outAnimation];
	strokeAnimation.duration = self.duration + outAnimation.beginTime;
	strokeAnimation.repeatCount = INFINITY;
	strokeAnimation.timeOffset = self.progress;
	strokeAnimation.removedOnCompletion = NO;
	strokeAnimation.fillMode = kCAFillModeForwards;
	return strokeAnimation;
}

- (CABasicAnimation *)createNewRotateAnimation{
	CABasicAnimation *rotateAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
	rotateAnimation.fromValue = @(0);
	rotateAnimation.toValue = @(M_PI * 2);
	rotateAnimation.duration = self.duration * 1.5;
	rotateAnimation.repeatCount = INFINITY;
	rotateAnimation.timeOffset = self.progress;
	rotateAnimation.removedOnCompletion = NO;
	rotateAnimation.fillMode = kCAFillModeForwards;
	return rotateAnimation;
}

- (void)setProgress:(CGFloat)progress{
	_progress = progress;
	if (!self.isAnimating){
		[self.indicatorLayer removeAllAnimations];
		CAAnimationGroup *strokeAnimation = [self createNewStrokeAnimation];
		strokeAnimation.speed = 0;
		[self.indicatorLayer addAnimation:strokeAnimation forKey:@"rotation"];

		CABasicAnimation *rotateAnimation = [self createNewRotateAnimation];
		rotateAnimation.speed = 0;
		[self.indicatorLayer addAnimation:rotateAnimation forKey:@"stroke"];
		self.hidden = NO;
	}
}

- (void)startAnimating{
	self.shouldBeAnimating = YES;
	self.hidden = NO;
	[self resetAnimations];
	self.indicatorLayer.speed = 1;
	self.animating = YES;
}

- (void)stopAnimating{
	self.shouldBeAnimating = NO;
	[UIView animateWithDuration:0.5 animations:^{
		self.alpha = 0.0;
	} completion:^(BOOL finished) {
		self.alpha = 1.0;
		if (!self.shouldBeAnimating) {
			self.hidden = self.hidesWhenStopped;
			[self.indicatorLayer removeAllAnimations];
			self.animating = NO;
		}


	}];
}

- (CGSize)intrinsicContentSize {
	return self.frame.size;
}

@end
