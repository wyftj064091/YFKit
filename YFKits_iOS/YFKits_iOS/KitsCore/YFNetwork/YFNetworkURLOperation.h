//
//  YFNetworkURLOperation.h
//  YFKits_iOS
//
//  Created by Yifeng Wu on 13-8-13.
//  Copyright (c) 2013年 YifengWu. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    YFSSLPinningModeNone,
    YFSSLPinningModePublicKey,
    YFSSLPinningModeCertificate,
} YFURLConnectionOperationSSLPinningMode;


@interface YFNetworkURLOperation : NSOperation <NSURLConnectionDelegate
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 50000) || \
(defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1080)
,NSURLConnectionDataDelegate
#endif
>

/**
 The run loop modes in which the operation will run on the network thread. By default, this is a single-member set containing `NSRunLoopCommonModes`.
 */
@property (nonatomic, strong) NSSet * runloopModes;

/**
 The request used for url connection.
  */
@property (readonly, nonatomic, strong) NSURLRequest * request;

 /**
 The response used for url connection.
  */
@property (readonly, nonatomic, strong) NSURLResponse * response;

 /**
  Error occured during the url connection.
  */
@property (readonly, nonatomic, strong) NSError * erorr;

/**
 Whether the connection should accept an invalid SSL certificate.
 
 If `_AFNETWORKING_ALLOW_INVALID_SSL_CERTIFICATES_` is set, this property defaults to `YES` for backwards compatibility. Otherwise, this property defaults to `NO`.
 */
@property (nonatomic, assign) BOOL allowsInvalidSSLCertificate;

///----------------------------
/// @name Getting Response Data
///----------------------------

/**
 The data received during the request.
 */
@property (readonly, nonatomic, strong) NSData *responseData;

/**
 The string representation of the response data.
 */
@property (readonly, nonatomic, copy) NSString *responseString;

/**
 The string encoding of the response.
 
 If the response does not specify a valid string encoding, `responseStringEncoding` will return `NSUTF8StringEncoding`.
 */
@property (readonly, nonatomic, assign) NSStringEncoding responseStringEncoding;

///-------------------------------
/// @name Managing URL Credentials
///-------------------------------

/**
 Whether the URL connection should consult the credential storage for authenticating the connection. `YES` by default.
 
 This is the value that is returned in the `NSURLConnectionDelegate` method `-connectionShouldUseCredentialStorage:`.
 */
@property (nonatomic, assign) BOOL shouldUseCredentialStorage;

/**
 The credential used for authentication challenges in `-connection:didReceiveAuthenticationChallenge:`.
 
 This will be overridden by any shared credentials that exist for the username or password of the request URL, if present.
 */
@property (nonatomic, strong) NSURLCredential *credential;

/**
 The pinning mode which will be used for SSL connections. `AFSSLPinningModePublicKey` by default.
 
 SSL Pinning requires that the Security framework is linked with the binary. See the "SSL Pinning" section in the `AFURLConnectionOperation`" header for more information.
 */
@property (nonatomic, assign) YFURLConnectionOperationSSLPinningMode SSLPinningMode;

///------------------------
/// @name Accessing Streams
///------------------------

/**
 The input stream used to read data to be sent during the request.
 
 This property acts as a proxy to the `HTTPBodyStream` property of `request`.
 */
@property (nonatomic, strong) NSInputStream *inputStream;

/**
 The output stream that is used to write data received until the request is finished.
 
 By default, data is accumulated into a buffer that is stored into `responseData` upon completion of the request. When `outputStream` is set, the data will not be accumulated into an internal buffer, and as a result, the `responseData` property of the completed request will be `nil`. The output stream will be scheduled in the network thread runloop upon being set.
 */
@property (nonatomic, strong) NSOutputStream *outputStream;

///---------------------------------------------
/// @name Managing Request Operation Information
///---------------------------------------------

/**
 The user info dictionary for the receiver.
 */
@property (nonatomic, strong) NSDictionary *userInfo;

///------------------------------------------------------
/// @name Initializing an AFURLConnectionOperation Object
///------------------------------------------------------

/**
 Initializes and returns a newly allocated operation object with a url connection configured with the specified url request.
 
 This is the designated initializer.
 
 @param urlRequest The request object to be used by the operation connection.
 */
- (id)initWithRequest:(NSURLRequest *)urlRequest;

///----------------------------------
/// @name Pausing / Resuming Requests
///----------------------------------

/**
 Pauses the execution of the request operation.
 
 A paused operation returns `NO` for `-isReady`, `-isExecuting`, and `-isFinished`. As such, it will remain in an `NSOperationQueue` until it is either cancelled or resumed. Pausing a finished, cancelled, or paused operation has no effect.
 */
- (void)pause;

/**
 Whether the request operation is currently paused.
 
 @return `YES` if the operation is currently paused, otherwise `NO`.
 */
- (BOOL)isPaused;

/**
 Resumes the execution of the paused request operation.
 
 Pause/Resume behavior varies depending on the underlying implementation for the operation class. In its base implementation, resuming a paused requests restarts the original request. However, since HTTP defines a specification for how to request a specific content range, `AFHTTPRequestOperation` will resume downloading the request from where it left off, instead of restarting the original request.
 */
- (void)resume;

///----------------------------------------------
/// @name Configuring Backgrounding Task Behavior
///----------------------------------------------

/**
 Specifies that the operation should continue execution after the app has entered the background, and the expiration handler for that background task.
 
 @param handler A handler to be called shortly before the application’s remaining background time reaches 0. The handler is wrapped in a block that cancels the operation, and cleans up and marks the end of execution, unlike the `handler` parameter in `UIApplication -beginBackgroundTaskWithExpirationHandler:`, which expects this to be done in the handler itself. The handler is called synchronously on the main thread, thus blocking the application’s suspension momentarily while the application is notified.
 */
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
- (void)setShouldExecuteAsBackgroundTaskWithExpirationHandler:(void (^)(void))handler;
#endif

///---------------------------------
/// @name Setting Progress Callbacks
///---------------------------------

/**
 Sets a callback to be called when an undetermined number of bytes have been uploaded to the server.
 
 @param block A block object to be called when an undetermined number of bytes have been uploaded to the server. This block has no return value and takes three arguments: the number of bytes written since the last time the upload progress block was called, the total bytes written, and the total bytes expected to be written during the request, as initially determined by the length of the HTTP body. This block may be called multiple times, and will execute on the main thread.
 */
- (void)setUploadProgressBlock:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))block;

/**
 Sets a callback to be called when an undetermined number of bytes have been downloaded from the server.
 
 @param block A block object to be called when an undetermined number of bytes have been downloaded from the server. This block has no return value and takes three arguments: the number of bytes read since the last time the download progress block was called, the total bytes read, and the total bytes expected to be read during the request, as initially determined by the expected content size of the `NSHTTPURLResponse` object. This block may be called multiple times, and will execute on the main thread.
 */
- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))block;

///-------------------------------------------------
/// @name Setting NSURLConnection Delegate Callbacks
///-------------------------------------------------

/**
 Sets a block to be executed when the connection will authenticate a challenge in order to download its request, as handled by the `NSURLConnectionDelegate` method `connection:willSendRequestForAuthenticationChallenge:`.
 
 @param block A block object to be executed when the connection will authenticate a challenge in order to download its request. The block has no return type and takes two arguments: the URL connection object, and the challenge that must be authenticated. This block must invoke one of the challenge-responder methods (NSURLAuthenticationChallengeSender protocol).
 
 If `allowsInvalidSSLCertificate` is set to YES, `connection:willSendRequestForAuthenticationChallenge:` will attempt to have the challenge sender use credentials with invalid SSL certificates.
 */
- (void)setWillSendRequestForAuthenticationChallengeBlock:(void (^)(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge))block;

/**
 Sets a block to be executed when the server redirects the request from one URL to another URL, or when the request URL changed by the `NSURLProtocol` subclass handling the request in order to standardize its format, as handled by the `NSURLConnectionDelegate` method `connection:willSendRequest:redirectResponse:`.
 
 @param block A block object to be executed when the request URL was changed. The block returns an `NSURLRequest` object, the URL request to redirect, and takes three arguments: the URL connection object, the the proposed redirected request, and the URL response that caused the redirect.
 */
- (void)setRedirectResponseBlock:(NSURLRequest * (^)(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse))block;


/**
 Sets a block to be executed to modify the response a connection will cache, if any, as handled by the `NSURLConnectionDelegate` method `connection:willCacheResponse:`.
 
 @param block A block object to be executed to determine what response a connection will cache, if any. The block returns an `NSCachedURLResponse` object, the cached response to store in memory or `nil` to prevent the response from being cached, and takes two arguments: the URL connection object, and the cached response provided for the request.
 */
- (void)setCacheResponseBlock:(NSCachedURLResponse * (^)(NSURLConnection *connection, NSCachedURLResponse *cachedResponse))block;


@end
