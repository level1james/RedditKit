//
//  RKOAuthClient.m
//  Pods
//
//  Created by Joseph Pintozzi on 11/14/13.
//
//

#import "RKOAuthClient.h"
#import "RKUser.h"
#import "RKResponseSerializer.h"
#import "RKObjectBuilder.h"
#import "RKClient+Users.h"


NSString * const kOAuthScopeEdit = @"edit";
NSString * const kOAuthScopeHistory = @"history";
NSString * const kOAuthScopeIdentity = @"identity";
NSString * const kOAuthScopeModConfig = @"modconfig";
NSString * const kOAuthScopeModFlair = @"modflair";
NSString * const kOAuthScopeModLog = @"modlog";
NSString * const kOAuthScopeModPosts = @"modposts";
NSString * const kOAuthScopeMySubreddits = @"mysubreddits";
NSString * const kOAuthScopePrivateMessages = @"privatemessages";
NSString * const kOAuthScopeRead = @"read";
NSString * const kOAuthScopeSave = @"save";
NSString * const kOAuthScopeSubmit = @"submit";
NSString * const kOAuthScopeSubscribe = @"subscribe";
NSString * const kOAuthScopeVote = @"vote";


@interface RKOAuthClient ()

@property (readwrite, nonatomic, copy) NSString *clientId;
@property (readwrite, nonatomic, copy) NSString *clientSecret;
@property (readwrite, nonatomic, strong) RKOAuthCredential *credentials;

@property (readwrite, nonatomic, strong) RKUser *currentUser;
@property (nonatomic, strong) NSTimer *tokenRefreshTimer;

@end
@implementation RKOAuthClient
@dynamic currentUser;

- (id)initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret
{
    return [self initWithClientId:clientId clientSecret:clientSecret sessionConfiguration:nil];
}

- (id)initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret sessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration
{
    if (self = [super initWithBaseURL:[self.class APIBaseURL] sessionConfiguration:nil]) {
        
        NSParameterAssert(clientId);
        self.requestSerializer = [AFHTTPRequestSerializer serializer];
        self.responseSerializer = [RKResponseSerializer serializer];
        self.clientId = clientId;
        self.clientSecret = clientSecret;
        
        [self.requestSerializer setAuthorizationHeaderFieldWithUsername:self.clientId password:self.clientSecret ? self.clientSecret : @""];
    }
    return self;
}

// Overriding API urls

+ (NSURL *)APIBaseURL
{
    //OAuth requires HTTPS
    return [[self class] APIBaseHTTPSURL];
}

+ (NSURL *)APIBaseHTTPSURL
{
    return [NSURL URLWithString:@"https://oauth.reddit.com/"];
}

+ (NSURL *)APIBaseLoginURL
{
    return [NSURL URLWithString:@"https://ssl.reddit.com/"];
}

+ (NSString *)meURLPath
{
    return @"api/v1/me";
}

- (NSURL *)loginURLWithRedirectURI:(NSString *)redirectURI state:(NSString *)state scope:(NSArray*)scope compact:(BOOL)compact {
    
    NSParameterAssert(redirectURI);
    NSParameterAssert(state);
    NSParameterAssert(scope);
    
    NSString *urlString = [NSString stringWithFormat:@"%@api/v1/authorize%@?response_type=code&redirect_uri=%@&client_id=%@&duration=permanent&scope=%@&state=%@",
                           [[self class] APIBaseLoginURL],
                           compact ? @".compact" : @"",
                           [redirectURI stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                           self.clientId,
                           [scope componentsJoinedByString:@","],
                           state];
    
    return [NSURL URLWithString: urlString];
}


#pragma mark Authentication

- (NSURLSessionDataTask *)authenticateUsingCode:(NSString *)code redirectURI:(NSString *)redirectURI completion:(RKObjectCompletionBlock)completion {
    NSParameterAssert(code);
    NSParameterAssert(redirectURI);
    NSDictionary *parameters = @{@"code": code,
                                 @"redirect_uri": redirectURI,
                                 @"grant_type": @"authorization_code"};
    
    return [self authenticateUsingParameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)authenticateUsingRefreshToken:(NSString *)refreshToken completion:(RKObjectCompletionBlock)completion {
    NSParameterAssert(refreshToken);
    
    NSDictionary *parameters = @{@"refresh_token": refreshToken,
                                 @"grant_type": @"refresh_token"};

    return [self authenticateUsingParameters:parameters completion:completion];
}


- (NSURLSessionDataTask *)authenticateGuestUsingDeviceID:(NSString *)deviceID completion:(RKObjectCompletionBlock)completion {

    NSString *grantType = @"https://oauth.reddit.com/grants/installed_client";
    
    NSDictionary *parameters = @{@"device_id": deviceID,
                                 @"grant_type": grantType};
    
    return [self authenticateUsingParameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)authenticateUsingParameters:(NSDictionary *)parameters completion:(RKObjectCompletionBlock)completion {
    
    [self setBasicAuthorizationHeader];
    NSURL *baseURL = [self.class APIBaseLoginURL];
    NSString *URLString = [[NSURL URLWithString:@"api/v1/access_token" relativeToURL:baseURL] absoluteString];
    
    
    __weak __typeof(self)weakSelf = self;
    
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
    NSURLSessionDataTask *authenticationTask = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        if ([(NSHTTPURLResponse *)response statusCode] == 200) {
            [weakSelf handleOAuthResponse:responseObject parameters:parameters error:error completion:completion];
        } else {
            
        }
    }];
    
    [authenticationTask resume];
    return authenticationTask;
}

- (void)handleOAuthResponse:(id)responseObject parameters:(NSDictionary *)parameters error:(NSError *)error completion:(RKObjectCompletionBlock)completionBlock {

    NSLog(@"%@", responseObject);
    if (!error) {
        
        id refreshToken = responseObject[@"refresh_token"];
        if (!refreshToken || [refreshToken isEqual:[NSNull null]]) {
            refreshToken = parameters[@"refresh_token"];
        }
        
        NSDate *expiration = [NSDate distantFuture];
        id expiresIn = responseObject[@"expires_in"];
        if (expiresIn && ![expiresIn isEqual:[NSNull null]]) {
            expiration = [NSDate dateWithTimeIntervalSinceNow:[expiresIn doubleValue]];
        }

        NSString *accessToken = responseObject[@"access_token"];
        NSString *tokenType = responseObject[@"token_type"];
        
        RKOAuthCredential *credentials = [[RKOAuthCredential alloc] initWithToken:accessToken tokenType:tokenType];
        credentials.refreshToken = refreshToken;
        credentials.expiration = expiration;
        
        [self setBearerAccessToken:accessToken];
        
        if (!self.currentUser && [parameters[@"grant_type"] isEqualToString:@"authorization_code"]) {
            [self currentUserWithCompletion:^(id object, NSError *error) {
                completionBlock ? completionBlock(credentials, error) : nil;
            }];
        } else if (completionBlock) {
            completionBlock(credentials, error);
        }
    } else if (completionBlock) {
        completionBlock(nil, error);
    }
}

- (void)signOut
{
    [super signOut];
    
    [self.requestSerializer setValue:nil forHTTPHeaderField:@"Authorization"];
    self.credentials = nil;
}

- (BOOL)isSignedIn
{
    return self.modhash != nil || !self.credentials.isExpired;
}

- (void)setBasicAuthorizationHeader {
    [self.requestSerializer setAuthorizationHeaderFieldWithUsername:self.clientId password:self.clientSecret ? self.clientSecret : @""];
}

- (void)setBearerAccessToken:(NSString*)accessToken {
    [self.requestSerializer setValue:[@"bearer " stringByAppendingString: accessToken] forHTTPHeaderField:@"Authorization"];
}

@end

@interface RKOAuthCredential ()
@property (readwrite, nonatomic, copy) NSString *accessToken;
@property (readwrite, nonatomic, copy) NSString *tokenType;
@end

@implementation RKOAuthCredential

- (instancetype)initWithToken:(NSString *)token tokenType:(NSString *)type {
    self = [super init];
    if (self) {
        NSParameterAssert(token);
        NSParameterAssert(type);
        
        self.accessToken = token;
        self.tokenType = type;
    }
    return self;
}

- (BOOL)isExpired {
    return [self.expiration compare:[NSDate date]] == NSOrderedAscending;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    self.accessToken = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(accessToken))];
    self.tokenType = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(tokenType))];
    self.refreshToken = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(refreshToken))];
    self.expiration = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(expiration))];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.accessToken forKey:NSStringFromSelector(@selector(accessToken))];
    [aCoder encodeObject:self.tokenType forKey:NSStringFromSelector(@selector(tokenType))];
    [aCoder encodeObject:self.refreshToken forKey:NSStringFromSelector(@selector(refreshToken))];
    [aCoder encodeObject:self.expiration forKey:NSStringFromSelector(@selector(expiration))];
}



@end
