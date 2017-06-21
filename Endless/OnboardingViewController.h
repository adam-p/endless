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

#import <UIKit/UIKit.h>

@protocol OnboardingViewControllerDelegate <NSObject>
- (void)onboardingEnded;
@end

@protocol OnboardingChildViewControllerDelegate <NSObject>
- (CGFloat)getBannerOffset;
- (void)onboardingEnded;
- (void)moveToViewAtIndex:(NSInteger)index;
@end

@interface OnboardingViewController : UIViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate, OnboardingChildViewControllerDelegate>
@property (nonatomic, weak) id<OnboardingViewControllerDelegate> delegate;
@property (strong, nonatomic) UIPageViewController *pageController;
- (void)moveToNextPage;
@end

@protocol OnboardingChildViewController <NSObject>
@property (nonatomic, weak) id<OnboardingChildViewControllerDelegate> delegate;
@property (assign, nonatomic) NSInteger index;
@end
