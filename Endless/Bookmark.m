/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "Bookmark.h"

@implementation Bookmark

static NSMutableArray *_list;

NSString * const BOOKMARK_KEY_NAME = @"name";
NSString * const BOOKMARK_KEY_URL = @"url";

NSString * const BOOKMARK_KEY_VERSION = @"version";
NSString * const BOOKMARK_KEY_LIST = @"bookmarks";

const int BOOKMARK_FILE_VERSION = 1;

+ (void)addDefaultBookmarks {
	[Bookmark addBookmarkForURLString:@"https://psiphon3.com" withName:@"Psiphon"];
	[Bookmark addBookmarkForURLString:@"https://m.facebook.com" withName:@"Facebook"];
	[Bookmark addBookmarkForURLString:@"https://mobile.twitter.com" withName:@"Twitter"];
	[Bookmark addBookmarkForURLString:@"https://m.youtube.com" withName:@"YouTube"];
	[Bookmark addBookmarkForURLString:@"https://gmail.com" withName:@"Gmail"];
	[Bookmark addBookmarkForURLString:@"https://instagram.com" withName:@"Instagram"];
	[Bookmark addBookmarkForURLString:@"https://google.com" withName:@"Google"];
	[Bookmark addBookmarkForURLString:@"https://duckduckgo.com" withName:@"DuckDuckGo"];
	[Bookmark addBookmarkForURLString:@"https://startpage.com" withName:@"StartPage"];
}

+ (NSString *)bookmarksPath
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [path stringByAppendingPathComponent:@"bookmarks.plist"];
}

+ (void)retrieveList
{
	_list = nil;

	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:[self bookmarksPath]]) {
		NSDictionary *bookmarks = [[NSDictionary alloc] initWithContentsOfFile:[self bookmarksPath]];

		NSNumber *v = [bookmarks objectForKey:BOOKMARK_KEY_VERSION];
		if (v != nil) {
			if ([v intValue] != BOOKMARK_FILE_VERSION)
				NSLog(@"need to handle bookmark list migration from version %d to %d", [v intValue], BOOKMARK_FILE_VERSION);

			NSArray *tlist = [bookmarks objectForKey:BOOKMARK_KEY_LIST];
			_list = [[NSMutableArray alloc] initWithCapacity:MIN(tlist.count, 5)];
			for (int i = 0; i < [tlist count]; i++)
				[_list addObject:[self unmarshall:tlist[i]]];
		}
	}

	if (_list == nil)
		_list = [[NSMutableArray alloc] initWithCapacity:5];
}

+ (NSMutableArray *)list
{
	return _list;
}

+ (void)persistList
{
	NSMutableDictionary *d = [[NSMutableDictionary alloc] init];

	NSMutableArray *t = [[NSMutableArray alloc] initWithCapacity:[_list count]];
	for (int i = 0; i < [_list count]; i++)
		[t addObject:((Bookmark *)_list[i]).marshallable];

	[d setObject:t forKey:BOOKMARK_KEY_LIST];
	[d setObject:[NSNumber numberWithInt:BOOKMARK_FILE_VERSION] forKey:BOOKMARK_KEY_VERSION];

	if ([d writeToFile:[self bookmarksPath] atomically:YES] == false)
		NSLog(@"failed writing bookmarks to %@", [self bookmarksPath]);
}

+ (Bookmark *)unmarshall:(NSDictionary *)marshalled
{
	Bookmark *b = [[Bookmark alloc] init];
	b.name = [marshalled objectForKey:BOOKMARK_KEY_NAME];
	b.url = [NSURL URLWithString:[marshalled objectForKey:BOOKMARK_KEY_URL]];
	return b;
}

+ (void)addBookmarkForURLString:(NSString *)urls withName:(NSString *)name;
{
	Bookmark *b = [[Bookmark alloc] init];

	NSURL *furl = [NSURL URLWithString:urls];
	if (![furl scheme] || [[furl scheme] isEqualToString:@""])
		furl = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urls]];

	if (![furl path] || [[furl path] isEqualToString:@""])
		furl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/", [furl absoluteString]]];

	b.url = furl;

	if (name && ![name isEqualToString:@""])
		b.name = name;
	else
		b.name = [NSString stringWithFormat:@"%@%@", [furl host], [[furl path] isEqualToString:@"/"] ? @"" : [furl path]];

	[[self list] addObject:b];
	[self persistList];
}

+ (BOOL)isURLBookmarked:(NSURL *)url
{
	for (int i = 0; i < [[Bookmark list] count]; i++) {
		Bookmark *b = [Bookmark list][i];

		if ([[[[b url] absoluteString] lowercaseString] isEqualToString:[[url absoluteString] lowercaseString]])
			return YES;
	}

	return NO;
}

+ (UIAlertController *)addBookmarkDialogWithOkCallback:(void (^)(void))callback
{
	WebViewTab *wvt = [[[AppDelegate sharedAppDelegate] webViewController] curWebViewTab];

	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ADD_BOOKMARK_TITLE", nil, [NSBundle mainBundle], @"Add Bookmark", @"'Add bookmark' dialog title")
																			 message:NSLocalizedStringWithDefaultValue(@"ADD_EDIT_BOOKMARK_TEXT", nil, [NSBundle mainBundle], @"Enter the details of the URL to bookmark:", @"'Add Bookmark' dialog text")
																	  preferredStyle:UIAlertControllerStyleAlert];
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = NSLocalizedStringWithDefaultValue(@"ADD_EDIT_BOOKMARK_URL", nil, [NSBundle mainBundle], @"URL", @"Add bookmark URL field");

		if (wvt && [wvt url])
			textField.text = [[wvt url] absoluteString];
	}];
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = NSLocalizedStringWithDefaultValue(@"ADD_EDIT_BOOKMARK_NAME", nil, [NSBundle mainBundle], @"Page Name (leave blank to use URL)", @"Add bookmark page name field");

		if (wvt && [wvt url])
			textField.text = [[wvt title] text];
	}];

	UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"OK_ACTION", nil, [NSBundle mainBundle], @"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		UITextField *url = alertController.textFields[0];
		UITextField *name = alertController.textFields[1];

		if (url && ![[url text] isEqualToString:@""]) {
			[Bookmark addBookmarkForURLString:[url text] withName:[name text]];

			if (callback != nil)
				callback();
		}
	}];

	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"CANCEL_ACTION", nil, [NSBundle mainBundle], @"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
	[alertController addAction:cancelAction];
	[alertController addAction:okAction];

	return alertController;
}


- (NSDictionary *)marshallable
{
	/* can only have basic things like NSArray, NSString, etc. or writing will fail */

	return @{
			 BOOKMARK_KEY_NAME: self.name,
			 BOOKMARK_KEY_URL: self.url.absoluteString,
			 };
}

- (NSString *)urlString
{
	return [self.url absoluteString];
}

- (void)setUrlString:(NSString *)urls
{
	self.url = [NSURL URLWithString:urls];
}

@end
