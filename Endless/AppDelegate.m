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

#import <AudioToolbox/AudioServices.h>

#import "AppDelegate.h"
#import "Bookmark.h"
#import "HTTPSEverywhere.h"
#import "PsiphonData.h"
#import "RegionAdapter.h"
#import "UpstreamProxySettings.h"

@implementation AppDelegate {
	BOOL _needsResume;
	// Array of home pages from the handshake.
	// We will pick only one URL from this array
	// when it's time to open a home page
	NSMutableArray *_handshakeHomePages;

	SystemSoundID _notificationSound;
	Reachability *_reachability;
	UIAlertController *authAlertController;
	NSTimer *_appActiveTimer;
	NSInteger _lastActiveTickTime;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[JAHPAuthenticatingHTTPProtocol setDelegate:self];
	[JAHPAuthenticatingHTTPProtocol start];


	[self initializeDefaults];

	self.hstsCache = [HSTSCache retrieve];
	[CookieJar syncCookieAcceptPolicy];
	[Bookmark retrieveList];
	self.sslCertCache = [[NSCache alloc] init];

	NSURL *audioPath = [[NSBundle mainBundle] URLForResource:@"blip1" withExtension:@"wav"];
	AudioServicesCreateSystemSoundID((__bridge CFURLRef)audioPath, &_notificationSound);

	self.psiphonTunnel = [PsiphonTunnel newPsiphonTunnel:self];

	_needsResume = false;

	BOOL isOnboarding = ![[NSUserDefaults standardUserDefaults] boolForKey:kHasBeenOnboardedKey];
	self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
	self.window.rootViewController = [[WebViewController alloc] init];
	self.window.rootViewController.restorationIdentifier = @"WebViewController";
	[(WebViewController*)self.window.rootViewController setResumePsiphonStart:isOnboarding];
	[(WebViewController*)self.window.rootViewController setShowTutorial:isOnboarding];

	return YES;
}

- (void)reloadOnboardingForl10n {
	WebViewController *newOnboarding = [[WebViewController alloc] init];
	newOnboarding.restorationIdentifier = @"WebViewController";
	newOnboarding.resumePsiphonStart = YES;
	newOnboarding.showTutorial = YES;

	[self changeRootViewController:newOnboarding];
}

// From https://gist.github.com/gimenete/53704124583b5df3b407
- (void)changeRootViewController:(UIViewController*)viewController {
	if (!self.window.rootViewController) {
		self.window.rootViewController = viewController;
		return;
	}

	UIViewController *prevViewController = self.window.rootViewController;

	UIView *snapShot = [self.window snapshotViewAfterScreenUpdates:YES];
	[viewController.view addSubview:snapShot];

	self.window.rootViewController = viewController;

	[prevViewController dismissViewControllerAnimated:NO completion:^{
		// Remove the root view in case it is still showing
		[prevViewController.view removeFromSuperview];
	}];

	[UIView animateWithDuration:.3 animations:^{
		snapShot.layer.opacity = 0;
		snapShot.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5);
	} completion:^(BOOL finished) {
		[snapShot removeFromSuperview];
	}];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Migrate old cookie policy values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	// Casting nil to 0 is OK here:
	int lastBuildNumber = (int)[defaults integerForKey:kBuildNumber];
	[CookieJar migrateOldValuesForVersion:lastBuildNumber];

	// Store build number for any future references
	int buildNumber = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] intValue];
	[defaults setInteger:buildNumber forKey:kBuildNumber];

	[self.window makeKeyAndVisible];
	return YES;
}

- (int) getSocksProxyPort {
	return (int)[self.psiphonTunnel getLocalSocksProxyPort];
}

- (int) getHttpProxyPort {
	return (int)[self.psiphonTunnel getLocalHttpProxyPort];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	if (![self areTesting]) {
		[[self hstsCache] persist];
	}

	if ([userDefaults boolForKey:@"clearAllWhenBackgrounded"]) {
		[[self webViewController] removeAllTabsForBackgrounded];
		[CookieJar clearAllData];
	}

	if(_appActiveTimer && [_appActiveTimer isValid]) {
		// make timer selector get called on its target immediately
		[_appActiveTimer fire];
		[_appActiveTimer invalidate];
		_appActiveTimer = nil;
	}

	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kHasBeenOnboardedKey]) {
		[self startPsiphonOnlyIfNeeded:YES];
	}
	// If the key kAppActiveTimeSinceLastHomePage exists
	// then we opened a home page at least once
	// App active timer should be started right after
	// the app becomes active in that case
	BOOL shouldStartTimer = ([[NSUserDefaults standardUserDefaults] objectForKey:kAppActiveTimeSinceLastHomePage] != nil);
	if(shouldStartTimer) {
		[self startAppActiveTimer];
	}
}

- (void) startAppActiveTimer {
	if (!_appActiveTimer || ![_appActiveTimer isValid]) {
		_lastActiveTickTime = (NSInteger)CACurrentMediaTime();
		_appActiveTimer = [NSTimer scheduledTimerWithTimeInterval:APP_ACTIVE_TIMER_INTERVAL_SECONDS
														   target:self
														 selector:@selector(onAppActiveTimerTick:)
														 userInfo:nil
														  repeats:YES];
	}
	// make timer selector get called on its target immediately once
	[_appActiveTimer fire];
}

- (ConnectionState)getConnectionState {
	return (ConnectionState)[self.psiphonTunnel getConnectionState];
}

-(void)startPsiphonOnlyIfNeeded:(BOOL)ifNeeded {
	dispatch_async(dispatch_get_main_queue(), ^{
		// Start the Psiphon tunnel
		if (![self.psiphonTunnel start:ifNeeded]) {
			NSLog(@"Psiphon Tunnel start:%@ failed", ifNeeded ? @"YES" : @"NO");
			// TODO: what to show?
		}

		// A state change notification will be received from the tunnel
	});
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/* this definitely ends our sessions */
	[_psiphonTunnel stop];
	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
#ifdef DEBUG
	NSLog(@"request to open url \"%@\"", url);
#endif
	if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttp"])
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttp" length]) withString:@"http"]];
	else if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttps"])
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttps" length]) withString:@"https"]];

	[[self webViewController] dismissViewControllerAnimated:YES completion:nil];
	[[self webViewController] addNewTabForURL:url];

	return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
	if ([self areTesting])
		return NO;

	/* if we tried last time and failed, the state might be corrupt */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults objectForKey:STATE_RESTORE_TRY_KEY] != nil) {
		NSLog(@"previous startup failed, not restoring application state");
		[userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
		return NO;
	}
	else
		[userDefaults setBool:YES forKey:STATE_RESTORE_TRY_KEY];

	[userDefaults synchronize];

	return YES;
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
	if ([self areTesting])
		return NO;

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults boolForKey:@"clearAllWhenBackgrounded"])
		return NO;

	return YES;
}

-(void)initializeDefaultsFor:(NSString*)plist
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:plist];
	NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];

	for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
		NSString *key = [pref objectForKey:@"Key"];
		if (key == nil)
			continue;

		if ([userDefaults objectForKey:key] == NULL) {
			NSObject *val = [pref objectForKey:@"DefaultValue"];
			if (val == nil)
				continue;

			[userDefaults setObject:val forKey:key];
#ifdef TRACE
			NSLog(@"initialized default preference for %@ to %@", key, val);
#endif
		}
	}
	[userDefaults synchronize];
}

- (void)initializeDefaults
{
	[self initializeDefaultsFor:@"Root.inApp.plist"];
	[self initializeDefaultsFor:@"Feedback.plist"];
	[self initializeDefaultsFor:@"Security.plist"];
	[self initializeDefaultsFor:@"Privacy.plist"];
	[self initializeDefaultsFor:@"PsiphonSettings.plist"];
	[self initializeDefaultsFor:@"Notifications~iphone.plist"];
	[self initializeDefaultsFor:@"Notifications~ipad.plist"];

	_searchEngines = [NSMutableDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"SearchEngines.plist"]];
}

- (BOOL)areTesting
{
	return (NSClassFromString(@"XCTestProbe") != nil);
}

- (void)scheduleRunningTunnelServiceRestart {
	[self startPsiphonOnlyIfNeeded:YES];
}

+ (AppDelegate *)sharedAppDelegate{
	return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

- (void)onAppActiveTimerTick:(NSTimer *)timer {
	NSInteger elapsedInterval = (NSInteger)CACurrentMediaTime() - _lastActiveTickTime;
	if(elapsedInterval > 0) {
		NSInteger currentAppActiveTime = [[NSUserDefaults standardUserDefaults] integerForKey:kAppActiveTimeSinceLastHomePage];
		if(currentAppActiveTime < 0) {
			// Guard against defaults corruption.
			// We care less if the number is too large, worst case we will prematurely
			// open a home page on the next reconnect.
			currentAppActiveTime = 0;
		}
		NSInteger newAppActiveTime;

		if(!__builtin_add_overflow(currentAppActiveTime, elapsedInterval, &newAppActiveTime)){
			// no overlow, write new value to defaults
			[[NSUserDefaults standardUserDefaults] setInteger:(newAppActiveTime) forKey:kAppActiveTimeSinceLastHomePage];
		}
		// do nothing in case of overflow
	}

	_lastActiveTickTime = (NSInteger)CACurrentMediaTime();
}

// MARK: TunneledAppDelegate protocol implementation

- (NSString *) getPsiphonConfig {
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSString *bundledConfigPath = [[[ NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"psiphon_config"];
	if(![fileManager fileExistsAtPath:bundledConfigPath]) {
		NSLog(@"Config file not found. Aborting now.");
		abort();
	}

	//Read in psiphon_config JSON
	NSData *jsonData = [fileManager contentsAtPath:bundledConfigPath];
	NSError *e = nil;
	NSDictionary *readOnly = [NSJSONSerialization JSONObjectWithData: jsonData options: kNilOptions error: &e];

	NSMutableDictionary *mutableConfigCopy = [readOnly mutableCopy];

	if(e) {
		NSLog(@"Failed to parse config JSON. Aborting now.");
		abort();
	}

	NSString *selectedRegionCode = [[RegionAdapter sharedInstance] getSelectedRegion].code;
	mutableConfigCopy[@"EgressRegion"] = selectedRegionCode;

	NSString *upstreamProxyUrl = [[UpstreamProxySettings sharedInstance] getUpstreamProxyUrl];
	mutableConfigCopy[@"UpstreamProxyUrl"] = upstreamProxyUrl;

	BOOL disableTimeouts = [[NSUserDefaults standardUserDefaults] boolForKey:kDisableTimeouts];
	if (disableTimeouts) {
		mutableConfigCopy[@"TunnelConnectTimeoutSeconds"] = 0;
		mutableConfigCopy[@"TunnelPortForwardDialTimeoutSeconds"] = 0;
		mutableConfigCopy[@"TunnelSshKeepAliveProbeTimeoutSeconds"] = 0;
		mutableConfigCopy[@"TunnelSshKeepAlivePeriodicTimeoutSeconds"] = 0;
		mutableConfigCopy[@"FetchRemoteServerListTimeoutSeconds"] = 0;
		mutableConfigCopy[@"PsiphonApiServerTimeoutSeconds"] = 0;
		mutableConfigCopy[@"FetchRoutesTimeoutSeconds"] = 0;
		mutableConfigCopy[@"HttpProxyOriginServerTimeoutSeconds"] = 0;
	}

	mutableConfigCopy[@"ClientVersion"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

	mutableConfigCopy[@"EmitDiagnosticNotices"] = [NSNumber numberWithBool:TRUE];

	jsonData = [NSJSONSerialization dataWithJSONObject:mutableConfigCopy
											   options:0 // non-pretty printing
												 error:&e];
	if(e) {
		NSLog(@"Failed to create JSON data from config object. Aborting now.");
		abort();
	}
	return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *) getEmbeddedServerEntries {
	// Read in the embedded server entries
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *bundledEmbeddedServerEntriesPath = [[[ NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"embedded_server_entries"];
	NSString *embeddedServerEntries = [[NSString alloc] initWithData:[fileManager contentsAtPath:bundledEmbeddedServerEntriesPath] encoding:NSASCIIStringEncoding];
	if (!embeddedServerEntries) {
		NSLog(@"Embedded server entries file not found. Aborting now.");
		abort();
	}

	return embeddedServerEntries;
}

- (void) onAvailableEgressRegions:(NSArray *)regions {
	dispatch_async(dispatch_get_main_queue(), ^{
		[[RegionAdapter sharedInstance] onAvailableEgressRegions:regions];
	});
}

- (void) onDiagnosticMessage : (NSString*) message {
	dispatch_async(dispatch_get_main_queue(), ^{
#ifdef TRACE
		NSLog(@"onDiagnosticMessage: %@", message);
#endif
		DiagnosticEntry *newDiagnosticEntry = [[DiagnosticEntry alloc] init:message];
		[[PsiphonData sharedInstance] addDiagnosticEntry:newDiagnosticEntry];
	});
}

- (void)onConnectionStateChangedFrom:(PsiphonConnectionState)oldState to:(PsiphonConnectionState)newState {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (newState == PsiphonConnectionStateConnecting) {
			// Clear out any previous home pages, as we'll get more from the new server
			if(_handshakeHomePages && [_handshakeHomePages count] > 0) {
				[_handshakeHomePages removeAllObjects];
			}
		}
		else if (newState == PsiphonConnectionStateConnected) {
			[JAHPAuthenticatingHTTPProtocol resetSharedDemux];

			NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

			if ([userDefaults boolForKey:@"vibrate_notification"]) {
				AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
			}

			if ([userDefaults boolForKey:@"sound_notification"]) {
				AudioServicesPlaySystemSound (_notificationSound);
			}

			// If kAppActiveTimeSinceLastHomePage doesn't exist then it is probably the very first app run
			// and we should show a home page
			BOOL shouldOpenHomePage = ([[NSUserDefaults standardUserDefaults] objectForKey:kAppActiveTimeSinceLastHomePage] == nil);
			NSLog(@"shouldOpenHomePage == %@ , kAppActiveTimeSinceLastHomePage exists == %@", shouldOpenHomePage ? @"YES" : @"NO", !shouldOpenHomePage ? @"YES" : @"NO");

			if(!shouldOpenHomePage) {
				// Check if enough uptime has passed and we should show a home page
				NSInteger activeTime = [[NSUserDefaults standardUserDefaults] integerForKey:kAppActiveTimeSinceLastHomePage];

				// If activeTime is negative then defaults are probably corrupted
				// Fix it by showing a home page which will also reset the corrupted value to 0
				shouldOpenHomePage = (activeTime < 0 || activeTime > APP_ACTIVE_TIME_BEFORE_NEXT_HOMEPAGE_SECONDS);
#ifdef TRACE
				NSLog(@"shouldOpenHomePage == %@, App active time == %ld, APP_ACTIVE_TIME_BEFORE_NEXT_HOMEPAGE_SECONDS == %d", shouldOpenHomePage ? @"YES" : @"NO", activeTime, APP_ACTIVE_TIME_BEFORE_NEXT_HOMEPAGE_SECONDS);
#endif
			}

			if(!shouldOpenHomePage) {
				// Check if there are any tabs. If none then we should show a home page
				shouldOpenHomePage = ([[[self webViewController] webViewTabs] count]== 0);
				if(!shouldOpenHomePage) {
					// Set current index if restoration tab.
					// That will refresh the tab's content.
					[[self webViewController] setRestorationTabCurrent];
				}
#ifdef TRACE
				NSLog(@"shouldOpenHomePage == %@, [[[self webViewController] webViewTabs] count]== %lu", shouldOpenHomePage ? @"YES" : @"NO", (unsigned long)[[[self webViewController] webViewTabs] count]);
#endif
			}

			if(shouldOpenHomePage) {
				if(_handshakeHomePages && [_handshakeHomePages count] > 0) {
					// pick single URL from the handshake
					NSString *selectedHomePage = _handshakeHomePages[0];

					[self.webViewController openPsiphonHomePage: selectedHomePage];

					// If the key kAppActiveTimeSinceLastHomePage doesn't exist
					// we need to start app active timer
					// after opening a home page.
					// Otherwise it should be started when the app becomes active
					// in the - (void)applicationDidBecomeActive:(UIApplication *)application
					BOOL shouldStartTimer = ([[NSUserDefaults standardUserDefaults] objectForKey:kAppActiveTimeSinceLastHomePage] == nil);

					// Reset active time since last home page once we open a homepage
					// That will also create kAppActiveTimeSinceLastHomePage if it didn't exist
					[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kAppActiveTimeSinceLastHomePage];

					if(shouldStartTimer) {
						[self startAppActiveTimer];
					}
				}
			}
		}
	});

	[self notifyConnectionState];
}

- (void)onDeviceInternetConnectivityInterrupted {
	// Force a tunnel reconnect
	[self startPsiphonOnlyIfNeeded:NO];
}

- (void) onHomepage:(NSString *)url {
	if([url length] == 0) {
		return;
	}

	if (!_handshakeHomePages) {
		_handshakeHomePages = [NSMutableArray new];
	}

	if([_handshakeHomePages indexOfObject:url] == NSNotFound) {
		[_handshakeHomePages addObject:url];
	}
}

- (void) reloadAndOpenSettings {
	[[RegionAdapter sharedInstance] reloadTitlesForNewLocalization];

	// iterate existing tabs, remove them from superview
	// and re-add to the new instance of WebViewController

	WebViewController* prevWebViewController = self.webViewController;
	NSArray * wvTabs = [prevWebViewController webViewTabs];

	WebViewTab* focusedTab = [prevWebViewController curWebViewTab];

	WebViewController* wvc = [[WebViewController alloc] init];
	wvc.restorationIdentifier = @"WebViewController";
	[self changeRootViewController:wvc];

	for (WebViewTab *wvt in wvTabs) {
		BOOL isCurrentTab = NO;

		// make sure tabs get added zoomed normal
		[wvt zoomNormal];

		[wvt.viewHolder removeFromSuperview];
		if (focusedTab == wvt) {
			isCurrentTab = YES;
		}
		// Reload tab's localizables
		[wvt initLocalizables];

		[wvc addWebViewTab:wvt andSetCurrent:isCurrentTab];
	}

	[prevWebViewController dismissViewControllerAnimated:NO completion:^{
		// Remove the root view in case it is still showing
		[prevWebViewController.view removeFromSuperview];
	}];

	[self notifyConnectionState];
	[self.webViewController setOpenSettingImmediatelyOnViewDidAppear:YES];
}

- (void) notifyConnectionState {
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:kPsiphonConnectionStateNotification
		 object:self
		 userInfo:@{kPsiphonConnectionState: @([self.psiphonTunnel getConnectionState])}];
	});
}

// MARK: JAHPAuthenticatingHTTPProtocol delegate methods
#ifdef TRACE
- (void)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol logWithFormat:(NSString *)format arguments:(va_list)arguments {
	NSLog(@"[JAHPAuthenticatingHTTPProtocol] %@", [[NSString alloc] initWithFormat:format arguments:arguments]);
}
#endif

- (BOOL)authenticatingHTTPProtocol:( JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol canAuthenticateAgainstProtectionSpace:( NSURLProtectionSpace *)protectionSpace {
	return ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest]
			|| [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]);
}

- (JAHPDidCancelAuthenticationChallengeHandler)authenticatingHTTPProtocol:( JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol didReceiveAuthenticationChallenge:( NSURLAuthenticationChallenge *)challenge {
	NSURLCredential *nsuc;

	/* if we have existing credentials for this realm, try it first */
	if ([challenge previousFailureCount] == 0) {
		NSDictionary *d = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:[challenge protectionSpace]];
		if (d != nil) {
			for (id u in d) {
				nsuc = [d objectForKey:u];
				break;
			}
		}
	}

	/* no credentials, prompt the user */
	if (nsuc == nil) {
		dispatch_async(dispatch_get_main_queue(), ^{
			authAlertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Authentication Required", @"HTTP authentication  alert title") message:@"" preferredStyle:UIAlertControllerStyleAlert];

			if ([[challenge protectionSpace] realm] != nil && ![[[challenge protectionSpace] realm] isEqualToString:@""])
				[authAlertController setMessage:[NSString stringWithFormat:@"%@: \"%@\"", [[challenge protectionSpace] host], [[challenge protectionSpace] realm]]];
			else
				[authAlertController setMessage:[[challenge protectionSpace] host]];

			[authAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = NSLocalizedString(@"User Name", "HTTP authentication alert user name input title");
			}];

			[authAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = NSLocalizedString(@"Password", @"HTTP authentication alert password input title");
				textField.secureTextEntry = YES;
			}];

			[authAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
				[[challenge sender] cancelAuthenticationChallenge:challenge];
				[authenticatingHTTPProtocol.client URLProtocol:authenticatingHTTPProtocol didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{ ORIGIN_KEY: @YES }]];
			}]];

			[authAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Log In", @"HTTP authentication alert log in button action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				UITextField *login = authAlertController.textFields.firstObject;
				UITextField *password = authAlertController.textFields.lastObject;

				NSURLCredential *nsuc = [[NSURLCredential alloc] initWithUser:[login text] password:[password text] persistence:NSURLCredentialPersistenceForSession];

				// We only want one set of credentials per [challenge protectionSpace]
				// in case we stored incorrect credentials on the previous login attempt
				// Purge stored credentials for the [challenge protectionSpace]
				// before storing new ones.
				// Based on a snippet from http://www.springenwerk.com/2008/11/i-am-currently-building-iphone.html

				NSDictionary *credentialsDict = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:[challenge protectionSpace]];
				if ([credentialsDict count] > 0) {
					NSEnumerator *userNameEnumerator = [credentialsDict keyEnumerator];
					id userName;

					// iterate over all usernames, which are the keys for the actual NSURLCredentials
					while (userName = [userNameEnumerator nextObject]) {
						NSURLCredential *cred = [credentialsDict objectForKey:userName];
						if(cred) {
							[[NSURLCredentialStorage sharedCredentialStorage] removeCredential:cred forProtectionSpace:[challenge protectionSpace]];
						}
					}
				}

				[[NSURLCredentialStorage sharedCredentialStorage] setCredential:nsuc forProtectionSpace:[challenge protectionSpace]];

				[authenticatingHTTPProtocol resolvePendingAuthenticationChallengeWithCredential:nsuc];
			}]];

			[[[AppDelegate sharedAppDelegate] webViewController] presentViewController:authAlertController animated:YES completion:nil];
		});
	}
	else {
		[[NSURLCredentialStorage sharedCredentialStorage] setCredential:nsuc forProtectionSpace:[challenge protectionSpace]];
		[authenticatingHTTPProtocol resolvePendingAuthenticationChallengeWithCredential:nsuc];
	}

	return nil;

}

- (void)authenticatingHTTPProtocol:( JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol didCancelAuthenticationChallenge:( NSURLAuthenticationChallenge *)challenge {
	if(authAlertController) {
		if (authAlertController.isViewLoaded && authAlertController.view.window) {
			[authAlertController dismissViewControllerAnimated:NO completion:nil];
		}
	}
}





@end
