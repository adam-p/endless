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


#import "FeedbackUpload.h"
#import "PsiphonData.h"
#import <PsiphonTunnel/JailbreakCheck.h>

#define kThumbIndexUnselected -1
#define kQuestionHash "24f5c290039e5b0a2fd17bfcdb8d3108"
#define kQuestionTitle "Overall satisfaction"

#define safeNullable(x) x != nil ? x : @""

@interface Feedback : NSObject

@end

@implementation Feedback {
	NSString *title;
}

@end

@implementation FeedbackUpload

// Form and send feedback blob which conforms to structure
// expected by the feedback template for ios,
// https://bitbucket.org/psiphon/psiphon-circumvention-system/src/default/EmailResponder/FeedbackDecryptor/templates/?at=default
// Matching format used by android client,
// https://bitbucket.org/psiphon/psiphon-circumvention-system/src/default/Android/app/src/main/java/com/psiphon3/psiphonlibrary/Diagnostics.java
// TODO: will fail silently on any errors
+ (void)generateAndSendFeedback:(NSInteger)thumbIndex
					   comments:(NSString*)comments
						  email:(NSString*)email
			 sendDiagnosticInfo:(BOOL)sendDiagnosticInfo
			  withPsiphonConfig:(NSString*)psiphonConfig {

	NSDictionary *config = [FeedbackUpload jsonToDictionary:psiphonConfig];
	if (config == nil) {
		return;
	}

	NSMutableDictionary *feedbackBlob = [[NSMutableDictionary alloc] init];

	// Ensure the survey response is valid
	if (thumbIndex < -1 || thumbIndex > 1) {
		return;
	}

	// Ensure either feedback or survey response was completed
	if (thumbIndex == -1 && sendDiagnosticInfo == false && comments.length == 0 && email.length == 0) {
		return;
	}

	// Check survey response
	NSString *surveyResponse = @"";
	if (thumbIndex != kThumbIndexUnselected) {
		surveyResponse = [NSString stringWithFormat:@"[{\"answer\":%ld,\"question\":\"%s\", \"title\":\"%s\"}]", (long)thumbIndex, kQuestionHash, kQuestionTitle];
	}

	NSDictionary *feedback = @{
							   @"email": safeNullable(email),
							   @"Message":  @{@"text": safeNullable(comments)},
							   @"Survey": @{@"json": safeNullable(surveyResponse)}
							   };
	[feedbackBlob setObject:feedback forKey:@"Feedback"];

	// If user decides to disclose diagnostics data
	if (sendDiagnosticInfo == YES) {
		NSMutableArray *diagnosticHistoryArray = [[NSMutableArray alloc] init];

		for (DiagnosticEntry *d in [[PsiphonData sharedInstance] diagnosticHistory]) {
			NSDictionary *entry = @{
									@"data": [d data],
									@"msg": [d message],
									@"timestamp!!timestamp": [d getTimestampISO8601]
									};
			[diagnosticHistoryArray addObject:entry];
		}

		NSMutableArray *statusHistoryArray = [[NSMutableArray alloc] init];

		for (StatusEntry *s in [[PsiphonData sharedInstance] statusHistory]) {
			// Don't send any sensitive logs or debug logs
			if (s.sensitivity == SensitivityLevelSensitiveLog || s.priority == PriorityDebug) {
				continue;
			}
			NSMutableDictionary *entry =
			[NSMutableDictionary dictionaryWithDictionary: @{
															 @"id": s.id,
															 @"timestamp!!timestamp": [s getTimestampISO8601],
															 @"priority": @(s.priority)
															 }];

			NSArray *f = s.formatArgs;
			if ([f count] > 0 && s.sensitivity != SensitivityLevelSensitiveFormatArgs) {
				[entry setObject:f forKey:@"formatArgs"];
			} else {
				[entry setObject:@[] forKey:@"formatArgs"];
			}

			Throwable *t = s.throwable;
			if (t != nil) {
				NSDictionary *throwable = @{
											@"message": t.message,
											@"stack": t.stackTrace
											};
				[entry setObject:throwable forKey:@"throwable"];
			}

			[statusHistoryArray addObject:entry];
		}

		NSDictionary *diagnosticInfo = @{
										 @"DiagnosticHistory": diagnosticHistoryArray,
										 @"StatusHistory": statusHistoryArray,
										 @"SystemInformation":
											 @{
												 @"Build": [FeedbackUpload gatherDeviceInfo],
												 @"PsiphonInfo":
													 @{
														 @"CLIENT_VERSION": safeNullable([[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]),
														 @"PROPAGATION_CHANNEL_ID": [config objectForKey:@"PropagationChannelId"],
														 @"SPONSOR_ID": [config objectForKey: @"SponsorId"]
														 },
												 @"isAppStoreBuild": @YES,
												 @"isJailbroken": [JailbreakCheck isDeviceJailbroken] ? @YES : @NO,
												 @"language": safeNullable([[NSUserDefaults standardUserDefaults] objectForKey:appLanguage]),
												 @"networkTypeName": [FeedbackUpload getConnectionType]
												 }
										 };
		[feedbackBlob setObject:diagnosticInfo forKey:@"DiagnosticInfo"];
	}

	NSString *rndmHexId = [FeedbackUpload generateFeedbackId];
	if (rndmHexId == nil) {
		return;
	}

	NSDictionary *metadata = @{
							   @"id": rndmHexId,
							   @"platform": @"ios-browser",
							   @"version": @1
							   };
	[feedbackBlob setObject:metadata forKey:@"Metadata"];

	NSError *e = nil;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:feedbackBlob options:0 error:&e];
	if (e != nil) {
		return;
	}

	NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

	// Extract feedback config values
	NSDictionary *feedbackConfig = [config objectForKey:@"feedbackConfig"];
	if (feedbackConfig == nil) {
		return;
	}
	NSString *pubKey = [feedbackConfig objectForKey:@"b64EncodedPublicKey"];
	NSString *uploadServer = [feedbackConfig objectForKey:@"uploadServer"];
	NSString *uploadServerHeaders = [feedbackConfig objectForKey:@"uploadServerHeaders"];

	// Upload feedback
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[[[AppDelegate sharedAppDelegate] psiphonTunnel] sendFeedback:jsonString publicKey:pubKey uploadServer:uploadServer uploadServerHeaders:uploadServerHeaders];
	});
}

// Generate random feedback ID
+ (NSString*)generateFeedbackId
{
	NSMutableString *feedbackID = NULL;
	size_t numBytes = 8;
	uint8_t *randomBytes = [FeedbackUpload generateRandomBytes:numBytes];
	if (randomBytes != NULL) {
		// Two hex characters are required to represent each byte
		feedbackID = [[NSMutableString alloc] initWithCapacity:numBytes*2];
		for(NSInteger index = 0; index < numBytes; index++)
		{
			[feedbackID appendFormat: @"%02hhX", randomBytes[index]];
		}
	}

	free(randomBytes);
	return feedbackID;
}

// Generate `count` random bytes
// Returned bytes must be freed by caller
+ (uint8_t*)generateRandomBytes:(size_t)count {
	uint8_t *randomBytes = (uint8_t *)malloc(sizeof(uint8_t) * count);
	int result = SecRandomCopyBytes(kSecRandomDefault, count, randomBytes);
	if(result != 0) {
		free(randomBytes);
		return NULL;
	}
	return randomBytes;
}

+ (NSDictionary<NSString*, NSString*>*) gatherDeviceInfo {
	UIDevice *device = [UIDevice currentDevice];

	UIUserInterfaceIdiom userInterfaceIdiom = [device userInterfaceIdiom];
	NSString *userInterfaceIdiomString = @"";

	switch (userInterfaceIdiom) {
		case UIUserInterfaceIdiomUnspecified:
			userInterfaceIdiomString = @"unspecified";
			break;
		case UIUserInterfaceIdiomPhone:
			userInterfaceIdiomString = @"phone";
			break;
		case UIUserInterfaceIdiomPad:
			userInterfaceIdiomString = @"pad";
			break;
		case UIUserInterfaceIdiomTV:
			userInterfaceIdiomString = @"tv";
			break;
		case UIUserInterfaceIdiomCarPlay:
			userInterfaceIdiomString = @"carPlay";
			break;
	}

	NSDictionary<NSString*, NSString*> *deviceInfo =
	@{
	  @"systemName":device.systemName,
	  @"systemVersion":device.systemVersion,
	  @"model":device.model,
	  @"localizedModel":device.localizedModel,
	  @"userInterfaceIdiom":userInterfaceIdiomString
	  };

	return deviceInfo;
}

// Get connection type
+ (NSString*)getConnectionType {
	Reachability *reachability = [Reachability reachabilityForInternetConnection];

	NetworkStatus status = [reachability currentReachabilityStatus];

	if(status == NotReachable)
	{
		return @"none";
	}
	else if (status == ReachableViaWiFi)
	{
		return @"WIFI";
	}
	else if (status == ReachableViaWWAN)
	{
		return @"mobile";
	}

	return @"error";
}

// Convert json string to dictionary
+ (NSDictionary*)jsonToDictionary:(NSString*)jsonString {
	NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
	NSError *e = nil;

	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&e];

	if (e) {
		return nil;
	}

	return json;
}

@end
