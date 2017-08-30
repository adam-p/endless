/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "Bookmark.h"
#import "BookmarkController.h"

@interface EditViewContainer : UIControl
@property (strong, nonatomic) Bookmark *bookmark;
@end

@implementation EditViewContainer
@end

@interface BookmarkCell : UITableViewCell
@property (strong, nonatomic) EditViewContainer *editViewContainer;
@end

@implementation BookmarkCell {
	NSLayoutConstraint *editViewContainerWidth;

	BOOL isRTL;
}

@synthesize editViewContainer;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

	if (self) {
		/* Setup bookmark edit button which appears on each cell when in edit mode */

		// Setup views
		editViewContainer = [[EditViewContainer alloc] init];
		[self.contentView addSubview:editViewContainer];

		UIImage *editImage = [UIImage imageNamed:@"edit"];
		UIImageView *editView = [[UIImageView alloc] initWithImage:editImage];
		[editViewContainer addSubview:editView];

		// Setup autolayout constraints
		self.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
		editViewContainer.translatesAutoresizingMaskIntoConstraints = NO;
		editView.translatesAutoresizingMaskIntoConstraints = NO;

		// editViewContainer
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:editViewContainer
																	 attribute:isRTL ? NSLayoutAttributeLeft : NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:isRTL ? NSLayoutAttributeLeftMargin : NSLayoutAttributeRightMargin
																	multiplier:1.0f
																	  constant:0.f]];

		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:editViewContainer
																	 attribute:NSLayoutAttributeCenterY
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeCenterY
																	multiplier:1.0f
																	  constant:0.f]];

		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:editViewContainer
																	 attribute:NSLayoutAttributeTop
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeTop
																	multiplier:1.0f
																	  constant:0.f]];

		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:editViewContainer
																	 attribute:NSLayoutAttributeBottom
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeBottom
																	multiplier:1.0f
																	  constant:0.f]];

		editViewContainerWidth = [NSLayoutConstraint constraintWithItem:editViewContainer
															  attribute:NSLayoutAttributeWidth
															  relatedBy:NSLayoutRelationEqual
																 toItem:editViewContainer
															  attribute:NSLayoutAttributeHeight
															 multiplier:.0f
															   constant:0.f];
		[self.contentView addConstraint:editViewContainerWidth];

		// editView
		[editViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:editView
																	  attribute:NSLayoutAttributeHeight
																	  relatedBy:NSLayoutRelationEqual
																		 toItem:editViewContainer
																	  attribute:NSLayoutAttributeHeight
																	 multiplier:.75f
																	   constant:0.f]];

		[editViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:editView
																	  attribute:NSLayoutAttributeWidth
																	  relatedBy:NSLayoutRelationEqual
																		 toItem:editViewContainer
																	  attribute:NSLayoutAttributeWidth
																	 multiplier:.75f
																	   constant:0.f]];

		[editViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:editView
																	  attribute:NSLayoutAttributeCenterX
																	  relatedBy:NSLayoutRelationEqual
																		 toItem:editViewContainer
																	  attribute:NSLayoutAttributeCenterX
																	 multiplier:1.0f
																	   constant:0.f]];

		[editViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:editView
																	  attribute:NSLayoutAttributeCenterY
																	  relatedBy:NSLayoutRelationEqual
																		 toItem:editViewContainer
																	  attribute:NSLayoutAttributeCenterY
																	 multiplier:1.0f
																	   constant:0.f]];

		// textLabel
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.textLabel
																	 attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:isRTL ? NSLayoutAttributeRightMargin : NSLayoutAttributeLeftMargin
																	multiplier:1.0f
																	  constant:0.f]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.textLabel
																	 attribute:isRTL ? NSLayoutAttributeLeft : NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationEqual
																		toItem:editViewContainer
																	 attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
																	multiplier:1.0f
																	  constant:0.f]];

		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.textLabel
																	 attribute:NSLayoutAttributeHeight
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeHeight
																	multiplier:.6f
																	  constant:0.f]];

		// detailTextLabel
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.detailTextLabel
																	 attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.textLabel
																	 attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
																	multiplier:1.0f
																	  constant:0.f]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.detailTextLabel
																	 attribute:NSLayoutAttributeBottom
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeBottom
																	multiplier:1.0f
																	  constant:0.f]];

		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.detailTextLabel
																	 attribute:isRTL ? NSLayoutAttributeLeft : NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationEqual
																		toItem:editViewContainer
																	 attribute:isRTL ? NSLayoutAttributeRight : NSLayoutAttributeLeft
																	multiplier:1.0f
																	  constant:0.f]];

		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.detailTextLabel
																	 attribute:NSLayoutAttributeTop
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.textLabel
																	 attribute:NSLayoutAttributeBottom
																	multiplier:1.0f
																	  constant:0.f]];

		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.detailTextLabel
																	 attribute:NSLayoutAttributeHeight
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeHeight
																	multiplier:.4f
																	  constant:0.f]];
	}

	return self;
}

- (void)setEditing:(BOOL)editing {
	[super setEditing:editing];

	[self updateConstraintsForEditing:editing];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];

	// Do not perform any animations
	[self updateConstraintsForEditing:editing];
}

- (void)updateConstraintsForEditing:(BOOL)editing {
	[self.contentView removeConstraint:editViewContainerWidth];
	editViewContainerWidth = [NSLayoutConstraint constraintWithItem:editViewContainer
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:editViewContainer
														  attribute:NSLayoutAttributeHeight
														 multiplier:editing ? 1.f : .0f
														   constant:0.f];
	[self.contentView addConstraint:editViewContainerWidth];
}

@end

@implementation BookmarkController {
	UIBarButtonItem *addItem;
	UIBarButtonItem *leftItem;
}

BOOL isRTL;

- (void)viewDidLoad
{
	[super viewDidLoad];

	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	self.title = NSLocalizedStringWithDefaultValue(@"BOOKMARKS_TITLE", nil, [NSBundle mainBundle], @"Bookmarks", @"Bookmarks main dialog title");
	self.navigationItem.rightBarButtonItem = addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem:)];
	self.navigationItem.leftBarButtonItem = leftItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"DONE_ACTION", nil, [NSBundle mainBundle], @"Done", @"Done action")
																						style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
	self.navigationController.toolbarHidden = NO;
	[self setBarButtonItemsForEditing:NO];

	UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
	lpgr.minimumPressDuration = 0.75f;
	lpgr.delegate = self;
	[[self tableView] addGestureRecognizer:lpgr];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[Bookmark persistList];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[Bookmark list] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (self.embedded)
		return NSLocalizedStringWithDefaultValue(@"BOOKMARKS_TITLE", nil, [NSBundle mainBundle], @"Bookmarks", @"Bookmarks table header title");
	else
		return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	BookmarkCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bookmark"];
	if (cell == nil)
		cell = [[BookmarkCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"bookmark"];

	Bookmark *b = [[Bookmark list] objectAtIndex:indexPath.row];
	if (b != nil) {
		cell.textLabel.text = b.name;
		cell.detailTextLabel.text = b.urlString;
	}

	[cell setShowsReorderControl:YES];

	[cell.editViewContainer addTarget:self action:@selector(editButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

	cell.editViewContainer.bookmark = b;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Bookmark *bookmark = [Bookmark list][[indexPath row]];

	if (self.embedded)
		[[[AppDelegate sharedAppDelegate] webViewController] prepareForNewURLFromString:[bookmark urlString]];
	else {
		[[AppDelegate sharedAppDelegate].webViewController addNewTabForURL:bookmark.url];
	}

	[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[[Bookmark list] removeObjectAtIndex:[indexPath row]];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
	Bookmark *s = [Bookmark list][[sourceIndexPath row]];
	[[Bookmark list] removeObjectAtIndex:[sourceIndexPath row]];
	[[Bookmark list] insertObject:s atIndex:[destinationIndexPath row]];
}

- (void)didLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
	if (!self.embedded) {
		CGPoint p = [gestureRecognizer locationInView:[self tableView]];

		NSIndexPath *indexPath = [[self tableView] indexPathForRowAtPoint:p];
		if (gestureRecognizer.state == UIGestureRecognizerStateBegan && indexPath != nil) {

			[[self tableView] setEditing:YES animated:YES];

			self.navigationItem.rightBarButtonItem = nil;
			self.navigationItem.leftBarButtonItem = nil;
			[self setBarButtonItemsForEditing:YES];
		}
	}
}

- (void)editButtonPressed:(EditViewContainer *)sender {
	Bookmark *bookmark = sender.bookmark;

	if (self.embedded)
		[[[AppDelegate sharedAppDelegate] webViewController] prepareForNewURLFromString:[bookmark urlString]];
	else {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"EDIT_BOOKMARK_TITLE", nil, [NSBundle mainBundle], @"Edit Bookmark", @"Edit Bookmark dialog title")
																				 message:NSLocalizedStringWithDefaultValue(@"ADD_EDIT_BOOKMARK_TEXT", nil, [NSBundle mainBundle], @"Enter the details of the URL to bookmark:", @"'Edit Bookmark' dialog text")
																		  preferredStyle:UIAlertControllerStyleAlert];
		[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.placeholder = NSLocalizedStringWithDefaultValue(@"ADD_EDIT_BOOKMARK_URL", nil, [NSBundle mainBundle], @"URL", @"'Edit Bookmark' dialog URL field");
			textField.text = bookmark.urlString;
		}];
		[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.placeholder = NSLocalizedStringWithDefaultValue(@"ADD_EDIT_BOOKMARK_NAME", nil, [NSBundle mainBundle], @"Page Name (leave blank to use URL)", @"'Edit Bookmark' dialog page name field");
			textField.text = bookmark.name;
		}];

		__weak  BookmarkController *weakSelf = self;
		UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"OK_ACTION", nil, [NSBundle mainBundle], @"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			UITextField *url = alertController.textFields[0];
			bookmark.urlString = [url text];

			UITextField *name = alertController.textFields[1];
			bookmark.name = [name text];

			[weakSelf.tableView reloadData];
		}];

		UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"CANCEL_ACTION", nil, [NSBundle mainBundle], @"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
		[alertController addAction:cancelAction];
		[alertController addAction:okAction];

		[self presentViewController:alertController animated:YES completion:nil];
	}
}

- (void)setBarButtonItemsForEditing:(BOOL)forEditing {
	UIBarButtonItem *b = [[UIBarButtonItem alloc] initWithTitle:forEditing ? NSLocalizedStringWithDefaultValue(@"DONE_ACTION", nil, [NSBundle mainBundle], @"Done", @"Done action") : NSLocalizedStringWithDefaultValue(@"BOOKMARKS_EDIT_BUTTON", nil, [NSBundle mainBundle], @"Edit", @"Edit button at bottom of screen in bookmarks view")
														  style:UIBarButtonItemStylePlain
														 target:self
														 action:forEditing ? @selector(hideEdit) : @selector(showEdit)];

	UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];

	NSArray *buttonArray = [[NSArray alloc] initWithObjects:flex, b, nil];

	[self setToolbarItems:buttonArray animated:NO];
}

- (void)showEdit {
	[self setBarButtonItemsForEditing:YES];
	self.navigationItem.rightBarButtonItem = nil;
	self.navigationItem.leftBarButtonItem = nil;
	[[self tableView] setEditing:YES animated:YES];
}

- (void)hideEdit {
	[self setBarButtonItemsForEditing:NO];
	self.navigationItem.rightBarButtonItem = addItem;
	self.navigationItem.leftBarButtonItem = leftItem;
	[[self tableView] setEditing:NO animated:YES];
}

- (void)addItem:sender
{
	UIAlertController *uiac = [Bookmark addBookmarkDialogWithOkCallback:^{
		[self.tableView reloadData];
	}];

	[self presentViewController:uiac animated:YES completion:nil];
}

@end
