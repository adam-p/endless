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

-(void) initLocalizables {
	[self.refresher setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to Refresh Page", @"UI hint that the webpage can be refreshed by pulling(swiping) down")]];
	if(!_title.text) {
		[_title setText:NSLocalizedString(@"New Tab", @"New browser tab title text")];
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
		if ([[AppDelegate sharedAppDelegate] getConnectionState] != ConnectionStateConnected) {
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
		// Close the current tab.
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Confirm", @"Title for the 'Allow this page to close its tab?' alert") message:NSLocalizedString(@"Allow this page to close its tab?", @"Alert dialog text") preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[[AppDelegate sharedAppDelegate] webViewController] removeTab:[self tabIndex]];
		}];

		UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
		[alertController addAction:cancelAction];
		[alertController addAction:okAction];

		[[[AppDelegate sharedAppDelegate] webViewController] presentViewController:alertController animated:YES completion:nil];

		[self webView:__webView callbackWith:@""];
	}
	else if ([action isEqualToString:@"noscript"]) {
		BOOL disableJavascript = [[NSUserDefaults standardUserDefaults] boolForKey:kDisableJavascript];
		NSString* callBack;
		if (disableJavascript) {
			callBack = @"__endless.removeNoscript();";
		} else {
			callBack = @"";
		}
		[self webView:__webView callbackWith:callBack];
	}

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
	self.url = self.webView.request.URL;
	[self setProgress:@0];

	if ([[error domain] isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
		return;

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

	UIAlertView *m = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"Alert dialog title when webpage has failed to load") message:msg delegate:self cancelButtonTitle: NSLocalizedString(@"OK", "OK action") otherButtonTitles:nil];
	[m show];

	[self webViewDidFinishLoad:__webView];

	[[AppDelegate sharedAppDelegate] startPsiphonOnlyIfNeeded:YES];
}

- (void)webView:(UIWebView *)__webView callbackWith:(NSString *)callback
{
	NSString *finalcb = [NSString stringWithFormat:@"(function() { %@; __endless.ipcDone = (new Date()).getTime(); })();", callback];

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
	[[[AppDelegate sharedAppDelegate] webViewController] updateProgress];
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

	UIAlertAction *openAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self loadURL:[NSURL URLWithString:href]];
	}];

	UIAlertAction *openNewTabAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in a New Tab", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[[AppDelegate sharedAppDelegate] webViewController] addNewTabForURL:[NSURL URLWithString:href]];
	}];

	UIAlertAction *openSafariAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in Safari", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:href]];
	}];

	UIAlertAction *saveImageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Save Image", @"Action title for long press on image dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self requestAuthorizationWithRedirectionToSettings];

		UIAlertView *downloadInProgress = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Downloading…", @"Image download in progress alert title") message:[NSString stringWithFormat:NSLocalizedString(@"Downloading image %@. You will be notified when the download completes.", @"Image download in progress alert text. %@ will be replaced with the URL of the image."), img] delegate:self cancelButtonTitle: NSLocalizedString(@"OK", @"OK action button") otherButtonTitles:nil];
		[downloadInProgress show];

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSURL *imgurl = [NSURL URLWithString:img];
			[JAHPAuthenticatingHTTPProtocol temporarilyAllow:imgurl];
			NSData *imgdata = [NSData dataWithContentsOfURL:imgurl];

			if (imgdata) {
				UIImage *i = [UIImage imageWithData:imgdata];
				UIImageWriteToSavedPhotosAlbum(i, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);

				UIAlertView *downloadSuccess = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Success!", @"Image download success alert title") message:[NSString stringWithFormat:NSLocalizedString(@"Successfully downloaded image %@", @"Image download success alert text. %@ will be replaced with the URL of the image."), img] delegate:self cancelButtonTitle: NSLocalizedString(@"OK", @"OK action button") otherButtonTitles:nil];
				dispatch_async(dispatch_get_main_queue(), ^{
					[downloadInProgress dismissWithClickedButtonIndex:0 animated:YES];
					[downloadSuccess show];
				});
			}
			else {
				UIAlertView *downloadError = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"Image download error alert title") message:[NSString stringWithFormat:NSLocalizedString(@"An error occurred downloading image %@", @"Image download error alert text. %@ will be replaced with the URL of the image."), img] delegate:self cancelButtonTitle: NSLocalizedString(@"OK", @"OK action button") otherButtonTitles:nil];
				dispatch_async(dispatch_get_main_queue(), ^{
					[downloadInProgress dismissWithClickedButtonIndex:0 animated:YES];
					[downloadError show];
				});
			}
		});
	}];

	UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Copy URL", @"Action title for long press on link dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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

	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
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
					NSString *accessDescription = NSLocalizedString(@"\"Psiphon Browser\" needs access to your photo library to save and upload images", @"Alert text telling user additional permissions must be granted to save and upload photos in the browser");
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:accessDescription message:NSLocalizedString(@"To give permissions tap on 'Change Settings' button", @"Alert text telling user which button to press if they want to be redirected to the settings menu") preferredStyle:UIAlertControllerStyleAlert];

					UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Text of cancel button on alert which will dismiss the popup") style:UIAlertActionStyleCancel handler:nil];
					[alertController addAction:cancelAction];

					UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Change Settings", @"Text of button on alert which will redirect the user to the settings menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
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
		for (WebViewTab *wvt in [[[AppDelegate sharedAppDelegate] webViewController] webViewTabs]) {
			if ([wvt hash] == [self.openedByTabHash longValue]) {
				[[[AppDelegate sharedAppDelegate] webViewController] removeTabOpenedByHash:self.tabIndex];
				return;
			}
		}

		[[[AppDelegate sharedAppDelegate] webViewController] removeTab:self.tabIndex];
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
	[[self webView] setUserInteractionEnabled:NO];

	[_titleHolder setHidden:false];
	[_title setHidden:false];
	[_closer setHidden:false];
	[[[self viewHolder] layer] setShadowOpacity:0.3];
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE)];
}

- (void)zoomNormal
{
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
	NSString *json = [[self webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSON.stringify(__endless.elementsAtPoint(%li, %li));", (long)tapOnPage.x, (long)tapOnPage.y]];
	if (json == nil) {
		NSLog(@"[Tab %@] didn't get any JSON back from __endless.elementsAtPoint", self.tabIndex);
		return @[];
	}

	return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
}

@end
