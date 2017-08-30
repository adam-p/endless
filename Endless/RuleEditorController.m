/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "RuleEditorController.h"

@implementation RuleEditorController

UISearchController *searchController;

- (id)initWithStyle:(UITableViewStyle)style
{
	self = [super initWithStyle:style];

	self.sortedRuleNames = [[NSMutableArray alloc] init];
	self.inUseRuleNames = [[NSMutableArray alloc] init];

	self.searchResult = [[NSMutableArray alloc] init];

	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];

	searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	searchController.searchResultsUpdater = self;
	searchController.dimsBackgroundDuringPresentation = NO;
	searchController.searchBar.delegate = self;
	[[self tableView] setTableHeaderView:searchController.searchBar];
	[searchController.searchBar sizeToFit];

}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
		return NSLocalizedStringWithDefaultValue(@"RULES_CURRENT_PAGE_LIST_TITLE", nil, [NSBundle mainBundle], @"Rules in use on current page", @"Title above a list of rules in use");
	else
		return NSLocalizedStringWithDefaultValue(@"RULES_ALL_LIST_TITLE", nil, [NSBundle mainBundle], @"All rules", @"Title above a list of rules");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
		return [self.inUseRuleNames count];
	else if (searchController.active && ![searchController.searchBar.text  isEqual:@""])
		return [self.searchResult count];
	else
		return [self.sortedRuleNames count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rule"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"rule"];

	/* TODO: once we have a per-rule view page, enable this */
	//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	cell.textLabel.text = [self ruleForTableView:tableView atIndexPath:indexPath];

	NSString *disabled = [self ruleDisabledReason:cell.textLabel.text];
	if (disabled == nil) {
		cell.textLabel.textColor = [UIColor darkTextColor];
		cell.detailTextLabel.text = nil;
	}
	else {
		cell.textLabel.textColor = [UIColor redColor];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"Disabled: %@", disabled];
		cell.detailTextLabel.textColor = [UIColor redColor];
	}

	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *row = [self ruleForTableView:tableView atIndexPath:indexPath];

		if ([self ruleDisabledReason:row] == nil)
			[self disableRuleByName:row withReason:@"User disabled"];
		else
			[self enableRuleByName:row];
	}

	[tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
	NSString *searchString = searchController.searchBar.text;
	[self.searchResult removeAllObjects];

	for (NSString *ruleName in self.sortedRuleNames) {
		NSRange range = [ruleName rangeOfString:searchString options:NSCaseInsensitiveSearch];

		if (range.length > 0)
			[self.searchResult addObject:ruleName];
	}
	[self.tableView reloadData];
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *row = [self ruleForTableView:tableView atIndexPath:indexPath];

	if ([self ruleDisabledReason:row] == nil)
		return @"Disable";
	else
		return @"Enable";
}

- (NSString *)ruleForTableView:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath
{
	NSMutableArray *group;

	if ([indexPath section] == 0)
		group = [self inUseRuleNames];
	else if (searchController.active && ![searchController.searchBar.text  isEqual:@""])
		group = [self searchResult];
	else
		group = [self sortedRuleNames];

	if (group && [group count] > [indexPath row])
		return [group objectAtIndex:indexPath.row];
	else
		return nil;
}

- (NSString *)ruleDisabledReason:(NSString *)rule
{
	return nil;
}

- (void)disableRuleByName:(NSString *)rule withReason:(NSString *)reason
{
	abort();
}

- (void)enableRuleByName:(NSString *)rule
{
	abort();
}

@end
