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
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */


#import <Photos/Photos.h>
#import "PsiphonData.h"
#import "JAHPAuthenticatingHTTPProtocol.h"
#import "WebViewTab.h"

#import "NSString+JavascriptEscape.h"

@import WebKit;

@implementation WebViewTab {
	NSMutableArray *equivalentURLS;

	BOOL isRTL;

	// For downloads
	NSURL *downloadedFile;
	QLPreviewController *previewController;
	UIView *downloadPreview;
	UIDocumentInteractionController *documentInteractionController;
	UIView *previewControllerOverlay;
}

- (id)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame withRestorationIdentifier:nil];
}

- (id)initWithFrame:(CGRect)frame withRestorationIdentifier:(NSString *)rid
{
	self = [super init];

	_viewHolder = [[UIView alloc] initWithFrame:frame];

	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	/* re-register user agent with our hash, which should only affect this UIWebView */
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"UserAgent": [NSString stringWithFormat:@"%@/%lu", [[AppDelegate sharedAppDelegate] defaultUserAgent], (unsigned long)self.hash] }];

	_webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	_isRestoring = NO;
	_shouldReloadOnConnected = NO;
	if (rid != nil) {
		[_webView setRestorationIdentifier:rid];
		[self setIsRestoring:YES];
	}
	[_webView setDelegate:self];
	[_webView setScalesPageToFit:YES];
	[_webView setAutoresizesSubviews:YES];
	[_webView setAllowsInlineMediaPlayback:YES];

	[_webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
	[_webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webKitprogressEstimateChanged:) name:@"WebProgressEstimateChangedNotification" object:[_webView valueForKeyPath:@"documentView.webView"]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(psiphonConnectionStateNotified:) name:kPsiphonConnectionStateNotification object:nil];


	/* swiping goes back and forward in current webview */
	UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRightAction:)];
	[swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
	[swipeRight setDelegate:self];
	[self.webView addGestureRecognizer:swipeRight];

	UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeftAction:)];
	[swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
	[swipeLeft setDelegate:self];
	[self.webView addGestureRecognizer:swipeLeft];

	self.refresher = [[UIRefreshControl alloc] init];
	[self.refresher addTarget:self action:@selector(forceRefreshFromRefresher) forControlEvents:UIControlEventValueChanged];
	[self.webView.scrollView addSubview:self.refresher];

	_titleHolder = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_titleHolder setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.75]];

	_title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_title setTextColor:[UIColor whiteColor]];
	[_title setFont:[UIFont boldSystemFontOfSize:16.0]];
	[_title setLineBreakMode:NSLineBreakByTruncatingTail];
	[_title setTextAlignment:NSTextAlignmentCenter];

	_closer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_closer setTextColor:[UIColor whiteColor]];
	[_closer setFont:[UIFont systemFontOfSize:24.0]];
	[_closer setText:[NSString stringWithFormat:@"%C", 0x2715]];
	[_closer setTextAlignment:NSTextAlignmentCenter];
	[_closer setAdjustsFontSizeToFitWidth:YES];

	[_viewHolder addSubview:_titleHolder];
	[_viewHolder addSubview:_title];
	[_viewHolder addSubview:_closer];
	[_viewHolder addSubview:_webView];

	// Setup autolayout for closer (close tab 'X' in all-tabs view)
	_closer.translatesAutoresizingMaskIntoConstraints = NO;

	// Center vertically in titleHolder
	[_viewHolder addConstraint:[NSLayoutConstraint constraintWithItem:_closer
															attribute:NSLayoutAttributeCenterY
															relatedBy:NSLayoutRelationEqual
															   toItem:_titleHolder
															attribute:NSLayoutAttributeCenterY
														   multiplier:1.0f
															 constant:0.f]];

	// closer.height == titleHolder.height * 0.8
	[_viewHolder addConstraint:[NSLayoutConstraint constraintWithItem:_closer
															attribute:NSLayoutAttributeHeight
															relatedBy:NSLayoutRelationEqual
															   toItem:_titleHolder
															attribute:NSLayoutAttributeHeight
														   multiplier:.8f
															 constant:0.f]];

	// closer.width == closer.height
	[_viewHolder addConstraint:[NSLayoutConstraint constraintWithItem:_closer
															attribute:NSLayoutAttributeWidth
															relatedBy:NSLayoutRelationEqual
															   toItem:_closer
															attribute:NSLayoutAttributeHeight
														   multiplier:1.f
															 constant:0.f]];

	// isRTL == false -> closer.left == titleHolder.left + 3
	// isRTL == true -> closer.right == titleHolder.right - 3
	[_viewHolder addConstraint:[NSLayoutConstraint constraintWithItem:_closer
															attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
															relatedBy:NSLayoutRelationEqual
															   toItem:_titleHolder
															attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
														   multiplier:1.f
															 constant:isRTL ? -3.f : 3.f]];

	/* setup shadow that will be shown when zooming out */
	[[_viewHolder layer] setMasksToBounds:NO];
	[[_viewHolder layer] setShadowOffset:CGSizeMake(0, 0)];
	[[_viewHolder layer] setShadowRadius:8];
	[[_viewHolder layer] setShadowOpacity:0];

	_progress = @0.0;

	[self initLocalizables];

	[self updateFrame:frame];

	[self zoomNormal];

	[self setSecureMode:WebViewTabSecureModeInsecure];
	[self setApplicableHTTPSEverywhereRules:[[NSMutableDictionary alloc] initWithCapacity:6]];

	UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressMenu:)];
	[lpgr setDelegate:self];
	[_webView addGestureRecognizer:lpgr];

	for (UIView *_view in _webView.subviews) {
		for (UIGestureRecognizer *recognizer in _view.gestureRecognizers) {
			[recognizer addTarget:self action:@selector(webViewTouched:)];
		}
		for (UIView *_sview in _view.subviews) {
			for (UIGestureRecognizer *recognizer in _sview.gestureRecognizers) {
				[recognizer addTarget:self action:@selector(webViewTouched:)];
			}
		}
	}

	/* this doubles as a way to force the webview to initialize itself, otherwise the UA doesn't seem to set right before refreshing a previous restoration state */
	NSString *ua = [_webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
	NSArray *uap = [ua componentsSeparatedByString:@"/"];
	NSString *wvthash = uap[uap.count - 1];
	if (![[NSString stringWithFormat:@"%lu", (unsigned long)[self hash]] isEqualToString:wvthash])
		abort();

	if(!equivalentURLS) {
		equivalentURLS = [NSMutableArray new];
	}
	return self;
}

- (void)initLocalizables {
	[self.refresher setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedStringWithDefaultValue(@"PULL_TO_REFRESH_PAGE", nil, [NSBundle mainBundle], @"Pull to Refresh Page", @"UI hint that the webpage can be refreshed by pulling(swiping) down")]];
	if(!_title.text) {
		[_title setText:NSLocalizedStringWithDefaultValue(@"NEW_TAB_TITLE", nil, [NSBundle mainBundle], @"New Tab", @"New browser tab title text")];
	}
}

/* for long press gesture recognizer to work properly */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	if (![gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]])
		return NO;

	if ([gestureRecognizer state] != UIGestureRecognizerStateBegan)
		return YES;

	BOOL haveLinkOrImage = NO;

	NSArray *elements = [self elementsAtLocationFromGestureRecognizer:gestureRecognizer];
	for (NSDictionary *element in elements) {
		NSString *k = [element allKeys][0];

		if ([k isEqualToString:@"a"] || [k isEqualToString:@"img"]) {
			haveLinkOrImage = YES;
			break;
		}
	}

	if (haveLinkOrImage) {
		/* this is enough to cancel the touch when the long press gesture fires, so that the link being held down doesn't activate as a click once the finger is let up */
		if ([otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
			otherGestureRecognizer.enabled = NO;
			otherGestureRecognizer.enabled = YES;
		}

		return YES;
	}

	return NO;
}

- (void)close
{
	[self cancelDownloadAndRemovePreview];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WebProgressEstimateChangedNotification" object:[_webView valueForKeyPath:@"documentView.webView"]];
	// Make sure delegate will not try to call back when webview is already gone;
	[_webView setDelegate:nil];
	[_webView stopLoading];

	for (id gr in [_webView gestureRecognizers])
		[_webView removeGestureRecognizer:gr];

	_webView = nil;
}

- (void)webKitprogressEstimateChanged:(NSNotification*)notification
{
	[self setProgress:[NSNumber numberWithFloat:[[notification object] estimatedProgress]]];
}

- (void)updateFrame:(CGRect)frame
{
	[self.viewHolder setFrame:frame];
	[self.webView setFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
	[self.titleHolder setFrame:CGRectMake(0, -26, frame.size.width, 26)];
	[self.title setFrame:CGRectMake(22, -22, frame.size.width - 22 - 22, 18)];
}

- (void)reset
{
	[[self applicableHTTPSEverywhereRules] removeAllObjects];
	[self setSSLCertificate:nil];
}

- (void)loadURL:(NSURL *)u
{
	[self loadURL:u withForce:NO];
}

- (void) clearEquivalentURLs {
	[equivalentURLS removeAllObjects];
}

- (void) addEquivalentURL: (NSString*) url {
	// limit size of equivalentURLS to MAX_EQUIVALENT_URLS
	// we don't want this to blow up in a case of a redirect loop
	if([equivalentURLS count] <= MAX_EQUIVALENT_URLS) {
		[equivalentURLS addObject: url];
		return;
	}
#ifdef TRACE
	NSLog(@"[WebViewTab] equivalentURLS array size is >= 5");
#endif
}

- (void)loadURL:(NSURL *)u withForce:(BOOL)force
{
	[self.webView stopLoading];
	[self reset];

	NSMutableURLRequest *ur = [NSMutableURLRequest requestWithURL:u];
	ur.timeoutInterval = INT_MAX; // 2^31 - 1 (this is the default timeout seen on requests formed internally by UIWebView)
	if (force)
		[ur setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];

	[self.webView loadRequest:ur];
}

- (void)searchFor:(NSString *)query
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *se = [[[AppDelegate sharedAppDelegate] searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];

	if (se == nil)
	/* just pick the first search engine */
		se = [[[AppDelegate sharedAppDelegate] searchEngines] objectForKey:[[[[AppDelegate sharedAppDelegate] searchEngines] allKeys] firstObject]];

	NSDictionary *pp = [se objectForKey:@"post_params"];
	NSString *urls;
	if (pp == nil)
		urls = [[NSString stringWithFormat:[se objectForKey:@"search_url"], query] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	else
		urls = [se objectForKey:@"search_url"];

	NSURL *url = [NSURL URLWithString:urls];
	if (pp == nil) {
#ifdef TRACE
		NSLog(@"[Tab %@] searching via %@", self.tabIndex, url);
#endif
		[self setUrl:url];
		[self loadURL:url];
	}
	else {
		/* need to send this as a POST, so build our key val pairs */
		NSMutableString *params = [NSMutableString stringWithFormat:@""];
		for (NSString *key in [pp allKeys]) {
			if (![params isEqualToString:@""])
				[params appendString:@"&"];

			[params appendString:[key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
			[params appendString:@"="];

			NSString *val = [pp objectForKey:key];
			if ([val isEqualToString:@"%@"])
				val = [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			[params appendString:val];
		}

		[self.webView stopLoading];
		[self reset];
		[self setUrl:url];


#ifdef TRACE
		NSLog(@"[Tab %@] searching via POST to %@ (with params %@)", self.tabIndex, url, params);
#endif

		NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
		[self.webView loadRequest:request];
	}
}

/* this will only fire for top-level requests (and iframes), not page elements */
- (BOOL)webView:(UIWebView *)__webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];

	// `endlesshttps?://` links are used (mostly or always?) when launching the app with a URL.
	/* treat endlesshttps?:// links clicked inside of web pages as normal links */
	if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttp"]) {
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttp" length]) withString:@"http"]];
		[self loadURL:url];
		return NO;
	}
	else if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttps"]) {
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttps" length]) withString:@"https"]];
		[self loadURL:url];
		return NO;
	}

	if (![[url scheme] isEqualToString:@"endlessipc"]) {
		if ([AppDelegate sharedAppDelegate].psiphonConectionState != ConnectionStateConnected) {
			// We are not connected:
			// 1. Show dismissable modal with the connection status if request is for
			//    mainDocumentURL and mark this tab for reload when we get connected
			// 2. Cancel loading the request by returning NO
			if ([[[request mainDocumentURL] absoluteString] isEqualToString:[[request URL] absoluteString]]) {
				[[[AppDelegate sharedAppDelegate] webViewController] showPsiphonConnectionStatusAlert];
				[self setShouldReloadOnConnected:YES];
			}
			return NO;
		}

		/* Taken from upstream:
		 https://github.com/jcs/endless/commit/436091ff17f3b8724eebb21b235250ae6286fc01
		 https://github.com/jcs/endless/commit/c08cc646aad41691a371c23ac0311fed6cf23b2d

		 "WVT: add Universal Link protection
		 Universal Links in iOS allow 3rd party apps to claim URL hosts that
		 they own, so when links to those hosts are being opened in other
		 apps, that 3rd party app is executed to handle that URL request.

		 Unfortunately there is no way to disable this, so in a web browser
		 app like Endless (I also tested in Chrome, Firefox, Brave, Tob, and
		 Onion Browser), tapping on a link can immediately spawn an installed
		 3rd party app which will make that URL request without any
		 confirmation or warning.

		 For example, if the user has the eBay app installed and taps on a
		 link in Endless pointing to a http://rover.ebay.com/ URL, the eBay
		 app will immediately be opened and show the auction page being
		 requested, which could contain an <img> tag in the auction
		 description that loads from a 3rd party server.  While this isn't a
		 big deal for Endless, it is for Tor- and VPN-based apps that are
		 based on Endless which are trying to keep the user's network
		 activity contained inside the app.

		 Since UIWebView (and WKWebView) offer no indication that such a URL
		 will be opened as a Universal Link (and probably won't ever, for the
		 same reason that iOS disabled UIApplication:canOpenURL: so apps
		 can't figure out which other apps the user has installed), implement
		 a workaround.

		 In WebViewTab's webView:shouldStartLoadWithRequest: delegate method,
		 always return NO for top-level requests that get here (which are
		 links that have been tapped on, window.location= calls, and iframes)
		 but then just start a new request for the same URL.  This seems
		 enough to bypass Universal Link activation and still works with a
		 bunch of sites and Javascript that I tested.

		 Test URL: https://endl.es/tests/decloak"

		 More on the subject:
		 https://jcs.org/notaweblog/2017/02/14/ios_universal_links_and_privacy
		 */

		/* try to prevent universal links from triggering by refusing the initial request and starting a new one */

		// NOTE that this doesn't seem to protect against opening Apple Maps for http(s)://maps.apple.com and
		// App Store for http(s)://itunes.apple.com links, it looks like Apple own links are being more 'universal'
		// than others.

		BOOL iframe = ![[[request URL] absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]];
		if (iframe) {
#ifdef TRACE
			NSLog(@"[Tab %@] not doing universal link workaround for iframe %@", [self tabIndex], url);
#endif
		} else if (navigationType == UIWebViewNavigationTypeBackForward) {
#ifdef TRACE
			NSLog(@"[Tab %@] not doing universal link workaround for back/forward navigation to %@", [self tabIndex], url);
#endif
		} else if ([[[url scheme] lowercaseString] hasPrefix:@"http"] && ![NSURLProtocol propertyForKey:UNIVERSAL_LINKS_WORKAROUND_KEY inRequest:request]) {
			NSMutableURLRequest *tr = [request mutableCopy];
			[NSURLProtocol setProperty:@YES forKey:UNIVERSAL_LINKS_WORKAROUND_KEY inRequest:tr];
#ifdef TRACE
			NSLog(@"[Tab %@] doing universal link workaround for %@", [self tabIndex], url);
#endif
			[self.webView loadRequest:tr];
			return NO;
		}

		// build a dictionary of equivalent URLs
		if ([[[request mainDocumentURL] absoluteString] isEqualToString:[[request URL] absoluteString]]) {
			[self reset];

			// Ignore links clicked, forms submitted, reloads, etc.
			if(navigationType == UIWebViewNavigationTypeOther) {
				[self addEquivalentURL:[[request mainDocumentURL] absoluteString]];
			}
			if ([[[url scheme] lowercaseString] isEqualToString:@"https"]) {
				SSLCertificate* certificate = [[[AppDelegate sharedAppDelegate] sslCertCache] objectForKey:[url host]];
				if (certificate) {
					[self setSSLCertificate:certificate];
				}
			}
		}

		[self cancelDownloadAndRemovePreview];
		return YES;
	}

	// At this point we know we're handling an `endlessipc://` URL. Like:
	/* endlessipc://window.open/?http... */

	NSString *action = [url host];

	NSString *param, *param2;
	if ([[[request URL] pathComponents] count] >= 2)
		param = [url pathComponents][1];
	if ([[[request URL] pathComponents] count] >= 3)
		param2 = [url pathComponents][2];

	NSString *value = [[[url query] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	if ([action isEqualToString:@"console.log"]) {
#ifdef TRACE
		NSString *json = [[[url query] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSLog(@"[Tab %@] [console.%@] %@", [self tabIndex], param, json);
#endif
		/* no callback needed */
		return NO;
	}

#ifdef TRACE
	NSLog(@"[Javascript IPC]: [%@] [%@] [%@] [%@]", action, param, param2, value);
#endif

	if ([action isEqualToString:@"pagefinal"]) {
		// a page is finally loaded in the tab,
		// message the delegate and pass the array of
		// all equivalent URLs for this page
		if (_finalPageObserverDelegate && [_finalPageObserverDelegate respondsToSelector:@selector(seenFinalPage:)]) {
			[_finalPageObserverDelegate seenFinalPage: equivalentURLS];
			// signal the observer only once per new home page tab
			_finalPageObserverDelegate = nil;
		}
		[self clearEquivalentURLs];
	}
	else if ([action isEqualToString:@"noop"]) {
		// In the webview, execute a JS callback that indicates that IPC is done (with no other action).
		[self webView:__webView callbackWith:@""];
	}
	else if ([action isEqualToString:@"window.open"]) {
		/* only allow windows to be opened from mouse/touch events, like a normal browser's popup blocker */
		if (navigationType == UIWebViewNavigationTypeLinkClicked) {
			NSURL *newURL = [NSURL URLWithString:value];
			WebViewTab *newtab = [[[AppDelegate sharedAppDelegate] webViewController] addNewTabForURL:newURL];
			newtab.openedByTabHash = [NSNumber numberWithLong:self.hash];

			[self webView:__webView callbackWith:@""];
		}
		else {
			/* TODO: show a "popup blocked" warning? */
			NSLog(@"[Tab %@] blocked non-touch window.open() (nav type %ld)", self.tabIndex, (long)navigationType);

			[self webView:__webView callbackWith:@""];
		}
	}
	else if ([action isEqualToString:@"window.close"]) {
		// Close the current tab if it is opened by hash
		// same style as 'Back' button behaviour
		NSString *callBack = @"console.warn('Scripts may close only the windows that were opened by it.')";
		if (self.openedByTabHash) {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"CLOSE_TABS_CONFIRM", nil, [NSBundle mainBundle], @"Confirm", @"Title for the 'Allow this page to close its tab?' alert") message:NSLocalizedStringWithDefaultValue(@"CLOSE_TABS_PROMPT", nil, [NSBundle mainBundle], @"Allow this page to close its tab?", @"Alert dialog text") preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"OK_ACTION", nil, [NSBundle mainBundle], @"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				[[[AppDelegate sharedAppDelegate] webViewController] removeTabOpenedByHash:self.tabIndex];
			}];

			UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"CANCEL_ACTION", nil, [NSBundle mainBundle], @"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
			[alertController addAction:cancelAction];
			[alertController addAction:okAction];
			callBack = @"";
			[[[AppDelegate sharedAppDelegate] webViewController] presentViewController:alertController animated:YES completion:nil];
		}
		[self webView:__webView callbackWith:callBack];
	}
	/*
	// TODO-DISABLE-JAVASCRIPT: comment out until fixed
	else if ([action isEqualToString:@"noscript"]) {
		BOOL disableJavascript = NO; // TODO-DISABLE-JAVASCRIPT: hardcode off until fixed
		NSString* callBack;
		if (disableJavascript) {
			callBack = @"__psiphon.removeNoscript();";
		} else {
			callBack = @"";
		}
		[self webView:__webView callbackWith:callBack];
	}
	 */
	return NO;
}

- (void)webViewDidStartLoad:(UIWebView *)__webView
{
	/* reset and then let WebViewController animate to our actual progress */
	[self setProgress:@0.0];
	[self setProgress:@0.1];

	if (self.url == nil)
		self.url = [[__webView request] URL];

	// Send "Tab start load" notification
	[[NSNotificationCenter defaultCenter] postNotificationName:kPsiphonWebTabStartLoadNotification object:nil];
}

- (void)webViewDidFinishLoad:(UIWebView *)__webView
{
#ifdef TRACE
	NSLog(@"[Tab %@] finished loading page/iframe %@, security level is %lu", self.tabIndex, [[[__webView request] URL] absoluteString], self.secureMode);
#endif
	[self setProgress:@1.0];

	NSString *docTitle = [__webView stringByEvaluatingJavaScriptFromString:@"document.title"];
	NSString *finalURL = [__webView stringByEvaluatingJavaScriptFromString:@"window.location.href"];

	/* if we have javascript blocked, these will be empty */
	if (finalURL == nil || [finalURL isEqualToString:@""])
		finalURL = [[[__webView request] mainDocumentURL] absoluteString];
	if (docTitle == nil || [docTitle isEqualToString:@""])
		docTitle = finalURL;

	[self.title setText:docTitle];
	self.url = [NSURL URLWithString:finalURL];
}

- (void)webView:(UIWebView *)__webView didFailLoadWithError:(NSError *)error
{
	[self setProgress:@0];

	if ([[error domain] isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
		if (self.fileDownloadState == WebViewTabFileDownloadStateDownloadInProgress) {
			self.fileDownloadState = WebViewTabFileDownloadStateDownloadFailed;
			[[[AppDelegate sharedAppDelegate] webViewController] updateSearchBarDetails];
		}
		return;
	}

	/* "The operation couldn't be completed. (Cocoa error 3072.)" - useless */
	if ([[error domain] isEqualToString:NSCocoaErrorDomain] && error.code == NSUserCancelledError) {
		[[[AppDelegate sharedAppDelegate] webViewController] updateSearchBarDetails];
		return;
	}

	NSString *msg = [error localizedDescription];

	/* https://opensource.apple.com/source/libsecurity_ssl/libsecurity_ssl-36800/lib/SecureTransport.h */
	if ([[error domain] isEqualToString:NSOSStatusErrorDomain]) {
		switch (error.code) {
			case errSSLProtocol: /* -9800 */
				msg = @"SSL protocol error";
				break;
			case errSSLNegotiation: /* -9801 */
				msg = @"SSL handshake failed";
				break;
			case errSSLXCertChainInvalid: /* -9807 */
				msg = @"SSL certificate chain verification error (self-signed certificate?)";
				break;
		}
	}

	NSString *u;
	if ((u = [[error userInfo] objectForKey:@"NSErrorFailingURLStringKey"]) != nil)
		msg = [NSString stringWithFormat:@"%@\n\n%@", msg, u];

	if ([error userInfo] != nil) {
		NSNumber *ok = [[error userInfo] objectForKey:ORIGIN_KEY];
		if (ok != nil && [ok boolValue] == NO) {
#ifdef TRACE
			NSLog(@"[Tab %@] not showing dialog for non-origin error: %@ (%@)", self.tabIndex, msg, error);
#endif
			[self webViewDidFinishLoad:__webView];
			return;
		}
	}

#ifdef TRACE
	NSLog(@"[Tab %@] showing error dialog: %@ (%@)", self.tabIndex, msg, error);
#endif

	UIAlertView *m = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"WEB_LOAD_ERROR_TEXT", nil, [NSBundle mainBundle], @"Error", @"Alert dialog title when webpage has failed to load") message:msg delegate:self cancelButtonTitle: NSLocalizedStringWithDefaultValue(@"OK_ACTION", nil, [NSBundle mainBundle], @"OK", "OK action") otherButtonTitles:nil];
	[m show];

	[self webViewDidFinishLoad:__webView];
}

- (void)webView:(UIWebView *)__webView callbackWith:(NSString *)callback
{
	NSString *finalcb = [NSString stringWithFormat:@"(function() { %@; __psiphon.ipcDone = (new Date()).getTime(); })();", callback];

#ifdef TRACE_IPC
	NSLog(@"[Javascript IPC]: calling back with: %@", finalcb);
#endif

	[__webView stringByEvaluatingJavaScriptFromString:finalcb];
}

- (void)setSSLCertificate:(SSLCertificate *)SSLCertificate
{
	_SSLCertificate = SSLCertificate;

	if (_SSLCertificate == nil) {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to insecure", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeInsecure];
	}
	else if ([[self SSLCertificate] isEV]) {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to ev", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeSecureEV];
	}
	else {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to secure", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeSecure];
	}
}

- (void)setProgress:(NSNumber *)pr
{
	_progress = pr;
	dispatch_async(dispatch_get_main_queue(), ^{
		[[[AppDelegate sharedAppDelegate] webViewController] updateProgress];
	});
}

- (void)swipeRightAction:(UISwipeGestureRecognizer *)gesture
{
	[self goBack];
}

- (void)swipeLeftAction:(UISwipeGestureRecognizer *)gesture
{
	[self goForward];
}

- (void)webViewTouched:(UIEvent *)event
{
	[[[AppDelegate sharedAppDelegate] webViewController] webViewTouched];
}

- (void)longPressMenu:(UILongPressGestureRecognizer *)sender {
	UIAlertController *alertController;
	NSString *href, *img, *alt;

	if (sender.state != UIGestureRecognizerStateBegan)
		return;

#ifdef TRACE
	NSLog(@"[Tab %@] long-press gesture recognized", self.tabIndex);
#endif

	NSArray *elements = [self elementsAtLocationFromGestureRecognizer:sender];
	for (NSDictionary *element in elements) {
		NSString *k = [element allKeys][0];
		NSDictionary *attrs = [element objectForKey:k];

		if ([k isEqualToString:@"a"]) {
			href = [attrs objectForKey:@"href"];

			/* only use if image alt is blank */
			if (!alt || [alt isEqualToString:@""])
				alt = [attrs objectForKey:@"title"];
		}
		else if ([k isEqualToString:@"img"]) {
			img = [attrs objectForKey:@"src"];

			NSString *t = [attrs objectForKey:@"title"];
			if (t && ![t isEqualToString:@""])
				alt = t;
			else
				alt = [attrs objectForKey:@"alt"];
		}
	}

#ifdef TRACE
	NSLog(@"[Tab %@] context menu href:%@, img:%@, alt:%@", self.tabIndex, href, img, alt);
#endif

	if (!(href || img)) {
		sender.enabled = false;
		sender.enabled = true;
		return;
	}

	alertController = [UIAlertController alertControllerWithTitle:href message:alt preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction *openAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"LINK_LONG_PRESS_OPEN", nil, [NSBundle mainBundle], @"Open", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self loadURL:[NSURL URLWithString:href]];
	}];

	UIAlertAction *openNewTabAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"LINK_LONG_PRESS_OPEN_NEW_TAB", nil, [NSBundle mainBundle], @"Open in a New Tab", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[[AppDelegate sharedAppDelegate] webViewController] addNewTabForURL:[NSURL URLWithString:href]];
	}];

	UIAlertAction *openSafariAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"LINK_LONG_PRESS_OPEN_SAFARI", nil, [NSBundle mainBundle], @"Open in Safari", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:href]];
	}];

	UIAlertAction *saveImageAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"IMAGE_LONG_PRESS_SAVE", nil, [NSBundle mainBundle], @"Save Image", @"Action title for long press on image dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self requestAuthorizationWithRedirectionToSettings];

		UIAlertView *downloadInProgress = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_TITLE", nil, [NSBundle mainBundle], @"Downloading…", @"Image download in progress alert title") message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_TEXT", nil, [NSBundle mainBundle], @"Downloading image %@. You will be notified when the download completes.", @"Image download in progress alert text. %@ will be replaced with the URL of the image."), img] delegate:self cancelButtonTitle: NSLocalizedStringWithDefaultValue(@"OK_ACTION", nil, [NSBundle mainBundle], @"OK", @"OK action") otherButtonTitles:nil];
		[downloadInProgress show];

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSURL *imgurl = [NSURL URLWithString:img];
			[JAHPAuthenticatingHTTPProtocol temporarilyAllow:imgurl];

			NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:imgurl];
			[request setValue:[[AppDelegate sharedAppDelegate] defaultUserAgent] forHTTPHeaderField:@"User-Agent"]; // TODO: we could always set user agent to default if nil in JAHPAuthenticatingHTTPProtocol.m

			NSHTTPURLResponse *response = nil;
			NSError *error = nil;
			NSData *imgdata = [NSURLConnection sendSynchronousRequest:request
													returningResponse:&response
																error:&error];
			if (error != nil || (response != nil && [response statusCode] != 200) || imgdata == nil) {
				dispatch_async(dispatch_get_main_queue(), ^{
					NSString *errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_ERROR_GENERIC", nil, [NSBundle mainBundle], @"An error occurred downloading image %@", @"Image download error alert text. %@ will be replaced with the URL of the image."), img];
					if (error != nil) {
						errorMessage = [errorMessage stringByAppendingString:[NSString stringWithFormat:@". %@ %@.", NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_ERROR_PREFIX", nil, [NSBundle mainBundle], @"Error:", @"Text preceeding error description"), [error localizedDescription]]];
					}
					if ([response statusCode] != 200) {
						errorMessage = [errorMessage stringByAppendingString:[NSString stringWithFormat:@". %@ %@.", NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_STATUS_CODE_PREFIX", nil, [NSBundle mainBundle], @"Status code:", @"Text preceeding http response status code"), [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]]];
					}
					UIAlertView *downloadError = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_ERROR_TITLE", nil, [NSBundle mainBundle], @"Error", @"Image download error alert title") message:errorMessage delegate:self cancelButtonTitle: NSLocalizedStringWithDefaultValue(@"OK_ACTION", nil, [NSBundle mainBundle], @"OK", @"OK action") otherButtonTitles:nil];
					[downloadInProgress dismissWithClickedButtonIndex:0 animated:YES];
					[downloadError show];
				});
			} else {
				UIImage *i = [UIImage imageWithData:imgdata];
				UIImageWriteToSavedPhotosAlbum(i, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);

				dispatch_async(dispatch_get_main_queue(), ^{
					UIAlertView *downloadSuccess = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_SUCCESS_TITLE", nil, [NSBundle mainBundle], @"Success!", @"Image download success alert title") message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"IMAGE_DOWNLOAD_SUCCESS_TEXT", nil, [NSBundle mainBundle], @"Successfully downloaded image %@", @"Image download success alert text. %@ will be replaced with the URL of the image."), img] delegate:self cancelButtonTitle: NSLocalizedStringWithDefaultValue(@"OK_ACTION", nil, [NSBundle mainBundle], @"OK", @"OK action") otherButtonTitles:nil];

					[downloadInProgress dismissWithClickedButtonIndex:0 animated:YES];
					[downloadSuccess show];
				});
			}
		});
	}];

	UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"LINK_LONG_PRESS_COPY_URL", nil, [NSBundle mainBundle], @"Copy URL", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIPasteboard generalPasteboard] setString:(href ? href : img)];
	}];

	if (href) {
		[alertController addAction:openAction];
		[alertController addAction:openNewTabAction];
		[alertController addAction:openSafariAction];
	}

	if (img)
		[alertController addAction:saveImageAction];

	[alertController addAction:copyURLAction];

	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"CANCEL_ACTION", nil, [NSBundle mainBundle], @"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
	[alertController addAction:cancelAction];

	UIPopoverPresentationController *popover = [alertController popoverPresentationController];
	if (popover) {
		popover.sourceView = [sender view];
		CGPoint loc = [sender locationInView:[sender view]];
		/* offset for width of the finger */
		popover.sourceRect = CGRectMake(loc.x + 35, loc.y, 1, 1);
		popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
	}

	[[[AppDelegate sharedAppDelegate] webViewController] presentViewController:alertController animated:YES completion:nil];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	if (error != nil) {
		// Fail silently to the user
		Throwable *t = [[Throwable alloc] init:[NSString stringWithFormat:@"%@", error] withStackTrace:[NSThread callStackSymbols]];
		StatusEntry *s = [[StatusEntry alloc] init:@"Failed to download image." formatArgs:nil throwable:t sensitivity:SensitivityLevelSensitiveLog priority:PriorityError];
		[[PsiphonData sharedInstance] addStatusEntry:s];
	}
}

- (void) requestAuthorizationWithRedirectionToSettings {
	dispatch_async(dispatch_get_main_queue(), ^{
		PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
		if (status == PHAuthorizationStatusAuthorized) {
			// Photo library permission has been granted
		}
		else {
			// Photo library permission not granted
			// Try to request it normally
			[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
				if (status != PHAuthorizationStatusAuthorized)
				{
					// User doesn't grant permission.
					// Show alert where user can choose to redirect
					// to the settings menu and grant access or cancel.
					//
					// The suspended app will be termianted if the user
					// changes privacy settings in the settings menu.
					// It will be automatically relaunched when the user
					// navigates back.
					NSString *accessDescription = NSLocalizedStringWithDefaultValue(@"PHOTO_LIBRARY_ACCESS_PROMPT", nil, [NSBundle mainBundle], @"\"Psiphon Browser\" needs access to your photo library to save and upload images", @"Alert text telling user additional permissions must be granted to save and upload photos in the browser");
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:accessDescription message:NSLocalizedStringWithDefaultValue(@"PHOTO_LIBRARY_ACCESS_INSTRUCTION", nil, [NSBundle mainBundle], @"To give permissions tap on 'Change Settings' button", @"Alert text telling user which button to press if they want to be redirected to the settings menu") preferredStyle:UIAlertControllerStyleAlert];

					UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"CANCEL_ACTION", nil, [NSBundle mainBundle], @"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
					[alertController addAction:cancelAction];

					UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"CHANGE_SETTINGS_BUTTON", nil, [NSBundle mainBundle], @"Change Settings", @"Text of button on alert which will redirect the user to the settings menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
						[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
					}];
					[alertController addAction:settingsAction];

					// Callback will not be on the main thread
					dispatch_async(dispatch_get_main_queue(), ^{
						[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
					});
				}
			}];
		}
	});
}

- (BOOL)canGoBack
{
	return ((self.webView && [self.webView canGoBack]) || self.openedByTabHash != nil);
}

- (BOOL)canGoForward
{
	return !!(self.webView && [self.webView canGoForward]);
}

- (void)goBack
{
	if ([self.webView canGoBack]) {
		[[self webView] goBack];
	}
	else if (self.openedByTabHash) {
		[[[AppDelegate sharedAppDelegate] webViewController] removeTabOpenedByHash:self.tabIndex];
	}
}

- (void)goForward
{
	if ([[self webView] canGoForward])
		[[self webView] goForward];
}

- (void)refresh
{
	[[self webView] reload];
}

- (void)forceRefresh
{
	[self loadURL:[self url] withForce:YES];
}

- (void)forceRefreshFromRefresher
{
	[self forceRefresh];

	/* delay just so it confirms to the user that something happened */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		[self.refresher endRefreshing];
	});
}

- (void)zoomOut
{
	if (previewControllerOverlay != nil) {
		// If we are displaying a file preview on this tab
		// we want to prevent user interaction with it while
		// zoomed out in the all-tabs view.
		previewControllerOverlay.hidden = NO;
	}
	[[self webView] setUserInteractionEnabled:NO];

	[_titleHolder setHidden:false];
	[_title setHidden:false];
	[_closer setHidden:false];
	[[[self viewHolder] layer] setShadowOpacity:0.3];
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE)];
}

- (void)zoomNormal
{
	if (previewControllerOverlay != nil) {
		// Re-enable interaction with file preview on this tab
		// so the user can continue to interact with it once again
		// after returning from the all-tabs view (zoomed out) to
		// the normal tab view (zoom normal).
		previewControllerOverlay.hidden = YES;
	}
	[[self webView] setUserInteractionEnabled:YES];

	[_titleHolder setHidden:true];
	[_title setHidden:true];
	[_closer setHidden:true];
	[[[self viewHolder] layer] setShadowOpacity:0];
	[[self viewHolder] setTransform:CGAffineTransformIdentity];
}

- (NSArray *)elementsAtLocationFromGestureRecognizer:(UIGestureRecognizer *)uigr
{
	CGPoint tap = [uigr locationInView:[self webView]];
	tap.y -= [[[self webView] scrollView] contentInset].top;

	/* translate tap coordinates from view to scale of page */
	CGSize windowSize = CGSizeMake(
								   [[[self webView] stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] intValue],
								   [[[self webView] stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] intValue]
								   );
	CGSize viewSize = [[self webView] frame].size;
	float ratio = windowSize.width / viewSize.width;
	CGPoint tapOnPage = CGPointMake(tap.x * ratio, tap.y * ratio);

	/* now find if there are usable elements at those coordinates and extract their attributes */
	NSString *json = [[self webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSON.stringify(__psiphon.elementsAtPoint(%li, %li));", (long)tapOnPage.x, (long)tapOnPage.y]];
	if (json == nil) {
		NSLog(@"[Tab %@] didn't get any JSON back from __psiphon.elementsAtPoint", self.tabIndex);
		return @[];
	}

	return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
}

- (void)psiphonConnectionStateNotified:(NSNotification *)notification {
	ConnectionState state = [[notification.userInfo objectForKey:kPsiphonConnectionState] unsignedIntegerValue];
	if(state == ConnectionStateConnected) {
		[[self webView] stringByEvaluatingJavaScriptFromString:
		 [NSString stringWithFormat:@"if(__psiphon) {__psiphon.messageUrlProxyPort(%d);}", (int)[[AppDelegate sharedAppDelegate] httpProxyPort]]];
	}
}

#pragma mark - DownloadTaskDelegate methods

- (void)didStartDownloadingFile {
	self.fileDownloadState = WebViewTabFileDownloadStateDownloadInProgress;
}

- (void)didFinishDownloadingToURL:(NSURL *)location {
	self.fileDownloadState = WebViewTabFileDownloadStateDownloadCompleted;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (location != nil) {
			downloadedFile = location;
			[self addPreviewController]; // add preview controller to view
		} else {
#ifdef TRACE
			NSLog(@"didFinishDownloadingToURL called with nil location");
#endif
		}
	});
}

#pragma mark - DownloadTaskDelegate helpers
// Add preview controller as a child of WebViewController and
// its view as a subview of self.webView
- (void)addPreviewController {
	previewController = [[QLPreviewController alloc] init];
	previewController.delegate = self;
	previewController.dataSource = self;

	// Setup preview overlay
	downloadPreview = [[UIView alloc] init];
	downloadPreview.translatesAutoresizingMaskIntoConstraints = NO;
	[self.webView addSubview:downloadPreview];

	[self.webView addConstraint:[NSLayoutConstraint constraintWithItem:downloadPreview
													 attribute:NSLayoutAttributeLeft
													 relatedBy:NSLayoutRelationEqual
														toItem:self.webView
													 attribute:NSLayoutAttributeLeft
													multiplier:1.f
													  constant:0]];
	[self.webView addConstraint:[NSLayoutConstraint constraintWithItem:downloadPreview
													 attribute:NSLayoutAttributeRight
													 relatedBy:NSLayoutRelationEqual
														toItem:self.webView
													 attribute:NSLayoutAttributeRight
													multiplier:1.f
													  constant:0]];
	[self.webView addConstraint:[NSLayoutConstraint constraintWithItem:downloadPreview
													 attribute:NSLayoutAttributeTop
													 relatedBy:NSLayoutRelationEqual
														toItem:self.webView
													 attribute:NSLayoutAttributeTop
													multiplier:1.f
													  constant:0]];
	[self.webView addConstraint:[NSLayoutConstraint constraintWithItem:downloadPreview
													 attribute:NSLayoutAttributeBottom
													 relatedBy:NSLayoutRelationEqual
														toItem:self.webView
													 attribute:NSLayoutAttributeBottom
													multiplier:1.f
													  constant:0]];

	// Add viewController as a child of WebViewController
	UIViewController *parent = [[AppDelegate sharedAppDelegate] webViewController];
	[parent addChildViewController:previewController];

	// Add previewController.view as a subview of view
	[downloadPreview addSubview:previewController.view];

	// Setup previewController's autolayout
	previewController.view.translatesAutoresizingMaskIntoConstraints = NO;
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewController.view
																attribute:NSLayoutAttributeLeft
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeLeft
															   multiplier:1.f
																 constant:0]];
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewController.view
																attribute:NSLayoutAttributeRight
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeRight
															   multiplier:1.f
																 constant:0]];
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewController.view
																attribute:NSLayoutAttributeTop
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeTop
															   multiplier:1.f
																 constant:0]];
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewController.view
																attribute:NSLayoutAttributeBottom
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeBottom
															   multiplier:1.f
																 constant:-TOOLBAR_HEIGHT * 2.0 - TOOLBAR_HEIGHT  /* top and bottom toolbars plus "more" button's height */]];
	[previewController didMoveToParentViewController:parent];

	// Add "more" button which allows user to push DocumentInteractionController for presented file
	UIButton *more = [[UIButton alloc] init];
	[more setTitleColor:[parent.view tintColor] forState:UIControlStateNormal];
	[more setTitle:NSLocalizedStringWithDefaultValue(@"DOWNLOAD_PREVIEW_MORE", nil, [NSBundle mainBundle], @"More...", @"Text of button on download preview screen which allows users to see what other actions they can perform with the file") forState:UIControlStateNormal];
	[more addTarget:self action:@selector(presentOptionsMenuForCurrentDownload:) forControlEvents:UIControlEventTouchUpInside];
	[downloadPreview  addSubview:more];

	// Setup "more" button's autolayout
	more.frame = CGRectMake(0, 0, 120, TOOLBAR_HEIGHT);
	more.translatesAutoresizingMaskIntoConstraints = NO;
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:more
																attribute:NSLayoutAttributeCenterX
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeCenterX
															   multiplier:1.f
																 constant:0]];

	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:more
																attribute:NSLayoutAttributeTop
																relatedBy:NSLayoutRelationEqual
																   toItem:previewController.view
																attribute:NSLayoutAttributeBottom
															   multiplier:1.f
																 constant:0]];

	// Add another overlay (a hack to create a transparant clickable view)
	// which doesn't influence the alpha of the "more" button but allows us
	// to disable interaction with the file preview when zoomed out in the
	// all-tabs view.
	previewControllerOverlay = [[UIView alloc] init];
	previewControllerOverlay.backgroundColor = [UIColor whiteColor];
	previewControllerOverlay.alpha = 0.11;
	previewControllerOverlay.userInteractionEnabled = NO;
	previewControllerOverlay.translatesAutoresizingMaskIntoConstraints = NO;
	previewControllerOverlay.hidden = YES;
	[downloadPreview addSubview:previewControllerOverlay];

	// Setup autolayout
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewControllerOverlay
																attribute:NSLayoutAttributeLeft
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeLeft
															   multiplier:1.f
																 constant:0]];
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewControllerOverlay
																attribute:NSLayoutAttributeRight
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeRight
															   multiplier:1.f
																 constant:0]];
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewControllerOverlay
																attribute:NSLayoutAttributeTop
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeTop
															   multiplier:1.f
																 constant:0]];
	[downloadPreview addConstraint:[NSLayoutConstraint constraintWithItem:previewControllerOverlay
																attribute:NSLayoutAttributeBottom
																relatedBy:NSLayoutRelationEqual
																   toItem:downloadPreview
																attribute:NSLayoutAttributeBottom
															   multiplier:1.f
																 constant:0]];
}

- (void)presentOptionsMenuForCurrentDownload:(id)sender {
	if (downloadedFile != nil) {
		documentInteractionController = [self setupControllerWithURL:downloadedFile usingDelegate:self];
		BOOL presented = [documentInteractionController presentOptionsMenuFromRect:[AppDelegate sharedAppDelegate].webViewController.view.frame inView:[AppDelegate sharedAppDelegate].webViewController.view animated:YES];
		if (!presented) {
#ifdef TRACE
			NSLog(@"Failed to present options menu for current download");
#endif
		}
	}
}

// Should be called whenever navigation occurs or
// when the WebViewTab is being closed.
- (void)cancelDownloadAndRemovePreview {
	self.fileDownloadState = WebViewTabFileDownloadStateNone;
	if (downloadedFile != nil) {
		// Delete the temporary file
		NSError *err;
		[[NSFileManager defaultManager] removeItemAtPath:downloadedFile.path error:&err];
		if (err != nil) {
#ifdef TRACE
			NSLog(@"File delete error %@", err);
#endif
		}
		downloadedFile = nil;
	}
	[self removePreviewController];
}

- (void)removeDownloadPreview {
	if (downloadPreview != nil) {
		[downloadPreview removeFromSuperview];
		downloadPreview = nil;
	}
}

- (void)removePreviewController {
	documentInteractionController = nil;

	if (previewController != nil) {
		[previewController.view removeFromSuperview];
		[previewController removeFromParentViewController];
		previewController = nil;
		previewControllerOverlay = nil;
		documentInteractionController = nil;
	}
	[self removeDownloadPreview];
}

#pragma mark - UIDocumentInteractionControllerDelegate methods and helpers

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
	return [[AppDelegate sharedAppDelegate] webViewController];
}

- (UIDocumentInteractionController *) setupControllerWithURL: (NSURL*) fileURL
											   usingDelegate: (id <UIDocumentInteractionControllerDelegate>) interactionDelegate {
	UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
	interactionController.delegate = interactionDelegate;

	return interactionController;
}

- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller {
	if ([documentInteractionController isEqual:controller]) {
		documentInteractionController = nil;
	}
}

#pragma mark - QLPreviewControllerDataSource methods

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
	return downloadedFile;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
	if (downloadedFile != nil) {
		return 1;
	}
	return 0;
}

@end
