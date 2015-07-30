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

@property (nonatomic, strong) RKUser *currentUser;
@property (nonatomic, strong) NSTimer *tokenRefreshTimer;

@end
@implementation RKOAuthClient

- (id)initWithClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret
{
    if (self = [super initWithBaseURL:[[self class] APIBaseURL]]) {
        self.requestSerializer = [AFHTTPRequestSerializer serializer];
        self.responseSerializer = [RKResponseSerializer serializer];
        _clientId = clientId;
        _clientSecret = clientSecret;
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

- (void)setClientId:(NSString *)clientId clientSecret:(NSString*)clientSecret {
    _clientId = [clientId copy];
    _clientSecret = [clientSecret copy];
}

- (void)setOAuthorizationHeader {
    
    NSAssert(_clientId != nil, @"You must first set a clientId");
    NSAssert(_clientSecret != nil, @"You must first set a clientSecret");
    [[self requestSerializer] setAuthorizationHeaderFieldWithUsername:_clientId password:_clientSecret];
}

- (NSURL *)oauthURLWithRedirectURI:(NSString *)redirectURI state:(NSString *)state scope:(NSArray*)scope compact:(BOOL)compact {
    
    NSParameterAssert(redirectURI);
    NSParameterAssert(state);
    NSParameterAssert(scope);
    NSAssert(_clientId != nil, @"You must first set a clientId");
    
    NSString *urlString = [NSString stringWithFormat:@"%@api/v1/authorize%@?response_type=code&redirect_uri=%@&client_id=%@&duration=permanent&scope=%@&state=%@",
                           [[self class] APIBaseLoginURL],
                           compact ? @".compact" : @"",
                           [redirectURI stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                           _clientId,
                           [scope componentsJoinedByString:@","],
                           state];
    
    return [NSURL URLWithString: urlString];
}

- (NSURLSessionDataTask *)signInWithAccessCode:(NSString *)accessCode redirectURI:(NSString *)redirectURI state:(NSString *)state completion:(RKCompletionBlock)completion
{
    NSParameterAssert(accessCode);
    NSParameterAssert(redirectURI);
    NSParameterAssert(state);
    
    NSDictionary *parameters = @{@"code": accessCode, @"state": state, @"redirect_uri": redirectURI, @"grant_type": @"authorization_code"};
    return [self accessTokenWithParameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)refreshGuestTokenWithTimer:(NSTimer *)timer {
    return [self guestTokenWithCompletion:nil];
}

- (NSURLSessionDataTask *)refreshAccessTokenWithTimer:(NSTimer *)timer
{
    NSDictionary *parameters = timer.userInfo;
    return [self refreshAccessToken:_refreshToken redirectURI:parameters[@"redirect_uri"] state:parameters[@"state"] completion:nil];
}

- (NSURLSessionDataTask *)refreshAccessToken:(NSString *)refreshToken redirectURI:(NSString *)redirectURI state:(NSString *)state completion:(RKCompletionBlock)completion
{
    NSParameterAssert(refreshToken);
    NSParameterAssert(redirectURI);
    NSParameterAssert(state);
    
    NSDictionary *parameters = @{@"refresh_token": refreshToken, @"state": state, @"redirect_uri": redirectURI, @"grant_type": @"refresh_token"};
    return [self accessTokenWithParameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)userInfoWithCompletion:(RKObjectCompletionBlock)completion
{
    
    NSURL *baseURL = [[self class] APIBaseHTTPSURL];
    NSString *URLString = [[NSURL URLWithString:[[self class] meURLPath] relativeToURL:baseURL] absoluteString];
    
    NSMutableURLRequest *request = [[self requestSerializer] requestWithMethod:@"GET" URLString:URLString parameters:@{} error:nil];
    
    NSURLSessionDataTask *authenticationTask = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        if (completion) {
            completion(responseObject, error);
        }
    }];
    
    [authenticationTask resume];
    
    return authenticationTask;
}

- (void)revokeDeviceID {
    
}

- (NSURLSessionDataTask *)guestTokenWithCompletion:(RKCompletionBlock)completion {
    
    NSString *deviceID = [[NSUUID alloc] init].UUIDString;

    NSString *grantType = @"https://oauth.reddit.com/grants/installed_client";
    
    NSDictionary *parameters = @{@"grant_type": grantType,
                                 @"device_id": deviceID};
    
    return [self accessTokenWithParameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)accessTokenWithParameters:(NSDictionary *)parameters completion:(RKCompletionBlock)completion {
    
    [self setOAuthorizationHeader];
    NSURL *baseURL = [[self class] APIBaseLoginURL];
    NSString *URLString = [[NSURL URLWithString:@"api/v1/access_token" relativeToURL:baseURL] absoluteString];
    
    
    NSMutableURLRequest *request = [[self requestSerializer] requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
    
    __weak __typeof(self)weakSelf = self;
    NSURLSessionDataTask *authenticationTask = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        
        [weakSelf handleOAuthResponse:responseObject parameters:parameters error:error completion:completion];
        
    }];
    
    [authenticationTask resume];
    return authenticationTask;
}

- (void)handleOAuthResponse:(id)responseObject parameters:(NSDictionary *)parameters error:(NSError *)error completion:(RKCompletionBlock)completionBlock {
    
    if (!error) {
        
        NSLog(@"%@", responseObject);
        NSString *accessToken = responseObject[@"access_token"];
        NSString *refreshToken = responseObject[@"refresh_token"] != [NSNull null] ? responseObject[@"refresh_token"] : nil;
        NSTimeInterval expiration = [responseObject[@"expires_in"] doubleValue];
        
        if (!accessToken) {
            accessToken = parameters[@"code"];
        }
        _accessToken = accessToken;
        
        
        [self setBearerAccessToken:accessToken];
        [self updateTimerWithRefreshToken:refreshToken expiration:expiration parameters:parameters];
        
        if (!self.currentUser) {
            [self loadUserAccountWithCallback:^(NSError *error) {
                completionBlock ? completionBlock(error) : nil;
            }];
        } else if (completionBlock) {
            completionBlock(nil);
        }
    } else if (completionBlock) {
        completionBlock(error);
    }
}

- (void)updateTimerWithRefreshToken:(NSString *)refreshToken expiration:(NSTimeInterval)expiration parameters:(NSDictionary *)parameters {
    
    NSParameterAssert(expiration);
    
    // if we have an existing timer, invalidate it so it doesn't fire twice
    
    [_tokenRefreshTimer invalidate];
    NSTimeInterval seconds = expiration - 10; //be a little aggressive and refresh 10 seconds before our token expires
    self.refreshToken = refreshToken;
    
    if (refreshToken) {
        _tokenRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(refreshAccessTokenWithTimer:) userInfo:parameters repeats:NO];
    } else {
        _tokenRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(refreshGuestTokenWithTimer:) userInfo:nil repeats:NO];
    }
}


- (void)loadUserAccountWithCallback:(RKCompletionBlock)completion
{
    __weak __typeof(self)weakSelf = self;
    [self userInfoWithCompletion:^(id object, NSError *error) {
        if (error) {
            completion(error);
        } else {
            RKUser *account = [RKObjectBuilder objectFromJSON:@{@"kind": kRKObjectTypeAccount, @"data":object}];
            if (account && !error) {
                weakSelf.currentUser = account;
                if (completion)
                {
                    completion(nil);
                }
            } else if (completion) {
                completion(error);
            }
        }
    }];
}

- (BOOL)isSignedIn
{
	return self.modhash != nil || _accessToken != nil;
}


- (void)setBearerAccessToken:(NSString*)accessToken
{
    [[self requestSerializer] setValue:[@"bearer " stringByAppendingString: accessToken] forHTTPHeaderField:@"Authorization"];
}

@end
