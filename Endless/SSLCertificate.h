/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface SSLCertificate : NSObject

/* Relative Distinguished Name (RDN) table */
#define X509_KEY_CN	@"Common Name (CN)"
#define X509_KEY_O	@"Organization (O)"
#define X509_KEY_OU	@"Organizational Unit Number (OU)"
#define X509_KEY_L	@"Locality (L)"
#define X509_KEY_ST	@"State/Province (ST)"
#define X509_KEY_C	@"Country (C)"
#define X509_KEY_SN	@"Serial Number (SN)"

#define X509_KEY_STREET	@"Street Address"
#define X509_KEY_ZIP	@"Postal Code"
#define X509_KEY_SERIAL	@"Serial Number"
#define X509_KEY_BUSCAT	@"Business Category"

/* For l10n, keys must match the above */
#define X509_KEY_CN_l10n	NSLocalizedString(@"Common Name (CN)", @"Field name for display in list")
#define X509_KEY_O_l10n		NSLocalizedString(@"Organization (O)", @"Field name for display in list")
#define X509_KEY_OU_l10n	NSLocalizedString(@"Organizational Unit Number (OU)", @"Field name for display in list")
#define X509_KEY_L_l10n		NSLocalizedString(@"Locality (L)", @"Field name for display in list")
#define X509_KEY_ST_l10n	NSLocalizedString(@"State/Province (ST)", @"Field name for display in list")
#define X509_KEY_C_l10n		NSLocalizedString(@"Country (C)", @"Field name for display in list")
#define X509_KEY_SN_l10n	NSLocalizedString(@"Serial Number (SN)", @"Field name for display in list")

#define X509_KEY_STREET_l10n	NSLocalizedString(@"Street Address", @"Field name for display in list")
#define X509_KEY_ZIP_l10n		NSLocalizedString(@"Postal Code", @"Field name for display in list")
#define X509_KEY_SERIAL_l10n	NSLocalizedString(@"Serial Number", @"Field name for display in list")
#define X509_KEY_BUSCAT_l10n	NSLocalizedString(@"Business Category", @"Field name for display in list")

@property (strong, readonly) NSDictionary *oids;

@property (strong, readonly) NSNumber *version;
@property (strong, readonly) NSString *serialNumber;
@property (strong, readonly) NSString *signatureAlgorithm;
@property (strong, readonly) NSDictionary *issuer;
@property (strong, readonly) NSDate *validityNotBefore;
@property (strong, readonly) NSDate *validityNotAfter;
@property (strong, readonly) NSDictionary *subject;

@property SSLProtocol negotiatedProtocol;
@property SSLCipherSuite negotiatedCipher;

@property (readonly) BOOL isEV;
@property (strong, readonly) NSString *evOrgName;

- (id)initWithSecTrustRef:(SecTrustRef)secTrustRef;
- (id)initWithData:(NSData *)data;
- (BOOL)isExpired;
- (BOOL)hasWeakSignatureAlgorithm;
- (NSString *)negotiatedProtocolString;
- (NSString *)negotiatedCipherString;

@end
