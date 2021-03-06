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

// 友盟统计
#ifdef HEADER_UM_ANALYSE
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

/// 广告列表文件名设置
#ifndef FILE_NAME_AD_LIST
#define FILE_NAME_AD_LIST   @"ad_list"
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

/// 广告重新加载通知
static NSString *const kNoticAdReload   = @"NoticAdReload";
/// 插页广告即将显示
static NSString *const kNoticAdWillShow = @"NoticAdWillShow";
/// 插页广告消失通知
static NSString *const kNoticAdDismiss  = @"NoticAdDismiss";



typedef void (^AdVoidBlock)(void);
typedef void (^AdBannerBlock)(DFPBannerView *aBannerView);


@interface AdManager : NSObject<UIAlertViewDelegate, GADInterstitialDelegate>


+ (instancetype)shareInstance;

/// 是否可以显示广告，尽量少使用该方法
+ (BOOL)canShowAd;

/// 在App进入前台是检查所有事件
- (void)checkAllWhileAppActive;

/// 判断是否有广告或者评论显示
- (BOOL)haveAnythingInShow;

- (AdInfo *)adInfoForKey:(NSString *)adKey;

#pragma mark - Banner

/// 设置banner广告的大小
- (void)setAd:(NSString *)adKey withSize:(GADAdSize)aSize;
/// 获取banner广告的大小
- (GADAdSize)sizeForAd:(NSString *)adKey;

/// 创建banner广告
- (void)loadBannerAd:(NSString *)adKey
        receiveBlock:(AdBannerBlock)receiveBlock
         removeBlock:(AdVoidBlock)removeBlock;
- (void)loadBannerAd:(NSString *)adKey
            withSize:(GADAdSize)aSize
        receiveBlock:(AdBannerBlock)receiveBlock
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

- (void)setNativeAd:(NSString *)adKey withSize:(GADAdSize)aSize;

- (NSInteger)insertNativeAd:(NSString *)adKey inArray:(NSMutableArray *)arrItems atIndex:(NSInteger)lastAdIndex;

- (GADNativeExpressAdView *)popNativeAdForKey:(NSString *)adKey;

- (BOOL)isNativeAd:(id)aItem;

#pragma mark - Review

/** 检查评论是否弹出 */
- (void)checkReviewIsShow;

#pragma mark - Other Function

+ (UIViewController *)topViewController;

@end
