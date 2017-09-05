//
//  AppDelegate+FCMPlugin.m
//  TestApp
//
//  Created by felipe on 12/06/16.
//
//
#import "AppDelegate+FCMPlugin.h"
#import "FCMPlugin.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#import "Firebase.h"

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif

// Implement UNUserNotificationCenterDelegate to receive display notification via APNS for devices
// running iOS 10 and above. Implement FIRMessagingDelegate to receive data message via FCM for
// devices running iOS 10 and above.
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
@end
#endif

// Copied from Apple's header in case it is missing in some cases (e.g. pre-Xcode 8 builds).
#ifndef NSFoundationVersionNumber_iOS_9_x_Max
#define NSFoundationVersionNumber_iOS_9_x_Max 1299
#endif

@implementation AppDelegate (FCMPlugin)

static NSData *lastPush;
NSString *const kGCMMessageIDKey = @"gcm.message_id";

//////////////////////////////////////////////////////
///////////////////INITIALIZATION/////////////////////
//////////////////////////////////////////////////////

//Method swizzling
+ (void)load
{
    Method original =  class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:));
    Method custom =    class_getInstanceMethod(self, @selector(application:customDidFinishLaunchingWithOptions:));
    method_exchangeImplementations(original, custom);
}

- (BOOL)application:(UIApplication *)application customDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self application:application customDidFinishLaunchingWithOptions:launchOptions];
    
    NSLog(@"DidFinishLaunchingWithOptions");
    
    [FIRApp configure];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        UIUserNotificationType allNotificationTypes =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    } else {
        // iOS 10 or later
        #if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                UNAuthorizationOptions authOptions =
                UNAuthorizationOptionAlert
                | UNAuthorizationOptionSound
                | UNAuthorizationOptionBadge;
                [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
                }];

                // For iOS 10 display notification (sent via APNS)
                [UNUserNotificationCenter currentNotificationCenter].delegate = self;
                //For iOS 10 data message (sent direct from FCM)
                [FIRMessaging messaging].delegate = self;
        #endif
    }
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    [FIRMessaging messaging].shouldEstablishDirectChannel = YES;
    
    return YES;
}

//////////////////////////////////////////////////////
////////////////////////ALL IOS///////////////////////
//////////////////////////////////////////////////////

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    //FORGROUND => NOTIF + DATA                         [ios 10 && ios 9]
    //BACKGROUND.content_available=1 => NOTIF + DATA    [ios 10 && ios 9]
    //BACKGROUND.TAPPED => NOTIF + DATA                 [ios 9]
    //FOREGROUND => DATA                                [ios 9]
    
    [self notifyOfMessage:userInfo];
    completionHandler(UIBackgroundFetchResultNewData);
}



//////////////////////////////////////////////////////
/////////////////////////IOS 10///////////////////////
//////////////////////////////////////////////////////

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
    //BACKGROUND.TAPPED => NOTIF + DATA         [ios 10]
    [self notifyOfMessage:response.notification.request.content.userInfo];
}

- (void)messaging:(nonnull FIRMessaging *)messaging didReceiveMessage:(nonnull FIRMessagingRemoteMessage *)remoteMessage {
    //FOREGROUND => DATA                        [ios 10]
    [self notifyOfMessage:remoteMessage.appData];
}

//////////////////////////////////////////////////////
////////////////////REFRESH TOKENS////////////////////
//////////////////////////////////////////////////////
- (void)messaging:(nonnull FIRMessaging *)messaging didRefreshRegistrationToken:(nonnull NSString *)fcmToken
{
    [FCMPlugin.fcmPlugin notifyOfTokenRefresh:fcmToken];
}


//////////////////////////////////////////////////////
////////////////FOREGROUND/BACKGROUND/////////////////
//////////////////////////////////////////////////////

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"app become active");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"app entered background");
}

//////////////////////////////////////////////////////
///////////////////MESSAGE HANDLING///////////////////
//////////////////////////////////////////////////////

-(void) notifyOfMessage: (NSDictionary*) notification {
    NSData *jsonData = [self packageMessage:notification];
    [self logMessage:jsonData];
    
    [FCMPlugin.fcmPlugin notifyOfMessage:jsonData];
}

-(void) logMessage: (NSData*) messageData {
    NSLog(@"FCMPlugin: %@", messageData);
}

-(NSData*) packageMessage: (NSDictionary*) notification {
    NSError *error;
    NSDictionary *notificationMut = [notification mutableCopy];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:notificationMut
                                                       options:0
                                                         error:&error];
    return jsonData;
}


@end
