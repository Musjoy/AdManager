//
//  AdManager.h
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "AdInfo.h"

#ifdef MODULE_UM_ANALYSE
#import HEADER_UM_ANALYSE
/// 插页广告
#ifndef stat_ShowCountInterstitialAd
#define stat_ShowCountInterstitialAd    @"ShowCountInterstitialAd"
#endif
/// 奖励视频广告
#ifndef stat_ShowCountRewardedAd
#define stat_ShowCountRewardedAd        @"ShowCountRewardedAd"
#endif
/// 评论展示和点击
#ifndef stat_Review
#define stat_Review                     @"Review"
#endif
#endif

/// Plist文件名设置
#ifndef PLIST_AD_LIST
#define PLIST_AD_LIST   @"ad_list"
#endif

/// 启动广告 key设置
#ifndef KEY_AD_INTERSTITIAL_LAUNCH
#define KEY_AD_INTERSTITIAL_LAUNCH @"KEY_AD_INTERSTITIAL_LAUNCH"
#endif

/// MoreApps key设置
#ifndef KEY_AD_MORE_APPS
#define KEY_AD_MORE_APPS @"KEY_AD_MORE_APPS"
#endif

/// 移除广告内购
#ifndef IAP_PRODUCT_REMOVE_ADS
#define IAP_PRODUCT_REMOVE_ADS  @"RemoveAds"
#endif

///======== 评论弹窗
/** 是否已点击评论弹窗 */
#define kReviewIsClick      @"ReviewIsClick"


/// 插页广告消失通知
static NSString *const kNoticAdDismiss  = @"NoticAdDismiss";

typedef void (^AdVoidBlock)(void);


@interface AdManager : NSObject<UIAlertViewDelegate, GADInterstitialDelegate>


+ (instancetype)shareInstance;


+ (BOOL)canShowAd;

/// 开始准备广告
- (void)startPrepare;

- (void)checkAllWhileAppActive;

- (BOOL)haveAnythingInShow;

- (AdInfo *)adInfoForKey:(NSString *)adKey;

#pragma mark - Banner

/// 创建banner广告
- (DFPBannerView *)createBannerAd:(NSString *)adKey withSize:(GADAdSize)aSize;
- (DFPBannerView *)createBannerAd:(NSString *)adKey
                         withSize:(GADAdSize)aSize
                     receiveBlock:(AdVoidBlock)receiveBlock
                      removeBlock:(AdVoidBlock)removeBlock;



#pragma mark - Interstitial Ad

/// 检查是否显示插页广告
- (void)checkInterstitialAd:(NSString *)adKey;
/// 是否可以显示插页广告
- (BOOL)canShowAd:(NSString *)adKey;
/// 显示插页广告
- (BOOL)showInterstitialAd:(NSString *)adKey;

#pragma mark - MoreApp

/// 是否存在可显示的moreApp
- (BOOL)hadMoreApp;
/// 点击MoreApps广告，即显示默认MoreApps
- (void)moreAppsClick;

#pragma mark - Revarded Ad

/// 添加奖励广告计数，适用于计数型的奖励广告
- (void)addRewardedAdCount:(NSString *)adKey;
/// 是否有对应奖励广告
- (BOOL)haveRewardedAd:(NSString *)adKey;
/// 显示Rewarded广告，返回NO则广告未显示，completion不会被调用
- (BOOL)showRewardedAd:(NSString *)adKey completion:(AdVoidBlock)completion;

#pragma mark - Native Ad

- (GADNativeExpressAdView *)popNativeAdForKey:(NSString *)adKey;

#pragma mark - Review

/** 检查评论是否弹出 */
- (void)checkReviewIsShow;

#pragma mark - Other Function

+ (UIViewController *)topViewController;

@end
