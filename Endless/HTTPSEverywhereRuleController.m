/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "HTTPSEverywhereRuleController.h"
#import "HTTPSEverywhere.h"
#import "HTTPSEverywhereRule.h"

@implementation HTTPSEverywhereRuleController

- (id)initWithStyle:(UITableViewStyle)style
{
	self = [super initWithStyle:style];

	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"DONE_ACTION", nil, [NSBundle mainBundle], @"Done", @"Done action") style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];

	self.sortedRuleNames = [[NSMutableArray alloc] initWithCapacity:[[HTTPSEverywhere rules] count]];

	if ([[[AppDelegate sharedAppDelegate] webViewController] curWebViewTab] != nil) {
		self.inUseRuleNames = [[NSMutableArray alloc] initWithArray:[[[[[[AppDelegate sharedAppDelegate] webViewController] curWebViewTab] applicableHTTPSEverywhereRules] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
	}
	else {
		self.inUseRuleNames = [[NSMutableArray alloc] init];
	}

	for (NSString *k in [[HTTPSEverywhere rules] allKeys]) {
		if (![self.inUseRuleNames containsObject:k])
			[self.sortedRuleNames addObject:k];
	}

	self.sortedRuleNames = [NSMutableArray arrayWithArray:[self.sortedRuleNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
	self.searchResult = [NSMutableArray arrayWithCapacity:[self.sortedRuleNames count]];

	self.title = NSLocalizedStringWithDefaultValue(@"HTTPSEVERYWHERE_MENU_TITLE", nil, [NSBundle mainBundle], @"HTTPS Everywhere Rules", @"HTTPS Everywhere menu title");

	return self;
}

- (NSString *)ruleDisabledReason:(NSString *)rule
{
	return [[HTTPSEverywhere disabledRules] objectForKey:rule];
}

- (void)disableRuleByName:(NSString *)rule withReason:(NSString *)reason
{
	[HTTPSEverywhere disableRuleByName:rule withReason:reason];
}

- (void)enableRuleByName:(NSString *)rule
{
	[HTTPSEverywhere enableRuleByName:rule];
}

@end
