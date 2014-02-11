//
//  YFNetworkURLOperation.m
//  YFKits_iOS
//
//  Created by Yifeng Wu on 13-8-13.
//  Copyright (c) 2013年 YifengWu. All rights reserved.
//

#import "YFNetworkURLOperation.h"

NSString * const YFNetworkRecursiveLock = @"YFNetworkRecursiveLock";

typedef enum {
    YFOperationPausedState      = -1,
    YFOperationReadyState       = 1,
    YFOperationExecutingState   = 2,
    YFOperationFinishedState    = 3,
} YFOperationState;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
typedef UIBackgroundTaskIdentifier YFBackgroundTaskIdentifier;
#else
typedef id YFBackgroundTaskIdentifier;
#endif

typedef void (^YFURLConnectionOperationProgressBlock)(NSUInteger bytes, long long totalBytes, long long totalBytesExpected);
typedef void (^YFURLConnectionOperationAuthenticationChallengeBlock)(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge);
typedef NSCachedURLResponse * (^YFURLConnectionOperationCacheResponseBlock)(NSURLConnection *connection, NSCachedURLResponse *cachedResponse);
typedef NSURLRequest * (^YFURLConnectionOperationRedirectResponseBlock)(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse);


@interface YFNetworkURLOperation ()

@property (nonatomic, strong) NSRecursiveLock * lock;
@property (nonatomic, assign) YFOperationState state;
@property (readwrite, nonatomic, strong) NSURLConnection *connection;
@property (readwrite, nonatomic, strong) NSURLRequest *request;
@property (readwrite, nonatomic, strong) NSURLResponse *response;
@property (readwrite, nonatomic, strong) NSError *error;
@property (readwrite, nonatomic, strong) NSData *responseData;
@property (readwrite, nonatomic, copy) NSString *responseString;
@property (readwrite, nonatomic, assign) NSStringEncoding responseStringEncoding;
@property (readwrite, nonatomic, assign) long long totalBytesRead;
@property (readwrite, nonatomic, assign) YFBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (readwrite, nonatomic, copy) YFURLConnectionOperationProgressBlock uploadProgress;
@property (readwrite, nonatomic, copy) YFURLConnectionOperationProgressBlock downloadProgress;
@property (readwrite, nonatomic, copy) YFURLConnectionOperationAuthenticationChallengeBlock authenticationChallenge;
@property (readwrite, nonatomic, copy) YFURLConnectionOperationCacheResponseBlock cacheResponse;
@property (readwrite, nonatomic, copy) YFURLConnectionOperationRedirectResponseBlock redirectResponse;

@end

@implementation YFNetworkURLOperation

#pragma mark Instance methods
- (id)initWithRequest:(NSURLRequest *)urlRequest
{
    NSParameterAssert(urlRequest);
    self = [super init];
    if (self) {
        self.lock = [[NSRecursiveLock alloc] init];
        self.lock.name = YFNetworkRecursiveLock;
        
        self.request = urlRequest;
        
        self.runloopModes = [NSSet setWithObject:NSRunLoopCommonModes];
        
        self.state = YFOperationReadyState;
        
    }
    
    return self;
}

#pragma mark -
#pragma mark NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (self.authenticationChallenge) {
        self.authenticationChallenge(connection, challenge);
        return;
    }
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
        
        SecPolicyRef policy = SecPolicyCreateBasicX509();
        CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
        NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:certificateCount];
        
        for (CFIndex i = 0; i < certificateCount; i++) {
            SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
            
            if (self.SSLPinningMode == YFSSLPinningModeCertificate) {
                [trustChain addObject:(__bridge_transfer NSData *)SecCertificateCopyData(certificate)];
            } else if (self.SSLPinningMode == YFSSLPinningModePublicKey) {
                SecCertificateRef someCertificates[] = {certificate};
                CFArrayRef certificates = CFArrayCreate(NULL, (const void **)someCertificates, 1, NULL);
                
                SecTrustRef trust = NULL;
                
                OSStatus status = SecTrustCreateWithCertificates(certificates, policy, &trust);
                NSAssert(status == errSecSuccess, @"SecTrustCreateWithCertificates error: %ld", (long int)status);
                if (status == errSecSuccess && trust) {
                    SecTrustResultType result;
                    status = SecTrustEvaluate(trust, &result);
                    NSAssert(status == errSecSuccess, @"SecTrustEvaluate error: %ld", (long int)status);
                    if (status == errSecSuccess) {
                        [trustChain addObject:(__bridge_transfer id)SecTrustCopyPublicKey(trust)];
                    }
                    
                    CFRelease(trust);
                }
                
                CFRelease(certificates);
            }
        }
        
        CFRelease(policy);
        
        switch (self.SSLPinningMode) {
            case YFSSLPinningModePublicKey: {
                NSArray *pinnedPublicKeys = [self.class pinnedPublicKeys];
                
                for (id publicKey in trustChain) {
                    for (id pinnedPublicKey in pinnedPublicKeys) {
                        if (AFSecKeyIsEqualToKey((__bridge SecKeyRef)publicKey, (__bridge SecKeyRef)pinnedPublicKey)) {
                            NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
                            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
                            return;
                        }
                    }
                }
                
                [[challenge sender] cancelAuthenticationChallenge:challenge];
                break;
            }
            case YFSSLPinningModeCertificate: {
                for (id serverCertificateData in trustChain) {
                    if ([[self.class pinnedCertificates] containsObject:serverCertificateData]) {
                        NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
                        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
                        return;
                    }
                }
                
                [[challenge sender] cancelAuthenticationChallenge:challenge];
                break;
            }
            case YFSSLPinningModeNone: {
                if (self.allowsInvalidSSLCertificate){
                    NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
                    [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
                } else {
                    SecTrustResultType result = 0;
                    OSStatus status = SecTrustEvaluate(serverTrust, &result);
                    NSAssert(status == errSecSuccess, @"SecTrustEvaluate error: %ld", (long int)status);
                    
                    if (status == errSecSuccess && (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed)) {
                        NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
                        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
                    } else {
                        [[challenge sender] cancelAuthenticationChallenge:challenge];
                    }
                }
                break;
            }
        }
    } else {
        if ([challenge previousFailureCount] == 0) {
            if (self.credential) {
                [[challenge sender] useCredential:self.credential forAuthenticationChallenge:challenge];
            } else {
                [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
            }
        } else {
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    }
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection __unused *)connection {
    return self.shouldUseCredentialStorage;
}

#pragma mark Connection data

- (NSInputStream *)connection:(NSURLConnection __unused *)connection
            needNewBodyStream:(NSURLRequest *)request
{
    if ([request.HTTPBodyStream conformsToProtocol:@protocol(NSCopying)]) {
        return [request.HTTPBodyStream copy];
    } else {
        [self cancelConnection];
        
        return nil;
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse
{
    if (self.redirectResponse) {
        return self.redirectResponse(connection, request, redirectResponse);
    } else {
        return request;
    }
}

- (void)connection:(NSURLConnection __unused *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (self.uploadProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.uploadProgress((NSUInteger)bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        });
    }
}

- (void)connection:(NSURLConnection __unused *)connection
didReceiveResponse:(NSURLResponse *)response
{
    self.response = response;
    
    [self.outputStream open];
}

- (void)connection:(NSURLConnection __unused *)connection
    didReceiveData:(NSData *)data
{
    NSUInteger length = [data length];
    if ([self.outputStream hasSpaceAvailable]) {
        const uint8_t *dataBuffer = (uint8_t *) [data bytes];
        [self.outputStream write:&dataBuffer[0] maxLength:length];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.totalBytesRead += length;
        
        if (self.downloadProgress) {
            self.downloadProgress(length, self.totalBytesRead, self.response.expectedContentLength);
        }
    });
}

- (void)connectionDidFinishLoading:(NSURLConnection __unused *)connection {
    self.responseData = [self.outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    
    [self.outputStream close];
    
    [self finish];
    
    self.connection = nil;
}

- (void)connection:(NSURLConnection __unused *)connection
  didFailWithError:(NSError *)error
{
    self.error = error;
    
    [self.outputStream close];
    
    [self finish];
    
    self.connection = nil;
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    if (self.cacheResponse) {
        return self.cacheResponse(connection, cachedResponse);
    } else {
        if ([self isCancelled]) {
            return nil;
        }
        
        return cachedResponse;
    }
}
@end
