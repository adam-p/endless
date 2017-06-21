/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "Bookmark.h"
#import "BookmarkController.h"
#import "HTTPSEverywhereRuleController.h"
#import "IASKSettingsReader.h"
#import "IASKSpecifierValuesViewController.h"
#import "RegionAdapter.h"
#import "SettingsViewController.h"
#import "SSLCertificateViewController.h"
#import "UpstreamProxySettings.h"
#import "JAHPAuthenticatingHTTPProtocol.h"
#import "WebViewController.h"
#import "WebViewTab.h"
#import "PsiphonConnectionIndicator.h"
#import "PsiphonConnectionModalViewController.h"
#import "PsiphonHomePagesEquivalentURLs.h"

#define TOOLBAR_HEIGHT 44
#define TOOLBAR_PADDING 6
#define TOOLBAR_BUTTON_SIZE 40
#define kBookmarksCancelButtonWidth 70

static BOOL (^safeStringsEqual)(NSString *, NSString *) = ^BOOL(NSString *a, NSString *b) {
	return (([a length] == 0) && ([b length] == 0)) || ([a isEqualToString:b]);
};


@implementation UIColor (DefaultNavigationControllerColor)
+ (UIColor *)defaultNavigationControllerColor {
	return [UIColor colorWithRed:(247/255.0f) green:(247/255.0f) blue:(247/255.0f) alpha:1];
}
@end

@interface WebViewController (RegionSelectionControllerDelegate) <RegionSelectionControllerDelegate>
@end

@implementation WebViewController {

	UIScrollView *tabScroller;
	UIPageControl *tabChooser;
	int curTabIndex;
	int curTabIndexFromRestoration;
	NSMutableArray *webViewTabs;

	PsiphonConnectionIndicator *psiphonConnectionIndicator;
	UIView *navigationBar;
	UITextField *urlField;
	UIButton *lockIcon;
	UIButton *brokenLockIcon;
	UIButton *refreshButton;
	UIProgressView *progressBar;
	UIToolbar *tabToolbar;
	UILabel *tabCount;
	int keyboardHeight;

	UIToolbar *bottomToolBar;

	UIButton *backButton;
	UIButton *forwardButton;
	UIButton *tabsButton;
	UIButton *settingsButton;
	UIButton *bookmarksButton;

	UIBarButtonItem *tabAddButton;
	UIBarButtonItem *tabDoneButton;
	UIBarButtonItem *bookmarkAddButton;

	float currentWebViewScrollOffsetY;
	BOOL isShowingToolBars;

	BOOL showingTabs;
	BOOL webViewScrollIsDecelerating;
	BOOL webViewScrollIsDragging;

	SettingsViewController *appSettingsViewController;

	BookmarkController *bookmarks;
	UIButton *bookmarksCancelButton;
	NSLayoutConstraint *bookmarksViewBottom;

	NSMutableDictionary *preferencesSnapshot;

	TutorialViewController *tutorial;

	UIPanGestureRecognizer *tabSelectionPanGestureRecognizer;
	CGPoint originalPoint; // Where the tab was before dragging
	CGPoint panGestureOriginPoint; // Where the user started dragging
	int panGestureRecognizerType; // 0: None, 1: Remove tab, 2: Change page

	BOOL isRTL;
}

// Force portrait orientation during onboarding
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	if (self.showTutorial && ![[NSUserDefaults standardUserDefaults] boolForKey:kHasBeenOnboardedKey]) {
		return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown);
	} else {
		return UIInterfaceOrientationMaskAll;
	}
}

-(id)init {
	if (self = [super init]) {
		[self setOpenSettingImmediatelyOnViewDidAppear:NO];
		[self setShowTutorial:NO];
	}
	return self;
}

- (void)loadView
{
	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	[[AppDelegate sharedAppDelegate] setWebViewController:self];

	[[AppDelegate sharedAppDelegate] setDefaultUserAgent:[self buildDefaultUserAgent]];

	webViewTabs = [[NSMutableArray alloc] initWithCapacity:10];
	curTabIndex = 0;
	curTabIndexFromRestoration = 0;

	self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].applicationFrame.size.width, [UIScreen mainScreen].applicationFrame.size.height)];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

	tabScroller = [[UIScrollView alloc] init];
	[tabScroller setScrollEnabled:NO];
	[[self view] addSubview:tabScroller];

	navigationBar = [[UIView alloc] init];
	[navigationBar setClipsToBounds:YES];
	[[self view] addSubview:navigationBar];

	bottomToolBar = [[UIToolbar alloc] init];
	[bottomToolBar setClipsToBounds:YES];
	[[self view] addSubview:bottomToolBar];


	keyboardHeight = 0;

	progressBar = [[UIProgressView alloc] init];
	[progressBar setTrackTintColor:[UIColor clearColor]];
	[progressBar setTintColor:self.view.window.tintColor];
	[progressBar setProgress:0.0];
	[navigationBar addSubview:progressBar];

	urlField = [[UITextField alloc] init];
	[urlField.layer setCornerRadius:6.0f];
	[urlField.layer setBorderWidth:0.0f];
	[urlField setKeyboardType:UIKeyboardTypeWebSearch];
	[urlField setFont:[UIFont systemFontOfSize:15]];
	[urlField setReturnKeyType:UIReturnKeyGo];
	[urlField setClearButtonMode:UITextFieldViewModeWhileEditing];
	[urlField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
	[urlField setLeftViewMode:UITextFieldViewModeAlways];
	[urlField setRightViewMode:UITextFieldViewModeAlways];
	[urlField setSpellCheckingType:UITextSpellCheckingTypeNo];
	[urlField setAutocorrectionType:UITextAutocorrectionTypeNo];
	[urlField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	[urlField setDelegate:self];
	[navigationBar addSubview:urlField];

	psiphonConnectionIndicator = [[PsiphonConnectionIndicator alloc]
								  initWithFrame: [self frameForConnectionIndicator]];
	[psiphonConnectionIndicator addTarget:self action:@selector(showPsiphonConnectionStatusAlert)
						 forControlEvents:UIControlEventTouchUpInside];

	[navigationBar addSubview:psiphonConnectionIndicator];


	lockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
	[lockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[lockIcon setImage:[UIImage imageNamed:@"lock"] forState:UIControlStateNormal];
	[[lockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[lockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];

	brokenLockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
	[brokenLockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[brokenLockIcon setImage:[UIImage imageNamed:@"broken_lock"] forState:UIControlStateNormal];
	[[brokenLockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[brokenLockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];

	refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[refreshButton setFrame:CGRectMake(0, 0, 24, 16)];
	[refreshButton setImage:[UIImage imageNamed:@"refresh"] forState:UIControlStateNormal];
	[[refreshButton imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[refreshButton addTarget:self action:@selector(forceRefresh) forControlEvents:UIControlEventTouchUpInside];

	backButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *backImage = [[UIImage imageNamed: isRTL ? @"arrow_right" : @"arrow_left"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[backButton setImage:backImage forState:UIControlStateNormal];
	[backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
	[backButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];

	forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *forwardImage = [[UIImage imageNamed: isRTL ? @"arrow_left" : @"arrow_right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[forwardButton setImage:forwardImage forState:UIControlStateNormal];
	[forwardButton addTarget:self action:@selector(goForward:) forControlEvents:UIControlEventTouchUpInside];
	[forwardButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];


	tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *tabsImage = [[UIImage imageNamed:@"tabs"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[tabsButton setImage:tabsImage forState:UIControlStateNormal];
	[tabsButton setTintColor:[progressBar tintColor]];
	[tabsButton addTarget:self action:@selector(showTabs:) forControlEvents:UIControlEventTouchUpInside];
	[tabsButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];

	tabCount = [[UILabel alloc] init];
	[tabCount setText:@""];
	[tabCount setTextAlignment:NSTextAlignmentCenter];
	[tabCount setFont:[UIFont systemFontOfSize:11]];
	[tabCount setTextColor:[progressBar tintColor]];
	[tabCount setAdjustsFontSizeToFitWidth:YES];
	// offset ratios from centre of `tabsImage` to
	// centre of the square in the forefront of `tabsImage`.
	CGSize tabCountOffsetRatios = CGSizeMake(-1/8.f, 1/8.f);
	[tabCount setFrame:CGRectMake(0, 0, 12, 12)];
	[tabCount setCenter:CGPointMake(tabsButton.center.x + (tabsButton.frame.size.width * tabCountOffsetRatios.width)/2, tabsButton.center.y + (tabsButton.frame.size.height * tabCountOffsetRatios.height)/2)];
	[tabsButton addSubview:tabCount];

	settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *settingsImage = [[UIImage imageNamed:@"settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[settingsButton setImage:settingsImage forState:UIControlStateNormal];
	[settingsButton setTintColor:[progressBar tintColor]];
	[settingsButton addTarget:self action:@selector(openSettingsMenu:) forControlEvents:UIControlEventTouchUpInside];
	[settingsButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];

	bookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *bookmarksImage = [[UIImage imageNamed:@"bookmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[bookmarksButton setImage:bookmarksImage forState:UIControlStateNormal];
	[bookmarksButton setTintColor:[progressBar tintColor]];
	[bookmarksButton addTarget:self action:@selector(addBookmarkFromBottomToolbar:) forControlEvents:UIControlEventTouchUpInside];
	[bookmarksButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];

	bookmarkAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(addBookmarkFromBottomToolbar:)];



	bottomToolBar.items = [NSArray arrayWithObjects:
						   [[UIBarButtonItem alloc] initWithCustomView:backButton ],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:forwardButton],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:settingsButton],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:bookmarksButton],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:tabsButton],
						   nil];


	[tabScroller setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
	[tabScroller setAutoresizesSubviews:NO];
	[tabScroller setShowsHorizontalScrollIndicator:NO];
	[tabScroller setShowsVerticalScrollIndicator:NO];
	[tabScroller setScrollsToTop:NO];
	[tabScroller setDelaysContentTouches:NO];
	[tabScroller setDelegate:self];

	tabChooser = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_HEIGHT)];

	[tabChooser setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin)];
	[tabChooser addTarget:self action:@selector(slideToCurrentTab:) forControlEvents:UIControlEventValueChanged];
	[tabChooser addTarget:self action:@selector(tappedOnPageControlDot:) forControlEvents:UIControlEventTouchUpInside];
	[tabChooser setNumberOfPages:0];
	[self.view insertSubview:tabChooser aboveSubview:navigationBar];
	[tabChooser setHidden:true];

	tabToolbar = [[UIToolbar alloc] init];
	[tabToolbar setClipsToBounds:YES];
	[tabToolbar setHidden:true];
	[self.view insertSubview:tabToolbar aboveSubview:navigationBar];

	tabAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNewTabFromToolbar:)];
	tabDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneWithTabsButton:)];
	tabDoneButton.title = NSLocalizedString(@"Done", @"Done button title, dismisses the tab chooser");

	tabToolbar.items = [NSArray arrayWithObjects:
						[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						tabAddButton,
						[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						tabDoneButton,
						nil];

	UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOnNavBar:)];
	singleTapGestureRecognizer.numberOfTapsRequired = 1;
	singleTapGestureRecognizer.enabled = YES;
	singleTapGestureRecognizer.cancelsTouchesInView = NO;
	[navigationBar addGestureRecognizer:singleTapGestureRecognizer];

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[center addObserver:self selector:@selector(psiphonConnectionStateNotified:) name:kPsiphonConnectionStateNotification object:nil];

	[self adjustLayout];

	[self.view.window makeKeyAndVisible];
}

- (void)dealloc {
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
	[center removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
	[center removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[center removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	[center removeObserver:self name:kPsiphonConnectionStateNotification object:nil];
}

- (id)settingsButton
{
	return settingsButton;
}

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super encodeRestorableStateWithCoder:coder];

	[[PsiphonHomePagesEquivalentURLs sharedInstance] encodeRestorableStateWithCoder:coder];

	if (webViewTabs.count > 0) {
		NSMutableArray *wvtd = [[NSMutableArray alloc] initWithCapacity:webViewTabs.count - 1];
		for (WebViewTab *wvt in webViewTabs) {
			if (wvt.url != nil) {
				[wvtd addObject:@{ @"url" : wvt.url, @"title" : wvt.title.text }];
				[[wvt webView] setRestorationIdentifier:[wvt.url absoluteString]];
			} else if (wvt.webView.restorationIdentifier !=nil) {
				[wvtd addObject:@{ @"url" : [NSURL URLWithString:wvt.webView.restorationIdentifier], @"title" : wvt.title.text }];
				[[wvt webView] setRestorationIdentifier:wvt.webView.restorationIdentifier];
			} else {
				continue;
			}

#ifdef TRACE
			NSLog(@"encoded restoration state for tab %@ with %@", wvt.tabIndex, wvtd[wvtd.count - 1]);
#endif
		}
		[coder encodeObject:wvtd forKey:@"webViewTabs"];
		[coder encodeObject:[NSNumber numberWithInt:curTabIndex] forKey:@"curTabIndex"];
	}
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super decodeRestorableStateWithCoder:coder];
	[[PsiphonHomePagesEquivalentURLs sharedInstance] decodeRestorableStateWithCoder:coder];


	NSMutableArray *wvt = [coder decodeObjectForKey:@"webViewTabs"];
	for (int i = 0; i < wvt.count; i++) {
		NSDictionary *params = wvt[i];
#ifdef TRACE
		NSLog(@"restoring tab %d with %@", i, params);
#endif
		WebViewTab *wvt = [self addNewTabForURL:[params objectForKey:@"url"] forRestoration:YES andFocus:NO withCompletionBlock:nil];
		[[wvt title] setText:[params objectForKey:@"title"]];
	}

	NSNumber *cp = [coder decodeObjectForKey:@"curTabIndex"];
	if (cp != nil && [webViewTabs count] > 0) {
		if ([cp intValue] <= [webViewTabs count] - 1) {
			curTabIndexFromRestoration = [cp intValue];
		}
	}

	[self updateSearchBarDetails];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	/* we made it this far, remove lock on previous startup */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
	[userDefaults synchronize];

	if(self.openSettingImmediatelyOnViewDidAppear) {
		[self openSettingsMenu:nil];
		[self setOpenSettingImmediatelyOnViewDidAppear:NO];
		return;
	}

	if (self.showTutorial) {
		if (tutorial == nil) {
			[self overlayTutorial];
		}
		return;
	}

	[self viewIsVisible];
}

/* called when we've become visible and after the overlaid tutorial has ended */
- (void)viewIsVisible
{
	if ([[AppDelegate sharedAppDelegate] areTesting]) {
		return;
	}
	BOOL shouldShowSplash = YES;

	// show splash if there are no browser tabs
	// that are not in a state of restoration
	for (WebViewTab* wvt in webViewTabs) {
		if (!wvt.isRestoring) {
			shouldShowSplash = NO;
			break;
		}
	}

	if (shouldShowSplash && !self.showTutorial) {
		__weak  WebViewController *weakSelf = self;

		PsiphonConnectionSplashViewController *connectionSplashViewController = [[PsiphonConnectionSplashViewController alloc]
																				 initWithState:[[AppDelegate sharedAppDelegate] getConnectionState]];
		connectionSplashViewController.delegate = self;
		[connectionSplashViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Go to Settings", nil)
																		   style:UIAlertActionStyleDefault
																		 handler:^(NYAlertAction *action) {
																			 [weakSelf openSettingsMenu:nil];
																		 }]];

		[self presentViewController:connectionSplashViewController animated:NO
						 completion:^(){[[AppDelegate sharedAppDelegate] notifyConnectionState];}];
	}

	[self adjustLayout];
}

- (void)keyboardWillShow:(NSNotification *)notification {
	CGRect keyboardStart = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	CGRect keyboardEnd = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

	/* on devices with a bluetooth keyboard attached, both values should be the same for a 0 height */
	keyboardHeight = keyboardStart.origin.y - keyboardEnd.origin.y;

	[self adjustLayout];
}

- (void)keyboardWillHide:(NSNotification *)notification {
	keyboardHeight = 0;
	[self adjustLayout];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	// reset gesture recognizer type
	panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;

	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		if (showingTabs)
			[self showTabsWithCompletionBlock:nil];

		[self adjustLayout];
	} completion:nil];
}

- (void) showToolBars:(BOOL) show {
	CGFloat navBarOffsetY  = 0.0;
	CGFloat bottomBarOffsetY = 0.0;
	CGRect navBarFrame = navigationBar.frame;
	CGRect bottomToolBarFrame = bottomToolBar.frame;
	float statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;

	if (isShowingToolBars == show) {
		return;
	}

	if(show) {
		navBarOffsetY = statusBarHeight ;
		bottomBarOffsetY = self.view.frame.size.height - TOOLBAR_HEIGHT;
		isShowingToolBars = YES;
	}
	else {
		navBarOffsetY = statusBarHeight - TOOLBAR_HEIGHT;
		bottomBarOffsetY = self.view.frame.size.height;
		isShowingToolBars = NO;
	}

	navBarFrame.origin.y = navBarOffsetY;
	bottomToolBarFrame.origin.y = bottomBarOffsetY;

	CGFloat toolBarAlpha = show ? 1.0f : 0.0f;
	[UIView animateWithDuration: 0.1 animations:^{
		navigationBar.frame = navBarFrame;
		bottomToolBar.frame = bottomToolBarFrame;
		navigationBar.alpha = toolBarAlpha;
		bottomToolBar.alpha = toolBarAlpha;

		tabScroller.frame = CGRectMake(0, navigationBar.frame.origin.y + navigationBar.frame.size.height, navigationBar.frame.size.width, self.view.frame.size.height - (navigationBar.frame.origin.y + navigationBar.frame.size.height) - (self.view.frame.size.height - bottomBarOffsetY));
		[self adjustWebViewTabsLayout];
	}];
	[self.view setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

	[tabScroller setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[tabToolbar setBarTintColor:[UIColor defaultNavigationControllerColor]];
	[urlField setBackgroundColor:[UIColor whiteColor]];

	[tabAddButton setTintColor:[progressBar tintColor]];
	[tabDoneButton setTintColor:[progressBar tintColor]];
	[settingsButton setTintColor:[progressBar tintColor]];
	[tabsButton setTintColor:[progressBar tintColor]];
	[tabCount setTextColor:[progressBar tintColor]];

	[tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
	[tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];

	/* tabScroller.frame is now our actual webview viewing area */
}

- (void)adjustLayout
{
	float statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
	CGSize size = [[UIScreen mainScreen] applicationFrame].size;

	/* main background view starts at 0,0, but actual content starts at 0,(app frame origin y to account for status bar/location warning) */
	self.view.frame = CGRectMake(0, 0, size.width, size.height + statusBarHeight);

	tabChooser.frame = CGRectMake(0, size.height - (TOOLBAR_HEIGHT + 20), self.view.frame.size.width, 24);

	UIWebView *wv = [[self curWebViewTab] webView];
	currentWebViewScrollOffsetY = wv.scrollView.contentOffset.y;


	navigationBar.frame = tabToolbar.frame = CGRectMake(0, statusBarHeight, self.view.frame.size.width, TOOLBAR_HEIGHT);
	bottomToolBar.frame = CGRectMake(0, self.view.frame.size.height - TOOLBAR_HEIGHT, size.width, TOOLBAR_HEIGHT);

	progressBar.frame = CGRectMake(0, navigationBar.frame.size.height - 2, navigationBar.frame.size.width, 2);

	tabScroller.frame = CGRectMake(0, navigationBar.frame.origin.y + navigationBar.frame.size.height, navigationBar.frame.size.width, self.view.frame.size.height - navigationBar.frame.size.height - bottomToolBar.frame.size.height - statusBarHeight);

	[self.view setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

	[tabScroller setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[tabToolbar setBarTintColor:[UIColor defaultNavigationControllerColor]];
	[navigationBar setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[urlField setBackgroundColor:[UIColor whiteColor]];
	[bottomToolBar setBarTintColor:[UIColor defaultNavigationControllerColor]];

	[tabAddButton setTintColor:[progressBar tintColor]];
	[tabDoneButton setTintColor:[progressBar tintColor]];
	[settingsButton setTintColor:[progressBar tintColor]];
	[tabsButton setTintColor:[progressBar tintColor]];
	[tabCount setTextColor:[progressBar tintColor]];

	[tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
	[tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];

	if(!showingTabs) {
		[self adjustWebViewTabsLayout];
	}

	tabScroller.contentSize = CGSizeMake(size.width * tabChooser.numberOfPages, tabScroller.frame.size.height);
	[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];

	urlField.frame = [self frameForUrlField];
	psiphonConnectionIndicator.frame = [self frameForConnectionIndicator];
	[self updateSearchBarDetails];

	if (bookmarks != nil && bookmarksViewBottom != nil) {
		bookmarksViewBottom.constant = keyboardHeight;
		[self.view layoutIfNeeded];
	}

	[self.view setNeedsDisplay];
}

- (CGRect)frameForTabIndex:(NSUInteger)number
{
	return CGRectMake((self.view.frame.size.width * number), 0, self.view.frame.size.width, tabScroller.frame.size.height);
}

- (CGRect) frameForConnectionIndicator {
	CGSize size = [[UIScreen mainScreen] applicationFrame].size;
	CGRect frame;
	if(isRTL) {
		frame = CGRectMake(size.width - TOOLBAR_HEIGHT + TOOLBAR_PADDING,
						   TOOLBAR_PADDING,
						   TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING,
						   TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING);
	} else {
		frame = CGRectMake(TOOLBAR_PADDING,
						   TOOLBAR_PADDING,
						   TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING,
						   TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING);
	}
	return frame;

}

- (CGRect)frameForUrlField
{
	float x;
	if(isRTL) {
		x = TOOLBAR_PADDING;
	} else {
		x = 2 * TOOLBAR_PADDING + TOOLBAR_BUTTON_SIZE;
	}
	float y = TOOLBAR_PADDING;
	float w = navigationBar.frame.size.width - 3 * TOOLBAR_PADDING - TOOLBAR_BUTTON_SIZE;
	if ([urlField isFirstResponder]) { // embedded bookmarks view is visible
		// create space for embedded bookmarks view cancel button
		if (isRTL) {
			x += kBookmarksCancelButtonWidth;
		}
		w -= kBookmarksCancelButtonWidth;
	}
	float h = TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING;
	return CGRectMake(x, y, w, h);
}

- (NSMutableArray *)webViewTabs
{
	return webViewTabs;
}

- (__strong WebViewTab *)curWebViewTab
{
	if (webViewTabs.count > 0)
		return webViewTabs[curTabIndex];
	else
		return nil;
}

- (long)curWebViewTabHttpsRulesCount
{
	return [[[self curWebViewTab] applicableHTTPSEverywhereRules] count];
}

- (void)setCurTabIndex:(int)tab
{
	curTabIndex = tab;
	tabChooser.currentPage = tab;

	if ([[self curWebViewTab] isRestoring]) {
		[[self curWebViewTab] refresh];
		[[self curWebViewTab] setIsRestoring:NO];
	}
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url
{
	return [self addNewTabForURL:url forRestoration:NO andFocus:YES withCompletionBlock:nil];
}

-(void) addWebViewTab:(WebViewTab*) wvt andSetCurrent:(BOOL)current{
	[wvt.webView.scrollView setDelegate:self];

	[webViewTabs addObject:wvt];
	[tabChooser setNumberOfPages:webViewTabs.count];
	[wvt setTabIndex:[NSNumber numberWithLong:(webViewTabs.count - 1)]];

	[tabCount setText:[NSString stringWithFormat:@"%lu", (long)tabChooser.numberOfPages]];

	[tabScroller setContentSize:CGSizeMake(wvt.viewHolder.frame.size.width * tabChooser.numberOfPages, wvt.viewHolder.frame.size.height)];
	[tabScroller addSubview:wvt.viewHolder];
	[tabScroller bringSubviewToFront:navigationBar];

	if(current) {
		[self setCurTabIndex:wvt.tabIndex.intValue];
	}

	CGSize size = [[UIScreen mainScreen] applicationFrame].size;
	tabScroller.contentSize = CGSizeMake(size.width * tabChooser.numberOfPages, tabScroller.frame.size.height);
	[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url forRestoration:(BOOL)restoration andFocus:(BOOL)focus withCompletionBlock:(void(^)(BOOL))block
{
	WebViewTab *wvt = [[WebViewTab alloc] initWithFrame:[self frameForTabIndex:webViewTabs.count] withRestorationIdentifier:(restoration ? [url absoluteString] : nil)];
	[wvt.webView.scrollView setDelegate:self];

	[webViewTabs addObject:wvt];
	[tabChooser setNumberOfPages:webViewTabs.count];
	[wvt setTabIndex:[NSNumber numberWithLong:(webViewTabs.count - 1)]];
	[wvt setUrl:url];

	[tabCount setText:[NSString stringWithFormat:@"%lu", (long)tabChooser.numberOfPages]];

	[tabScroller setContentSize:CGSizeMake(wvt.viewHolder.frame.size.width * tabChooser.numberOfPages, wvt.viewHolder.frame.size.height)];
	[tabScroller addSubview:wvt.viewHolder];
	[tabScroller bringSubviewToFront:navigationBar];

	if (showingTabs)
		[wvt zoomOut];


	void (^swapToTab)(BOOL) = ^(BOOL finished) {
		[self setCurTabIndex:(int)webViewTabs.count - 1];

		[self slideToCurrentTabWithCompletionBlock:^(BOOL finished) {
			if (url != nil)
				[wvt loadURL:url];

			[self showTabsWithCompletionBlock:block];
		}];
	};
	if (!restoration) {
		if(focus) {
			/* animate zooming out (if not already), switching to the new tab, then zoom back in */
			if (showingTabs) {
				swapToTab(YES);
			}
			else if (webViewTabs.count > 1) {
				[self showTabsWithCompletionBlock:swapToTab];
			}
			else if (url != nil) {
				[wvt loadURL:url];
			}
		} else if (url != nil) {
			[wvt loadURL:url];
		}
	}
	return wvt;
}

- (void)addNewTabFromToolbar:(id)_id
{
	//avoid capturing 'self'
	UITextField *localURLField = urlField;

	[self addNewTabForURL:nil forRestoration:NO andFocus:YES withCompletionBlock:^(BOOL finished) {
		[localURLField becomeFirstResponder];
	}];
}

- (void)removeTab:(NSNumber *)tabNumber
{
	[self removeTab:tabNumber andFocusTab:[NSNumber numberWithInt:-1]];
}

- (void)removeTabOpenedByHash:(NSNumber *)tabNumber
{
	[self removeTab:tabNumber];
	showingTabs = !showingTabs;
	[self showTabsWithCompletionBlock:nil];
}

- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus
{
	if (tabNumber.intValue > [webViewTabs count] - 1)
		return;

	WebViewTab *wvt = (WebViewTab *)webViewTabs[tabNumber.intValue];

#ifdef TRACE
	NSLog(@"removing tab %@ (%@) and focusing %@", tabNumber, wvt.title.text, toFocus);
#endif
	int futureFocusNumber = toFocus.intValue;
	if (futureFocusNumber > -1) {
		if (futureFocusNumber == tabNumber.intValue) {
			futureFocusNumber = -1;
		}
		else if (futureFocusNumber > tabNumber.intValue) {
			futureFocusNumber--;
		}
	}

	[[wvt viewHolder] removeFromSuperview];
	[webViewTabs removeObjectAtIndex:tabNumber.intValue];
	[wvt close];
	wvt = nil;

	[tabChooser setNumberOfPages:webViewTabs.count];
	[tabCount setText:[NSString stringWithFormat:@"%lu", (long)tabChooser.numberOfPages]];

	if (futureFocusNumber == -1) {
		if (curTabIndex == tabNumber.intValue) {
			if (webViewTabs.count > tabNumber.intValue && webViewTabs[tabNumber.intValue]) {
				/* keep currentPage pointing at the page that shifted down to here */
			}
			else if (tabNumber.intValue > 0 && webViewTabs[tabNumber.intValue - 1]) {
				/* removed last tab, keep the previous one */
				[self setCurTabIndex:tabNumber.intValue - 1];
			}
			else {
				/* no tabs left, add one and zoom out */

				//avoid capturing 'self'
				UITextField *localURLField = urlField;

				[self addNewTabForURL:nil forRestoration:NO andFocus:YES withCompletionBlock:^(BOOL finished) {
					[localURLField becomeFirstResponder];
				}];
				return;
			}
		}
	}
	else {
		[self setCurTabIndex:futureFocusNumber];
	}
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		tabScroller.contentSize = CGSizeMake(self.view.frame.size.width * tabChooser.numberOfPages, tabScroller.frame.size.height);

		for (int i = 0; i < webViewTabs.count; i++) {
			WebViewTab *wvt = webViewTabs[i];

			wvt.viewHolder.transform = CGAffineTransformIdentity;
			wvt.viewHolder.frame = [self frameForTabIndex:i];
			wvt.viewHolder.transform = CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE);
		}
	} completion:^(BOOL finished) {
		[self setCurTabIndex:curTabIndex];
	}];
}

- (void) setRestorationTabCurrent {
	if( [[self webViewTabs] count] > 0) {
		[self setCurTabIndex:curTabIndexFromRestoration];
	}
}

- (void) focusTab:(WebViewTab *)tab andRefresh:(BOOL)refresh animated:(BOOL)animated {
	int focusTabNumber = tab.tabIndex.intValue;
	[self setCurTabIndex:focusTabNumber];
	// Only force refresh tabs that are loaded.
	// Restoration tabs are refreshed when
	// they are switched to
	if(refresh && tab.url) {
		[tab forceRefresh];
	}
	if(animated) {
		[self slideToCurrentTabWithCompletionBlock:nil];
		if (showingTabs) {
			[self showTabsWithCompletionBlock:nil];
		}
	}

	[self adjustLayout];
}

- (void)removeAllTabs
{
	curTabIndex = 0;

	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = (WebViewTab *)webViewTabs[i];
		[[wvt viewHolder] removeFromSuperview];
		[wvt close];
	}

	[webViewTabs removeAllObjects];
	[tabChooser setNumberOfPages:0];

	[self updateSearchBarDetails];
}

// Remove all tabs and open a blank one
// with embedded bookmarks view visible.
- (void)removeAllTabsForBackgrounded {
	[self removeAllTabs];

	[self addNewTabForURL:nil forRestoration:NO andFocus:YES withCompletionBlock:nil];

	[urlField becomeFirstResponder];
}

- (void)updateSearchBarDetails
{
	/* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */

	[urlField setTextColor:[UIColor darkTextColor]];

	if (urlField.isFirstResponder) {
		/* focused, don't muck with the URL while it's being edited */
		[urlField setTextAlignment:NSTextAlignmentNatural];
		[urlField setLeftView:nil];
		[urlField setRightView:nil];
	}
	else {
		[urlField setTextAlignment:NSTextAlignmentCenter];
		[urlField setRightView:refreshButton];
		BOOL isEV = NO;
		if (self.curWebViewTab && self.curWebViewTab.secureMode >= WebViewTabSecureModeSecure) {
			[urlField setLeftView:lockIcon];

			if (self.curWebViewTab.secureMode == WebViewTabSecureModeSecureEV) {
				/* wait until the page is done loading */
				if ([progressBar progress] >= 1.0) {
					[urlField setTextColor:[UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0]];

					if ([self.curWebViewTab.SSLCertificate evOrgName] == nil)
						[urlField setText:NSLocalizedString(@"Unknown Organization", nil)];
					else
						[urlField setText:self.curWebViewTab.SSLCertificate.evOrgName];

					isEV = YES;
				}
			}
		}
		else if (self.curWebViewTab && self.curWebViewTab.secureMode == WebViewTabSecureModeMixed) {
			[urlField setLeftView:brokenLockIcon];
		}
		else {
			[urlField setLeftView:nil];
		}

		if (!isEV) {
			NSString *host;
			if (self.curWebViewTab.url == nil)
				host = @"";
			else {
				host = [self.curWebViewTab.url host];
				if (host == nil)
					host = [self.curWebViewTab.url absoluteString];
			}

			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
			NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];

			[urlField setText:hostNoWWW];

			if ([urlField.text isEqualToString:@""]) {
				[urlField setTextAlignment:NSTextAlignmentLeft];
			}
		}
	}

	backButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoBack);
	if (backButton.enabled) {
		[backButton setTintColor:[progressBar tintColor]];
	}
	else {
		[backButton setTintColor:[UIColor grayColor]];
	}

	forwardButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoForward);
	if (forwardButton.enabled) {
		[forwardButton setTintColor:[progressBar tintColor]];
	}
	else {
		[forwardButton setTintColor:[UIColor grayColor]];
	}

	[urlField setFrame:[self frameForUrlField]];
	[self showToolBars:YES];
}

- (void)updateProgress
{
	BOOL animated = YES;
	float fadeAnimationDuration = 0.15;
	float fadeOutDelay = 0.3;

	float progress = [[[self curWebViewTab] progress] floatValue];
	if (progressBar.progress == progress) {
		return;
	}
	else if (progress == 0.0) {
		/* reset without animation, an actual update is probably coming right after this */
		progressBar.progress = 0.0;
		return;
	}

#ifdef TRACE
	NSLog(@"[Tab %@] loading progress of %@ at %f", self.curWebViewTab.tabIndex, [self.curWebViewTab.url absoluteString], progress);
#endif

	[self updateSearchBarDetails];

	if (progress >= 1.0) {
		[progressBar setProgress:progress animated:NO];

		[UIView animateWithDuration:fadeAnimationDuration delay:fadeOutDelay options:UIViewAnimationOptionCurveLinear animations:^{
			progressBar.alpha = 0.0;
		} completion:^(BOOL finished) {
			[self updateSearchBarDetails];
		}];
	}
	else {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
			[progressBar setProgress:progress animated:YES];

			if (showingTabs)
				progressBar.alpha = 0.0;
			else
				progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)webViewTouched
{
	if ([urlField isFirstResponder]) {
		[urlField resignFirstResponder];
	}
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"started editing");
#endif

	[urlField setText:[self.curWebViewTab.url absoluteString]];

	if (bookmarks == nil) {
		bookmarks = [[BookmarkController alloc] init];
		bookmarks.embedded = true;

		[self addChildViewController:bookmarks];
		[self.view insertSubview:[bookmarks view] belowSubview:navigationBar];

		// Setup autolayout
		bookmarks.view.translatesAutoresizingMaskIntoConstraints = NO;
		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:bookmarks.view
															  attribute:NSLayoutAttributeTop
															  relatedBy:NSLayoutRelationEqual
																 toItem:navigationBar
															  attribute:NSLayoutAttributeBottom
															 multiplier:1.0f
															   constant:0.f]];

		bookmarksViewBottom = [NSLayoutConstraint constraintWithItem:bookmarks.view
														   attribute:NSLayoutAttributeBottom
														   relatedBy:NSLayoutRelationEqual
															  toItem:bottomToolBar
														   attribute:NSLayoutAttributeTop
														  multiplier:1.0f
															constant:keyboardHeight];
		[self.view addConstraint:bookmarksViewBottom];

		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:bookmarks.view
															  attribute:NSLayoutAttributeLeft
															  relatedBy:NSLayoutRelationEqual
																 toItem:self.view
															  attribute:NSLayoutAttributeLeft
															 multiplier:1.0f
															   constant:0.f]];

		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:bookmarks.view
															  attribute:NSLayoutAttributeRight
															  relatedBy:NSLayoutRelationEqual
																 toItem:navigationBar
															  attribute:NSLayoutAttributeRight
															 multiplier:1.0f
															   constant:0.f]];

		[self.view layoutIfNeeded];
	}

	if (bookmarksCancelButton == nil) {
		// Setup cancel button which dimisses embedded bookmarks view
		bookmarksCancelButton = [[UIButton alloc] init];
		[bookmarksCancelButton setTitle:NSLocalizedString(@"Cancel", @"Cancel button text which allows user to exit bookmarks view") forState:UIControlStateNormal];
		[bookmarksCancelButton.titleLabel setFont:[UIFont systemFontOfSize:20.0f]];
		[bookmarksCancelButton.titleLabel setAdjustsFontSizeToFitWidth:YES];
		[bookmarksCancelButton setTitleColor:[progressBar tintColor] forState:UIControlStateNormal];
		[bookmarksCancelButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];

		[bookmarksCancelButton addTarget:self
							action:@selector(dismissEmbeddedBookmarksView)
				  forControlEvents:UIControlEventTouchUpInside];

		bookmarksCancelButton.translatesAutoresizingMaskIntoConstraints = NO;
		[navigationBar addSubview:bookmarksCancelButton];

		// Autolayout
		[navigationBar addConstraint:[NSLayoutConstraint constraintWithItem:bookmarksCancelButton
																  attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
																  relatedBy:NSLayoutRelationEqual
																	 toItem:urlField
																  attribute:isRTL ? NSLayoutAttributeLeft : NSLayoutAttributeRight
																 multiplier:1.0f
																   constant:0.f]];

		CGFloat cancelButtonWidth = kBookmarksCancelButtonWidth;
		if (isRTL) {
			cancelButtonWidth += urlField.frame.origin.x;
		} else {
			cancelButtonWidth += self.view.frame.size.width - urlField.frame.origin.x - urlField.frame.size.width;
		}

		[navigationBar addConstraint:[NSLayoutConstraint constraintWithItem:bookmarksCancelButton
																  attribute:NSLayoutAttributeWidth
																  relatedBy:NSLayoutRelationEqual
																	 toItem:nil
																  attribute:NSLayoutAttributeNotAnAttribute
																 multiplier:1.0f
																   constant:cancelButtonWidth]];

		[navigationBar addConstraint:[NSLayoutConstraint constraintWithItem:bookmarksCancelButton
																  attribute:NSLayoutAttributeHeight
																  relatedBy:NSLayoutRelationEqual
																	 toItem:urlField
																  attribute:NSLayoutAttributeHeight
																 multiplier:1.0f
																   constant:0.f]];

		[navigationBar addConstraint:[NSLayoutConstraint constraintWithItem:bookmarksCancelButton
																  attribute:NSLayoutAttributeCenterY
																  relatedBy:NSLayoutRelationEqual
																	 toItem:urlField
																  attribute:NSLayoutAttributeCenterY
																 multiplier:1.0f
																   constant:0.f]];
	}

	// perform layout so we don't animate previous layout changes
	[self.view layoutIfNeeded];

	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[urlField setTextAlignment:NSTextAlignmentNatural];
		[urlField setFrame:[self frameForUrlField]];
	} completion:^(BOOL finished) {
		[urlField performSelector:@selector(selectAll:) withObject:nil afterDelay:0.1];
	}];

	[self updateSearchBarDetails];
}

- (void)dismissEmbeddedBookmarksView {
	[urlField resignFirstResponder]; // end editing
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField != nil && textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"ended editing with: %@", [textField text]);
#endif
	if (bookmarks != nil) {
		[[bookmarks view] removeFromSuperview];
		[bookmarks removeFromParentViewController];
		bookmarks = nil;
	}

	if (bookmarksCancelButton != nil) {
		[bookmarksCancelButton removeFromSuperview];
		bookmarksCancelButton = nil;
	}

	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[urlField setTextAlignment:NSTextAlignmentCenter];
		[urlField setFrame:[self frameForUrlField]];
	} completion:nil];

	[self updateSearchBarDetails];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField != urlField) {
		return YES;
	}

	[self prepareForNewURLFromString:urlField.text];

	return NO;
}

- (void)prepareForNewURLFromString:(NSString *)url
{
	// user is shifting to a new place, start with a blank list of equivalent URLs
	[[self curWebViewTab] clearEquivalentURLs];

	NSURL *enteredURL = [NSURL URLWithString:url];

	/* for some reason NSURL thinks "example.com:9091" should be "example.com" as the scheme with no host, so fix up first */
	if ([enteredURL host] == nil && [enteredURL scheme] != nil && [enteredURL resourceSpecifier] != nil)
		enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", url]];

	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""]) {
		/* no scheme so if it has a space or no dots, assume it's a search query */
		if ([url containsString:@" "] || ![url containsString:@"."]) {
			[[self curWebViewTab] searchFor:url];
			enteredURL = nil;
		}
		else
			enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", url]];
	}

	[urlField resignFirstResponder]; /* will unfocus and call textFieldDidEndEditing */

	if (enteredURL != nil) {
		[[self curWebViewTab] setUrl:enteredURL];
		[[self curWebViewTab] loadURL:enteredURL];
	}
}

- (void) adjustWebViewTabsLayout {
	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = webViewTabs[i];
		[wvt updateFrame:[self frameForTabIndex:i]];
	}
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView == tabScroller || showingTabs == YES) {
		return;
	}

	CGFloat contentOffsetY = scrollView.contentOffset.y;
	CGFloat scrollViewHeight = scrollView.frame.size.height;
	CGFloat scrollContentSizeHeight = scrollView.contentSize.height;

	if(scrollViewHeight >= scrollContentSizeHeight && isShowingToolBars) {
		return;
	}

	if (contentOffsetY < 0.0) {
		return;
	}

	if (self->currentWebViewScrollOffsetY >= contentOffsetY) {
		[self showToolBars:YES];
	}
	else {
		[self showToolBars:NO];
	}

	// check if scrolled beyond the scrollView bounds
	if(contentOffsetY + scrollViewHeight < scrollContentSizeHeight) {
		self->currentWebViewScrollOffsetY = contentOffsetY;
	}
}

- (void)goBack:(id)_id
{
	[self.curWebViewTab goBack];
}

- (void)goForward:(id)_id
{
	[self.curWebViewTab goForward];
}

- (void)refresh
{
	[[self curWebViewTab] refresh];
}

- (void)forceRefresh
{
	[[self curWebViewTab] forceRefresh];
}

- (void)openSettingsMenu:(id)_id
{
	// Take a snapshot of current user settings
	preferencesSnapshot = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];

	if (appSettingsViewController == nil) {
		appSettingsViewController = [[SettingsViewController alloc] init];
		appSettingsViewController.delegate = appSettingsViewController;
		appSettingsViewController.showCreditsFooter = NO;
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.webViewController = self;
		appSettingsViewController.neverShowPrivacySettings = YES;
	}

	// These keys correspond to settings in PsiphonOptions.plist
	BOOL upstreamProxyEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kUseUpstreamProxy];
	BOOL useUpstreamProxyAuthentication = upstreamProxyEnabled && [[NSUserDefaults standardUserDefaults] boolForKey:kUseProxyAuthentication];

	NSArray *upstreamProxyKeys = [NSArray arrayWithObjects:kUpstreamProxyHostAddress, kUpstreamProxyPort, kUseProxyAuthentication, nil];
	NSArray *proxyAuthenticationKeys = [NSArray arrayWithObjects:kProxyUsername, kProxyPassword, kProxyDomain, nil];

	// Hide configurable fields until user chooses to use upstream proxy
	NSMutableSet *hiddenKeys = upstreamProxyEnabled ? nil : [NSMutableSet setWithArray:upstreamProxyKeys];

	// Hide authentication fields until user chooses to use upstream proxy with authentication
	if (!useUpstreamProxyAuthentication) {
		if (hiddenKeys == nil) {
			hiddenKeys = [NSMutableSet setWithArray:proxyAuthenticationKeys];
		} else {
			[hiddenKeys addObjectsFromArray:proxyAuthenticationKeys];
		}
	}

	appSettingsViewController.hiddenKeys = hiddenKeys;

	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];

	__weak WebViewController* weakSelf = self;

	if([self presentedViewController] == nil) {
		[self presentViewController:navController animated:YES completion:nil];
	} else {
		[self dismissViewControllerAnimated:NO completion:^{
			[weakSelf presentViewController:navController animated:YES completion:nil];
		}];
	}
}

- (void)settingsViewControllerDidEnd
{
	// Allow ARC to dealloc appSettingsViewController
	appSettingsViewController = nil;

	// Update relevant ivars to match current settings
	[CookieJar syncCookieAcceptPolicy];

	// Check if settings which have changed require setting up JAHPQNSURLSessionDemux
	// singleton with new NSURLSessionConfiguration object
	if ([self isURLSessionResetRequired]) {
		[JAHPAuthenticatingHTTPProtocol resetSharedDemux];
	}

	// Check if settings which have changed require a tunnel service restart to take effect
	if ([self isSettingsRestartRequired]) {
		[[AppDelegate sharedAppDelegate] scheduleRunningTunnelServiceRestart];
	}
	// Check if settings which have changed require reload tabs
	if ([self isTabsReloadRequired]) {
		for (int i = 0; i < webViewTabs.count; i++) {
			[(WebViewTab *)webViewTabs[i] refresh];
		}
	}
}

- (BOOL) isURLSessionResetRequired {
	if (preferencesSnapshot) {
		// Check if "min TLS" has changed
		NSString* oldMinTLS = [preferencesSnapshot objectForKey:kMinTlsVersion];
		NSString* newMinTLS = [[NSUserDefaults standardUserDefaults] objectForKey:kMinTlsVersion];

		if (!safeStringsEqual(oldMinTLS, newMinTLS)) {
			return YES;
		}
	}
	return NO;
}

- (BOOL) isTabsReloadRequired {
	if (preferencesSnapshot) {
		// Check if "disable Javascript" has changed
		BOOL disableJavascript = [[preferencesSnapshot objectForKey:kDisableJavascript] boolValue];

		if (disableJavascript != [[NSUserDefaults standardUserDefaults] boolForKey:kDisableJavascript]) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)isSettingsRestartRequired
{
	UpstreamProxySettings *proxySettings = [UpstreamProxySettings sharedInstance];

	if (preferencesSnapshot) {
		// Check if "disable timeouts" has changed
		BOOL disableTimeouts = [[preferencesSnapshot objectForKey:kDisableTimeouts] boolValue];

		if (disableTimeouts != [[NSUserDefaults standardUserDefaults] boolForKey:kDisableTimeouts]) {
			return YES;
		}

		// Check if the selected region has changed
		NSString *region = [preferencesSnapshot objectForKey:kRegionSelectionSpecifierKey];

		if (!safeStringsEqual(region, [[RegionAdapter sharedInstance] getSelectedRegion].code)) {
			return YES;
		}

		// Check if "use proxy" has changed
		BOOL useUpstreamProxy = [[preferencesSnapshot objectForKey:kUseUpstreamProxy] boolValue];

		if (useUpstreamProxy != [proxySettings getUseCustomProxySettings]) {
			return YES;
		}

		// No further checking if "use proxy" is off and has not
		// changed
		if (!useUpstreamProxy) {
			return NO;
		}

		// If "use proxy" is selected, check if host || port have changed
		NSString *hostAddress = [preferencesSnapshot objectForKey:kUpstreamProxyHostAddress];
		NSString *proxyPort = [preferencesSnapshot objectForKey:kUpstreamProxyPort];

		if (!safeStringsEqual(hostAddress, [proxySettings getCustomProxyHost]) || !safeStringsEqual(proxyPort, [proxySettings getCustomProxyPort])) {
			return YES;
		}

		// Check if "use proxy authentication" has changed
		BOOL useProxyAuthentication = [[preferencesSnapshot objectForKey:kUseProxyAuthentication] boolValue];

		if (useProxyAuthentication != [proxySettings getUseProxyAuthentication]) {
			return YES;
		}

		// No further checking if "use proxy authentication" is off
		// and has not changed
		if (!useProxyAuthentication) {
			return NO;
		}

		// "use proxy authentication" is checked, check if
		// username || password || domain have changed
		NSString *username = [preferencesSnapshot objectForKey:kProxyUsername];
		NSString *password = [preferencesSnapshot objectForKey:kProxyPassword];
		NSString *domain = [preferencesSnapshot objectForKey:kProxyDomain];

		if (!safeStringsEqual(username,[proxySettings getProxyUsername]) ||
			!safeStringsEqual(password, [proxySettings getProxyPassword]) ||
			!safeStringsEqual(domain, [proxySettings getProxyDomain])) {
			return YES;
		}
	}
	return NO;
}

- (void)showTabs:(id)_id
{
	return [self showTabsWithCompletionBlock:nil];
}

- (void)showTabsWithCompletionBlock:(void(^)(BOOL))block
{
	if (showingTabs == false) {
		/* zoom out */

		/* make sure no text is selected */
		[urlField resignFirstResponder];

		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++) {
				[(WebViewTab *)webViewTabs[i] zoomOut];
			}

			tabChooser.hidden = false;
			navigationBar.hidden = true;
			tabToolbar.hidden = false;
			progressBar.alpha = 0.0;
		} completion:block];

		tabScroller.contentOffset = CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0);
		tabScroller.scrollEnabled = YES;
		tabScroller.pagingEnabled = YES;

		UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOnWebViewTab:)];
		singleTapGestureRecognizer.numberOfTapsRequired = 1;
		singleTapGestureRecognizer.enabled = YES;
		singleTapGestureRecognizer.cancelsTouchesInView = NO;
		[tabScroller addGestureRecognizer:singleTapGestureRecognizer];

		tabSelectionPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
		[tabSelectionPanGestureRecognizer setMinimumNumberOfTouches:1];
		[tabSelectionPanGestureRecognizer setMaximumNumberOfTouches:1];
		[tabScroller addGestureRecognizer:tabSelectionPanGestureRecognizer];
	}
	else {
		[tabScroller removeGestureRecognizer:tabSelectionPanGestureRecognizer];
		tabSelectionPanGestureRecognizer = nil;
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++) {
				[(WebViewTab *)webViewTabs[i] zoomNormal];
			}

			tabChooser.hidden = true;
			navigationBar.hidden = false;
			tabToolbar.hidden = true;
			progressBar.alpha = (progressBar.progress > 0.0 && progressBar.progress < 1.0 ? 1.0 : 0.0);
		} completion:block];

		tabScroller.scrollEnabled = NO;
		tabScroller.pagingEnabled = NO;

		[self updateSearchBarDetails];
	}

	showingTabs = !showingTabs;
}

- (void)doneWithTabsButton:(id)_id
{
	[self showTabs:nil];
}

- (void) addBookmarkFromBottomToolbar:(id)_id {
	BookmarkController *bc = [[BookmarkController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bc];
	[self presentViewController:navController animated:YES completion:nil];
}


- (void)showSSLCertificate
{
	if ([[self curWebViewTab] SSLCertificate] == nil)
		return;

	SSLCertificateViewController *scvc = [[SSLCertificateViewController alloc] initWithSSLCertificate:[[self curWebViewTab] SSLCertificate]];
	scvc.title = [[[self curWebViewTab] url] host];

	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:scvc];
	[self presentViewController:navController animated:YES completion:nil];
}

- (void)tappedOnNavBar:(UITapGestureRecognizer *)gesture
{
	CGPoint point = [gesture locationInView:navigationBar];

	// Make targets vertically flush with the navigation bar
	// and fuzz slightly horizontally for easier interaction.

	CGRect connectionIndicatorTarget = CGRectMake(isRTL ? urlField.frame.origin.x + urlField.frame.size.width : 0, 0, isRTL ? navigationBar.frame.size.width - (urlField.frame.origin.x + urlField.frame.size.width) : urlField.frame.origin.x, navigationBar.frame.size.height);

	CGRect lockTarget = CGRectZero;
	if (urlField.leftView != nil) {
		CGRect lockFrame = [urlField convertRect:urlField.leftView.frame toView:navigationBar];
		lockTarget = CGRectMake(lockFrame.origin.x, 0, lockFrame.size.width, navigationBar.frame.size.height);
	}

	CGRect refreshTarget = CGRectZero;
	if (urlField.rightView != nil) {
		CGRect refreshFrame = [urlField convertRect:urlField.rightView.frame toView:navigationBar];
		refreshTarget = CGRectMake(isRTL ? 0 : refreshFrame.origin.x - 15, 0, isRTL ? refreshFrame.origin.x + refreshFrame.size.width + 15 : navigationBar.frame.size.width - refreshFrame.origin.x + 15, navigationBar.frame.size.height);
	}

	CGRect urlFieldTarget = CGRectMake(urlField.frame.origin.x, 0, navigationBar.frame.size.width - urlField.frame.origin.x, navigationBar.frame.size.height);

	if (CGRectContainsPoint(connectionIndicatorTarget, point)) {
		[self showPsiphonConnectionStatusAlert];
	} else if (CGRectContainsPoint(lockTarget, point)) {
		[self showSSLCertificate];
	} else if (CGRectContainsPoint(refreshTarget, point)) {
		[self forceRefresh];
	} else if (CGRectContainsPoint(urlFieldTarget, point)) {
		[urlField becomeFirstResponder];
	}
}

- (void)tappedOnPageControlDot:(id)sender {
	UIPageControl *pager = sender;
	NSInteger page = pager.currentPage;
	[tabChooser setCurrentPage:page];
	curTabIndex = (int)page;
	CGRect frame = tabScroller.frame;
	frame.origin.x = frame.size.width * page;
	frame.origin.y = 0;
	[tabScroller setContentOffset:frame.origin animated:YES];
}

- (void)tappedOnWebViewTab:(UITapGestureRecognizer *)gesture
{
	if (!showingTabs) {
		if ([urlField isFirstResponder]) {
			[urlField resignFirstResponder];
		}

		return;
	}

	CGPoint point = [gesture locationInView:self.curWebViewTab.viewHolder];

	/* fuzz a bit to make it easier to tap */
	int fuzz = 40;
	CGRect closerFrame = CGRectMake(self.curWebViewTab.closer.frame.origin.x - fuzz, self.curWebViewTab.closer.frame.origin.y - fuzz, self.curWebViewTab.closer.frame.size.width + (fuzz * 2), self.curWebViewTab.closer.frame.size.width + (fuzz * 2));

	if (CGRectContainsPoint(closerFrame, point)) {
		[self removeTab:[NSNumber numberWithLong:curTabIndex]];
	}
	else {
		[self showTabs:nil];
	}
}

- (void)slideToCurrentTabWithCompletionBlock:(void(^)(BOOL))block
{
	[self updateProgress];

	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
	} completion:block];
}

- (IBAction)slideToCurrentTab:(id)_id
{
	[self slideToCurrentTabWithCompletionBlock:nil];
}

- (NSString *)buildDefaultUserAgent
{
	/*
	 * Some sites do mobile detection by looking for Safari in the UA, so make us look like Mobile Safari
	 *
	 * from "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H321"
	 * to   "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12H321 Safari/600.1.4"
	 */

	UIWebView *twv = [[UIWebView alloc] initWithFrame:CGRectZero];
	NSString *ua = [twv stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];

	NSMutableArray *uapieces = [[NSMutableArray alloc] initWithArray:[ua componentsSeparatedByString:@" "]];
	NSString *uamobile = uapieces[uapieces.count - 1];

	/* assume safari major version will match ios major */
	NSArray *osv = [[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."];
	uapieces[uapieces.count - 1] = [NSString stringWithFormat:@"Version/%@.0", osv[0]];

	[uapieces addObject:uamobile];

	/* now tack on "Safari/XXX.X.X" from webkit version */
	for (id j in uapieces) {
		if ([(NSString *)j containsString:@"AppleWebKit/"]) {
			[uapieces addObject:[(NSString *)j stringByReplacingOccurrencesOfString:@"AppleWebKit" withString:@"Safari"]];
			break;
		}
	}

	return [uapieces componentsJoinedByString:@" "];
}

- (void) psiphonConnectionStateNotified:(NSNotification *)notification
{
	ConnectionState state = [[notification.userInfo objectForKey:kPsiphonConnectionState] unsignedIntegerValue];
	[psiphonConnectionIndicator displayConnectionState:state];
	if(state != ConnectionStateConnected) {
		[self stopLoading];
	} else {
		for (WebViewTab *wvt in webViewTabs) {
			if ([wvt shouldReloadOnConnected]) {
				[wvt refresh];
				[wvt setShouldReloadOnConnected:NO];
			}
		}
	}
}

- (void) stopLoading
{
	for (WebViewTab *wvt in webViewTabs) {
		if (wvt.webView.isLoading) {
			[wvt.webView stopLoading];
			[wvt setProgress:@(0.0f)];
		}
	}
	[self updateProgress];
}

#pragma mark - Tutorial Delegate Methods

- (CGRect)getBottomToolbarFrame {
	return [self.view convertRect:bottomToolBar.frame toView:self.view];;
}

- (CGRect)getConnectionIndicatorFrame {
	return [self.view convertRect:psiphonConnectionIndicator.frame fromView:navigationBar];
}

- (CGRect)getCurrentSpotlightFrame:(NSUInteger)page
{
	int radius = psiphonConnectionIndicator.frame.size.width * 1.2;

	if (page == PsiphonTutorialPage1Index) {
		return CGRectMake(psiphonConnectionIndicator.frame.origin.x - (radius - psiphonConnectionIndicator.frame.size.width / 2), psiphonConnectionIndicator.frame.origin.y + navigationBar.frame.origin.y - (radius - psiphonConnectionIndicator.frame.size.height / 2), radius * 2.0, radius * 2.0);
	} else if (page == PsiphonTutorialPage2Index) {
		return CGRectMake(bottomToolBar.frame.size.width / 2 - radius, self.view.frame.size.height - bottomToolBar.frame.size.height / 2 - radius, radius * 2.0, radius * 2.0);
	}
	return CGRectNull;
}

- (CGRect)getSkipButtonFrame {
	return [navigationBar convertRect:urlField.frame toView:self.view];
}

- (void)moveToStep:(NSInteger)step {
	// Stop cycling connection indicator
	[self resetConnectionStateCycler];

	if (step == PsiphonTutorialPage1Index) {
		/* Tutorial highlights psiphon connection indicator */
		// Reset indicator state
		[self cycleConnectionStateForTutorial];
		// Cycle connection indicator to show user different connection states
		tutorial.connectionStateCycler = [NSTimer scheduledTimerWithTimeInterval:1.4
																		  target:self
																		selector:@selector(cycleConnectionStateForTutorial)
																		userInfo:nil
																		 repeats:YES];
	} else if (step == PsiphonTutorialPage2Index) {
		/* Tutorial highlights settings button */
	} else if (step == PsiphonTutorialPage3Index) {
		/* Tutorial goodbye with no spotlight */
	} else if (step >= PsiphonTutorialPageFinalIndex) {
		[self tutorialEnded];
	}
}

- (void)tutorialEnded
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if (![userDefaults boolForKey:kHasBeenOnboardedKey]) {
		[Bookmark addDefaultBookmarks];
		[[UIApplication sharedApplication] setStatusBarHidden:NO]; // Exit full screen
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasBeenOnboardedKey];
	}

	self.showTutorial = NO;

	// Remove from view
	[tutorial.view removeFromSuperview];
	[tutorial removeFromParentViewController];
	[tutorial didMoveToParentViewController:nil];

	// Stop cycling connection indicator if tutorial was skipped
	[self resetConnectionStateCycler];
	tutorial = nil;

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(psiphonConnectionStateNotified:) name:kPsiphonConnectionStateNotification object:nil];

	// Since we have modified the psiphonConnectionIndicator's state manually for the tutorial
	// we need to ensure it gets reset to display the correct state
	[[AppDelegate sharedAppDelegate] notifyConnectionState];

	if (self.resumePsiphonStart) {
		// Resume setup
		// Start psiphon and open homepage
		[[AppDelegate sharedAppDelegate] startPsiphonOnlyIfNeeded:YES];
		[self viewIsVisible];
	} else {
		[self dismissViewControllerAnimated:NO completion:nil];
	}
}

#pragma mark - Tutorial methods and helper functions

- (void)resetConnectionStateCycler {
	if (tutorial != nil && tutorial.connectionStateCycler != nil) {
		[tutorial.connectionStateCycler invalidate];
		tutorial.connectionStateCycler = nil;
	}
	[psiphonConnectionIndicator displayConnectionState:ConnectionStateConnected];
}

- (void)cycleConnectionStateForTutorial {
	static NSInteger state = 0;

	// Timer will be created or restarted
	if (tutorial != nil && tutorial.connectionStateCycler == nil) {
		state = 0;
	}

	// Connection indicator will start on the disconnected state
	switch (state % 3) {
		case 0:
			[psiphonConnectionIndicator displayConnectionState:ConnectionStateDisconnected];
			break;
		case 1:
			[psiphonConnectionIndicator displayConnectionState:ConnectionStateConnecting];
			break;
		case 2:
			[psiphonConnectionIndicator displayConnectionState:ConnectionStateConnected];
			break;
		default:
			break;
	}
	state += 1;
}

- (void)overlayTutorial
{
	// Unsubscribe from psiphonConnectionState notifications
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:kPsiphonConnectionStateNotification object:nil];

	// Init tutorial
	tutorial = [[TutorialViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	tutorial.webViewController = self;

	[self addChildViewController:tutorial];
	[self.view addSubview:tutorial.view];
	[tutorial didMoveToParentViewController:self];

	// Setup constraints
	tutorial.view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.view
														  attribute:NSLayoutAttributeLeft
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeLeft
														 multiplier:1.f constant:0.f]];
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.view
														  attribute:NSLayoutAttributeRight
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeRight
														 multiplier:1.f constant:0.f]];
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.view
														  attribute:NSLayoutAttributeTop
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeTop
														 multiplier:1.f constant:0.f]];
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.view
														  attribute:NSLayoutAttributeBottom
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeBottom
														 multiplier:1.f constant:0.f]];
}

- (void)showPsiphonConnectionStatusAlert {
	PsiphonConnectionAlertViewController *connectionAlertViewController = [[PsiphonConnectionAlertViewController alloc]
																		   initWithState:[[AppDelegate sharedAppDelegate] getConnectionState]];
	connectionAlertViewController.delegate = self;

	__weak  WebViewController *weakSelf = self;
	__weak  PsiphonConnectionAlertViewController *weakConnectionAlertViewController = connectionAlertViewController;

	[connectionAlertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Settings", nil)
																	  style:UIAlertActionStyleDefault
																	handler:^(NYAlertAction *action) {
																		[weakSelf openSettingsMenu:nil];
																	}]];

	[connectionAlertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Done", nil)
																	  style:UIAlertActionStyleDefault
																	handler:^(NYAlertAction *action) {
																		[weakConnectionAlertViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
																	}]];

	[self  presentViewController:connectionAlertViewController animated:NO
					  completion:^(){[[AppDelegate sharedAppDelegate] notifyConnectionState];}];
}

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
	if (showingTabs) {
		CGPoint vel = [gesture velocityInView:tabScroller];

		if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_NONE) {
			if ((fabs(vel.y) > fabs(vel.x) && vel.y < -50) || webViewTabs.count == 1) {
				// We only care about speed < 0 because the user needs to swipe up to close the tab
				/* User is trying to remove a tab */
				panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_UP;
				originalPoint = [[(WebViewTab *)webViewTabs[curTabIndex] viewHolder] center];
			} else if (fabs(vel.x) > fabs(vel.y) && fabs(vel.x) > 50) {
				/* User is trying to change page */
				panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_SIDE;
			}
		}

		if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_SIDE) {
			CGFloat xDistance = [gesture translationInView:tabScroller].x;

			switch (gesture.state) {
				case UIGestureRecognizerStateChanged: {
					CGRect frame = tabScroller.frame;
					frame.origin.x = frame.size.width * curTabIndex;
					frame.origin.y = 0;

					if (xDistance < 0 && curTabIndex == tabChooser.numberOfPages - 1) {
						// There is not tab on the right, change speed accordingly
						xDistance = -powf(MAX(0.0f, -xDistance), 0.75f);
					} else if (xDistance > 0 && curTabIndex == 0) {
						// There is not tab on the left, change speed accordingly
						xDistance = powf(MAX(0.0f, xDistance), 0.75f);
					}

					[tabScroller setContentOffset:CGPointMake(frame.origin.x - xDistance, frame.origin.y) animated:NO];
					break;
				};

				case UIGestureRecognizerStateEnded: {
					if ((xDistance <= -100 || vel.x <= -300) && curTabIndex < tabChooser.numberOfPages - 1) {
						// Moved enough to change page (go right), and there is at least 1 page on the right
						[tabChooser setCurrentPage:curTabIndex + 1];
						curTabIndex += 1;
						[self setCurTabIndex:curTabIndex];
					} else if ((xDistance >= 100 || vel.x >= 300) && curTabIndex > 0) {
						// Moved enough to change page (go left), and there is at least 1 page on the left
						[tabChooser setCurrentPage:curTabIndex - 1];
						curTabIndex -= 1;
						[self setCurTabIndex:curTabIndex];
					}

					// If the page index wasn't changed, it will just scroll back to the page's original position
					CGRect frame = tabScroller.frame;
					frame.origin.x = frame.size.width * curTabIndex;
					frame.origin.y = 0;
					[tabScroller setContentOffset:frame.origin animated:YES];

					panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;

					break;
				};

				case UIGestureRecognizerStateCancelled: {
					CGRect frame = tabScroller.frame;
					frame.origin.x = frame.size.width * curTabIndex;
					frame.origin.y = 0;
					[tabScroller setContentOffset:frame.origin animated:YES];

					panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;

					break;
				}

				default: break;
			}

		} else if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_UP) {
			CGFloat yDistance = [gesture translationInView:tabScroller].y;
			UIView *tabView = [(WebViewTab *)webViewTabs[curTabIndex] viewHolder];

			switch (gesture.state) {
				case UIGestureRecognizerStateChanged: {
					if (yDistance <= 0) {
						tabView.center = CGPointMake(originalPoint.x, originalPoint.y + yDistance);
					} else {
						tabView.center = originalPoint;
					}

					break;
				};
				case UIGestureRecognizerStateEnded: {
					if (-yDistance <= self.view.frame.size.height / 3 && vel.y >= -1500) {
						// Moved the view less than 1/4th of the view height, or is moving fast enough to consider the user wants to close
						[UIView animateWithDuration:0.5 animations:^{
							[tabView setCenter:originalPoint];
						} completion:^(BOOL finished) {}];
					} else {
						[UIView animateWithDuration:0.2 animations:^{
							[tabView setCenter:CGPointMake(originalPoint.x, -originalPoint.y)];
						} completion:^(BOOL finished) {
							// [self removeWithoutFocusingTab:[NSNumber numberWithLong:curTabIndex]];
							[self removeTab:[NSNumber numberWithLong:curTabIndex]];
						}];
					}
					panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;

					break;
				};

				case UIGestureRecognizerStateCancelled: {
					// Move the view back to the original point
					[UIView animateWithDuration:0.5 animations:^{
						[tabView setCenter:originalPoint];
					} completion:^(BOOL finished) {}];
					panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;

					break;
				}


				default: break;
			}
		}

	}
}

#pragma mark RegionSelectionControllerDelegate method implementation
- (void) regionSelectionControllerWillStart {
	// Take a snapshot of current user settings
	preferencesSnapshot = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
}

- (void) regionSelectionControllerDidEnd {
	if (preferencesSnapshot) {
		// Check if the selected region has changed
		NSString *region = [preferencesSnapshot objectForKey:kRegionSelectionSpecifierKey];

		if (!safeStringsEqual(region, [[RegionAdapter sharedInstance] getSelectedRegion].code)) {
			[[AppDelegate sharedAppDelegate] scheduleRunningTunnelServiceRestart];
		}
	}
}

- (void) openPsiphonHomePage:(NSString *) homePageURLString {

	// only add this url key if it is not in the home pages map already
	// to make sure we are not overiding equivalent urls values
	PsiphonHomePagesEquivalentURLs *homePagesEquivalentURLs = [PsiphonHomePagesEquivalentURLs sharedInstance];
	if([homePagesEquivalentURLs objectForKey:homePageURLString] == nil) {
		[homePagesEquivalentURLs addNewHomePagesEquivalentURLKey:homePageURLString];
	}

	// try to find an open tab with either a selected home page URL or one of the equivalent URLs loaded
	BOOL found = false;

	NSURL *homePageURL = [NSURL URLWithString:homePageURLString];

	for (WebViewTab *wvt in [self webViewTabs]) {
		if ([wvt.url isEqual:homePageURL] || [wvt.webView.restorationIdentifier isEqual:homePageURLString]) {
			// we have a tab with the URL same as home pages map key
			found = true;
		} else {
			// otherwise iterate over the equivalent URLs array for this key
			NSArray *equivURLs = [homePagesEquivalentURLs objectForKey:homePageURLString];
			for (NSString* equivURLString in equivURLs) {
				NSURL *equivURL = [NSURL URLWithString:equivURLString];
				if ([wvt.url isEqual:equivURL] || [wvt.webView.restorationIdentifier isEqual:equivURLString]) {
					found = true;
					break;
				}
			}
		}
		if(found) {
			[self focusTab:wvt andRefresh:YES animated:YES];
			// Do not check other tabs if we got at least one
			break;
		}
	}

	if(!found) {
		WebViewTab* wvt = [self addNewTabForURL: homePageURL];
		wvt.finalPageObserverDelegate = self;
	}
}

# pragma mark - FinalPageObserver protocol implementation
-(void) seenFinalPage: (NSArray*) equivURLs {
	// the tab we are observing is signaling us that
	// the page has been finally loaded in the browser,
	// equivURLs is an array of all equivalent URLs for this page.
	if (!equivURLs || [equivURLs count] == 0) {
		// this shouldn't happen
#ifdef TRACE
		NSLog(@"[AppDelegate] seenFinalPage called but array of equivalent URLs is empty!");
#endif
		return;
	}

	if([equivURLs count] == 1) {
		// Single URL in the array means there were no redirects for the original URL.
		// Do nothing, we already have this URL in the homePagesEquivalentURLs map
		return;
	}

	NSString *originalURL = [equivURLs objectAtIndex:0];

	// only update equvalent URLs for existing home pages
	PsiphonHomePagesEquivalentURLs *homePagesEquivalentURLs = [PsiphonHomePagesEquivalentURLs sharedInstance];
	if ([homePagesEquivalentURLs objectForKey:originalURL] != nil) {
		NSMutableArray *newEquivURLs = [NSMutableArray arrayWithArray:equivURLs];
		[newEquivURLs removeObjectAtIndex:0];
		[homePagesEquivalentURLs setObject:newEquivURLs forKey:originalURL];
	}
}

@end
