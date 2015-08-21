//
//  RKOAuthClient.h
//  Pods
//
//  Created by Joseph Pintozzi on 11/14/13.
//
//

#import "RKClient.h"

/**
 The different kinds of scope the OAuth client can request
 Explainations found here: http://www.reddit.com/dev/api
 */

extern NSString * const kOAuthScopeEdit;
extern NSString * const kOAuthScopeHistory;
extern NSString * const kOAuthScopeIdentity;
extern NSString * const kOAuthScopeModConfig;
extern NSString * const kOAuthScopeModFlair;
extern NSString * const kOAuthScopeModLog;
extern NSString * const kOAuthScopeModPosts;
extern NSString * const kOAuthScopeMySubreddits;
extern NSString * const kOAuthScopePrivateMessages;
extern NSString * const kOAuthScopeRead;
extern NSString * const kOAuthScopeSave;
extern NSString * const kOAuthScopeSubmit;
extern NSString * const kOAuthScopeSubscribe;
extern NSString * const kOAuthScopeVote;

@class RKOAuthCredential;

@interface RKOAuthClient : RKClient

/**
 The current clientId and clientSecret for this app.
 Only required if authenticating via OAuth
 */
@property (readonly, nonatomic, copy) NSString *clientId;
@property (readonly, nonatomic, copy) NSString *clientSecret;

/**
 Returns a RKClient ready for OAuth
 Get a client ID and secret here: https://ssl.reddit.com/prefs/apps
 */
- (id)initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret;

- (NSURL *)loginURLWithRedirectURI:(NSString *)redirectURI state:(NSString *)state scope:(NSArray*)scope compact:(BOOL)compact;
- (NSURLSessionDataTask *)authenticateUsingCode:(NSString *)code redirectURI:(NSString *)redirectURI completion:(RKObjectCompletionBlock)completion;
- (NSURLSessionDataTask *)authenticateUsingRefreshToken:(NSString *)refreshToken completion:(RKObjectCompletionBlock)completion;
- (NSURLSessionDataTask *)authenticateGuestUsingDeviceID:(NSString *)deviceID completion:(RKObjectCompletionBlock)completion;

@end

@interface RKOAuthCredential : NSObject <NSCoding>

- (instancetype)initWithToken:(NSString *)token tokenType:(NSString *)type;

@property (readonly, nonatomic, copy) NSString *accessToken;
@property (readonly, nonatomic, copy) NSString *tokenType;
@property (readwrite, nonatomic, copy) NSString *refreshToken;
@property (readwrite, nonatomic, copy) NSDate *expiration;
@property (readonly, nonatomic, assign, getter=isExpired) BOOL expired;

@end