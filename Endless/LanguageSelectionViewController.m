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

#import "LanguageSelectionViewController.h"

@implementation LanguageSettings {
	NSArray<NSString*> *languageCodes;
	NSArray<NSString*> *languageNames;
}

- (id)init {
	self = [super init];

	if (self) {
		// Get language names and language codes from Root.inApp.plist
		NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:@"Root.inApp.plist"];

		NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];

		for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
			NSString *key = [pref objectForKey:@"Key"];

			if (key != nil && [key isEqualToString:appLanguage]) {
				languageCodes = [pref objectForKey:@"Values"];
				languageNames = [pref objectForKey:@"Titles"];

				if (languageCodes.count != languageNames.count || languageCodes.count == 0) {
					[NSException raise:@"Invalid appLanguage specifier in Root.inApp.plist." format:@"Titles and Values arrays should have the same number of entries and a length greater than 0. Got languageNames.count = %lu and languageCodes.count = %lu", (unsigned long)languageNames.count, (unsigned long)languageCodes.count];
				}
				break;
			}
		}
	}

	return self;
}

- (NSString*)getCurrentLanguageCode {
	return [[NSUserDefaults standardUserDefaults] stringForKey:appLanguage];
}

- (NSArray<NSString*>*)getLanguageCodes {
	return languageCodes;
}

- (NSArray<NSString*>*)getLanguageNames {
	return languageNames;
}

@end

// Table view in onboarding which allows the
// user to select their desired language.
// Based on RegionSelectionViewController.
// Contingent on appLanguage specifier in Root.inApp.plist
// being setup correctly with a 1 to 1 mapping between "Values" as
// language codes and "Titles" as language names.
@implementation LanguageSelectionViewController {
	NSInteger selectedRow;

	NSString *currentLanguageCode;
	NSArray *languageCodes;
	NSArray *languageNames;
}

- (void)dismiss:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	self.title = NSLocalizedStringWithDefaultValue(@"LANGUAGE_SELECT_TITLE", nil, [NSBundle mainBundle], @"Language", @"Text above language selection box");
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
																				  target:self
																				  action:@selector(dismiss:)];
	self.navigationItem.leftBarButtonItem = cancelButton;

	LanguageSettings *languageSettings = [[LanguageSettings alloc] init];
	currentLanguageCode = [languageSettings getCurrentLanguageCode];
	languageCodes = [languageSettings getLanguageCodes];
	languageNames = [languageSettings getLanguageNames];

	/* Setup table */
	self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
	self.table.delegate = self;
	self.table.dataSource = self;
	self.table.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);

	self.table.tableHeaderView = nil;
	self.table.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;

	[self.view addSubview:self.table];
}

#pragma mark - UITableView delegate methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *language = [languageNames objectAtIndex:indexPath.row];
	NSString *languageCode = [languageCodes objectAtIndex:indexPath.row];

	NSString *identifier = [NSString stringWithFormat:@"%@", language];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
	}

	// We only want to localize "Default Language",
	// not the already localized language names.
	if (indexPath.row == kDefaultLanguageRow) {
		cell.textLabel.text = [[NSBundle mainBundle] localizedStringForKey:language value:language table:@"Root"];
	} else {
		cell.textLabel.text = language;
	}

	cell.userInteractionEnabled = YES;

	if ([languageCode isEqualToString:currentLanguageCode]) {
		selectedRow = indexPath.row;
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}

	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// De-select cell of currently selected language
	NSUInteger currentIndex[2];
	currentIndex[0] = 0;
	currentIndex[1] = selectedRow;
	NSIndexPath *currentIndexPath = [[NSIndexPath alloc] initWithIndexes:currentIndex length:2];
	UITableViewCell *currentlySelectedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
	currentlySelectedCell.accessoryType = UITableViewStylePlain; // Remove checkmark

	// Select cell of newly chosen language
	NSIndexPath *newIndexPath = [tableView indexPathForSelectedRow];
	UITableViewCell *newlySelectedCell = [tableView cellForRowAtIndexPath:newIndexPath];
	newlySelectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];

	if (indexPath.row != selectedRow) {
		// Update selected language
		NSString *selectedLanguageKey = [languageCodes objectAtIndex:indexPath.row];
		[[NSUserDefaults standardUserDefaults] setValue:selectedLanguageKey forKey:appLanguage];

		// Reload onboarding for new l10n
		[[AppDelegate sharedAppDelegate] reloadOnboardingForl10n];
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return languageNames.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

@end
