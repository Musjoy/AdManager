//
//  AdManager.m
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "AdManager.h"


#ifdef MODULE_FILE_SOURCE
#import "FileSource.h"
#endif

#ifdef MODULE_CONTROLLER_MANAGER
#import "MJControllerManager.h"
#endif

#ifdef MODULE_IAP_MANAGER
#import "IAPManager.h"
#endif
#ifdef MODULE_PROMOTION_MANAGER
#import "PromotionManager.h"
#endif

#ifdef MODULE_WEB_SERVICE
#import "MJWebService.h"
#endif
#ifdef MODULE_WEB_INTERFACE
#import "WebInterface.h"
#endif

#if __has_include(<StoreKit/StoreKit.h>)
#import <StoreKit/StoreKit.h>
#endif

/** 评论是否已经显示过 */
#define kReviewHadShow      @"ReviewHadShow"
/** 评论计数次数 */
#define kReviewShowCount    @"ReviewShowCount"
/** 评论上一次弹出时间 */
#define kReviewLastShowTime @"ReviewLastShowTime"
/// 评论显示间隔时间
#define INTERVAL_BETWEEN_REVIEW (24*60*60)
/// 首次评论激活需要次数
#define REVIEW_ACTIVE_COUNT 3

/// 弹窗起始tag
#define ALERT_TAG_START 200


/// banner接受到广告的回调
static NSString *const kReceiveCallback     = @"ReceiveCallback";
/// banner被移除的回调
static NSString *const kRemoveCallback      = @"RemoveCallback";
/// Rewarded视频回调
static NSString *const kRewardedCallback    = @"RewardedCallback";

/// 当前进入次数
static NSString *const kEnterCount          = @"EnterCount";
/// 规定时间内广告已经显示的次数
static NSString *const kAdShowCount         = @"AdShowCount";
/// 规定时间内广告已经显示的次数
static NSString *const kAdFirstShowTime     = @"AdFirstShowTime";

static AdManager *s_adManager = nil;

@interface AdManager ()<GADBannerViewDelegate, GADRewardBasedVideoAdDelegate, GADNativeExpressAdViewDelegate>

@property (nonatomic, assign) BOOL removeAdPurchased;               ///< 移除广告是否已购买
@property (nonatomic, assign) BOOL canShowAd;                       ///< 是否可以显示广告
@property (nonatomic, strong) NSDictionary *dicAdInfos;             ///< 广告信息列表，保存所有广告信息
@property (nonatomic, strong) NSMutableDictionary *dicAds;          ///< 广告列表，保存所有广告
@property (nonatomic, strong) NSMutableDictionary *dicCallback;     ///< banner广告的回调
@property (nonatomic, strong) NSMutableDictionary *dicAdCounts;     ///< 记录对应广告的激活次数等
@property (nonatomic, strong) NSMutableDictionary *dicAdRequest;    ///< 请求中的ad
@property (nonatomic, strong) NSMutableDictionary *dicAdSize;       ///< 请求中的ad


@property (nonatomic, strong) NSMutableArray *arrNeedLoadAds;       ///< 需要自动加载的广告列表
@property (nonatomic, strong) NSMutableArray *arrBannerNeedReload;  ///< 需要重新加载的banner

// 评论相关
@property (nonatomic, assign) BOOL canShowReview;                   ///< 是否可以显示评论
@property (nonatomic, assign) BOOL isReviewClick;                   ///< 是否已点击评论
@property (nonatomic, assign) BOOL reviewHadShow;                   ///< 评论是否已经显示
@property (nonatomic, assign) NSInteger reviewShowCount;            ///< 未显示过评论是的评论计数
@property (nonatomic, strong) NSDate *reviewLastShowDate;           ///< 评论最后显示时间


@property (nonatomic, assign) BOOL haveAlertShow;                   ///< 是否有alert显示

@property (nonatomic, assign) BOOL haveInterstitialAdShow;          ///< 是否有插页广告显示


@property (nonatomic, assign) GADAdSize defaultBannerSize;          ///< 默认banner尺寸

@end


@implementation AdManager

+ (instancetype)shareInstance
{
    if (s_adManager == nil) {
        s_adManager = [[self.class alloc] init];
    }
    return s_adManager;
}

+ (BOOL)canShowAd
{
    return [[AdManager shareInstance] canShowAd];
}

- (id)init
{
    self = [super init];
    if (self) {
        _canShowAd = YES;
        _canShowReview = NO;
        _arrNeedLoadAds = [[NSMutableArray alloc] init];
        _dicAds = [[NSMutableDictionary alloc] init];
        _dicCallback = [[NSMutableDictionary alloc] init];
        _dicAdCounts = [[NSMutableDictionary alloc] init];
        _dicAdRequest = [[NSMutableDictionary alloc] init];
        _dicAdSize = [[NSMutableDictionary alloc] init];
        _arrBannerNeedReload = [[NSMutableArray alloc] init];
        
#ifdef MODULE_IAP_MANAGER
        [[IAPManager shareInstance] observeProduct:IAP_PRODUCT_REMOVE_ADS purchased:^(BOOL isSucceed, NSString *message, id result) {
            if (isSucceed) {
                _removeAdPurchased = YES;
                _canShowAd = NO;
                [self removePurchaseAds];
            }
        }];
#ifdef IAP_PRODUCT_PRO_VERSION
        [[IAPManager shareInstance] observeProduct:IAP_PRODUCT_PRO_VERSION purchased:^(BOOL isSucceed, NSString *message, id result) {
            if (isSucceed) {
                _removeAdPurchased = YES;
                _canShowAd = NO;
                [self removePurchaseAds];
            }
        }];
#endif
#endif
        
        // 默认banner尺寸设置
        CGFloat adWidth = kScreenWidth;
        UIInterfaceOrientation or = [[UIApplication sharedApplication] statusBarOrientation];
        if (or == UIInterfaceOrientationLandscapeLeft ||
            or == UIInterfaceOrientationLandscapeRight) {
            adWidth = kScreenHeight;
        }
        CGFloat adHeight =  adWidth * 50.0 / 320;
        CGSize size = CGSizeMake(adWidth, adHeight);
        _defaultBannerSize = GADAdSizeFromCGSize(size);
        
        // 评论
        self.isReviewClick = [[NSUserDefaults standardUserDefaults] boolForKey:kReviewIsClick];
        self.reviewHadShow = [[NSUserDefaults standardUserDefaults] boolForKey:kReviewHadShow];
        self.reviewShowCount = [[NSUserDefaults standardUserDefaults] integerForKey:kReviewShowCount];
        self.reviewLastShowDate = [[NSUserDefaults standardUserDefaults] objectForKey:kReviewLastShowTime];
        
        
        [self reloadData];
        
#ifdef MODULE_FILE_SOURCE
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reloadData)
                                                     name:[kNoticPlistUpdate stringByAppendingString:FILE_NAME_AD_LIST]
                                                   object:nil];
#endif
        
    }
    return self;
}

#pragma mark - Notification Receive

- (void)reloadData
{
    if (!_removeAdPurchased) {
        _canShowAd = YES;
    }
    
    [_arrNeedLoadAds removeAllObjects];
    // 读取plist文件
    NSDictionary *dicAdKeys = getFileData(FILE_NAME_AD_LIST);
    if (dicAdKeys == nil
        || (dicAdKeys && ![dicAdKeys isKindOfClass:[NSDictionary class]])) {
        self.canShowAd = NO;
        self.canShowReview = NO;
        return;
    }
    
    NSNumber *canshowAd = [dicAdKeys objectForKey:@"canShowAd"];
    if (canshowAd && [canshowAd boolValue] == NO) {
        self.canShowAd = NO;
    }
    NSMutableDictionary *dicAdInfos = [[NSMutableDictionary alloc] init];
    NSDictionary *dicAds = [dicAdKeys objectForKey:@"adList"];
    for (NSString *adKey in dicAds.allKeys) {
        NSDictionary *dicAdInfo = dicAds[adKey];
        AdInfo *adInfo = [[AdInfo alloc] initWithData:dicAdInfo];
        adInfo.adKey = adKey;
        [dicAdInfos setObject:adInfo forKey:adKey];
        if (adInfo.adType == 3
            || ((adInfo.adType == 2 || adInfo.adType == 4)
                && (adInfo.forceLoad || (_canShowAd && adInfo.autoLoad)))) {
            [_arrNeedLoadAds addObject:adInfo];
        }
    }
    self.dicAdInfos = dicAdInfos;
    
    NSNumber *canShowReview = [dicAdKeys objectForKey:@"canShowReview"];
    if (canShowReview && [canShowReview boolValue] == YES) {
        self.canShowReview = YES;
    } else {
        self.canShowReview = NO;
    }
    
    if (_canShowAd && _arrBannerNeedReload.count > 0) {
        for (NSString *aAdKey in _arrBannerNeedReload) {
            [self reloadBannerAd:aAdKey];
        }
        [_arrBannerNeedReload removeAllObjects];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNoticAdReload object:nil];
    
}

#pragma mark - Public

- (void)startPrepare
{
    for (int i=0, len= (int)_arrNeedLoadAds.count; i<len; i++) {
        AdInfo *aAdInfo = _arrNeedLoadAds[i];
        [self checkPreloadAd:aAdInfo.adKey];
    }
    [_arrNeedLoadAds removeAllObjects];
}

- (void)checkAllWhileAppActive
{
    [[AdManager shareInstance] startPrepare];
    [[AdManager shareInstance] checkReviewIsShow];
    [[AdManager shareInstance] checkInterstitialAd:KEY_AD_INTERSTITIAL_LAUNCH];
}

- (BOOL)haveAnythingInShow
{
    return _haveInterstitialAdShow||_haveAlertShow;
}

- (AdInfo *)adInfoForKey:(NSString *)adKey
{
    return _dicAdInfos[adKey];
}

- (id)prepareForAd:(NSString *)aAdKey
{
    AdInfo *aAdInfo = [_dicAdInfos objectForKey:aAdKey];
    if (aAdInfo == nil) {
        return nil;
    }
    id aAd = nil;
    if (aAdInfo.adPreloadCount == 1) {
        aAd = [_dicAds objectForKey:aAdKey];
        if (aAd) {
            if ([aAd isKindOfClass:[NSMutableArray class]]) {
                [_dicAds removeObjectForKey:aAdKey];
            } else {
                return aAd;
            }
        }
    }
    
    aAd = [self createAdWith:aAdInfo];
    if (aAd) {
        // Native广告只用加载完成了才能放进来
        if (aAdInfo.adType != 4) {
            [self setAd:aAd forKey:aAdKey];
        }
    }
    return aAd;
}

#pragma mark - Banner

- (void)setAd:(NSString *)adKey withSize:(GADAdSize)aSize
{
    if (adKey.length == 0) {
        return;
    }
    NSValue *aValue = [NSValue valueWithBytes:&aSize objCType:@encode(GADAdSize)];
    [_dicAdSize setObject:aValue forKey:adKey];
}

- (GADAdSize)sizeForAd:(NSString *)adKey
{
    NSValue *aValue = [_dicAdSize objectForKey:adKey];
    if (aValue) {
        GADAdSize aSize;
        [aValue getValue:&aSize];
        return aSize;
    }
    return _defaultBannerSize;
}

- (void)loadBannerAd:(NSString *)adKey
        receiveBlock:(AdBannerBlock)receiveBlock
         removeBlock:(AdVoidBlock)removeBlock
{
    [self loadBannerAd:adKey withSize:_defaultBannerSize receiveBlock:receiveBlock removeBlock:removeBlock];
}

- (void)loadBannerAd:(NSString *)adKey withSize:(GADAdSize)aSize receiveBlock:(AdBannerBlock)receiveBlock removeBlock:(AdVoidBlock)removeBlock
{
    if (receiveBlock || removeBlock) {
        NSMutableDictionary *aDic = [[NSMutableDictionary alloc] init];
        if (receiveBlock) {
            [aDic setObject:receiveBlock forKey:kReceiveCallback];
        }
        if (removeBlock) {
            [aDic setObject:removeBlock forKey:kRemoveCallback];
        }
        [_dicCallback setObject:aDic forKey:adKey];
    }
    if (![self canShowAd]) {
        [_arrBannerNeedReload addObject:adKey];
        return;
    }
    DFPBannerView *banner = (DFPBannerView *)[self prepareForAd:adKey];
    if (banner == nil) {
        if (_dicAdInfos[adKey]) {
            triggerEventStr(stat_Error, [adKey stringByAppendingString:@" 无法创建"]);
            LogError(@"创建banner广告 {%@} 失败", adKey);
        }
        [_arrBannerNeedReload addObject:adKey];
        return;
    }
    [banner resize:aSize];
    [_dicAdRequest setObject:banner forKey:adKey];
    [banner loadRequest:[GADRequest request]];
}

/// 重新加载该banner
- (BOOL)reloadBannerAd:(NSString *)adKey
{
    DFPBannerView *banner = (DFPBannerView *)[self prepareForAd:adKey];
    if (banner == nil) {
        return NO;
    }
    [banner resize:[self sizeForAd:adKey]];
    [_dicAdRequest setObject:banner forKey:adKey];
    [banner loadRequest:[GADRequest request]];
    return YES;
}

#pragma mark - Interstitial Ad

- (void)checkInterstitialAd:(NSString *)adKey
{
    if (![self.class canShowAd] ) {
        return;
    }
    if (_haveInterstitialAdShow) {
        return;
    }
#ifdef MODULE_PROMOTION_MANAGER
    if ([[PromotionManager shareInstance] haveAnythingInShow]) {
        return;
    }
#endif
    // 是否在处理购买操作
#ifdef MODULE_IAP_MANAGER
    if ([[IAPManager shareInstance] isProcessing]) {
        return;
    }
#endif
    
    AdInfo *aAdInfo = _dicAdInfos[adKey];
    if (aAdInfo == nil) {
        return;
    }
    
    NSMutableDictionary *countInfo = _dicAdCounts[adKey];
    if (countInfo == nil) {
        countInfo = [[NSMutableDictionary alloc] init];
        [_dicAdCounts setObject:countInfo forKey:adKey];
    }
    int enterCount = [countInfo[kEnterCount] intValue];
    int adShowCount = [countInfo[kAdShowCount] intValue];
    NSDate *adFirstShowTime = countInfo[kAdFirstShowTime];
    
    
    enterCount++;
    if (enterCount%(aAdInfo.adActiveCount+1) == 1) {
        adShowCount++;
        NSDate *aAdFirstShowTime = nil;
        if (adShowCount%(aAdInfo.adMaxShowCount+1) == 1) {
            // 1 4 7, 存起来做比较，需要判断离上次时间
            NSDate *curDate = [NSDate date];
            if (adFirstShowTime == nil) {
                aAdFirstShowTime = curDate;
            } else {
                if ([curDate timeIntervalSinceDate:adFirstShowTime] > aAdInfo.adResetTime * 60) {
                    // 大于重置时间，可以显示
                    aAdFirstShowTime = curDate;
                } else {
                    // 如果小于的话，减掉改次计数，相当于改次计算不算
                    
                    
                    return;
                }
            }
        }
        if (adShowCount >= aAdInfo.adMaxShowCount) {
            adShowCount = 0;
        }

        if (![self showInterstitialAd:adKey]) {
            // 未显示成功，改次计数也不算
           
            return;
        }
        if (aAdFirstShowTime) {
            adFirstShowTime = aAdFirstShowTime;
            countInfo[kAdFirstShowTime] = adFirstShowTime;
        }
    }
    if (enterCount >= aAdInfo.adActiveCount) {
        enterCount = 0;
    }

    countInfo[kEnterCount] = [NSNumber numberWithInt:enterCount];
    countInfo[kAdShowCount] = [NSNumber numberWithInt:adShowCount];
}


- (BOOL)canShowAd:(NSString *)adKey
{
    AdInfo *aAdInfo = _dicAdInfos[adKey];
    if (aAdInfo == nil) {
        return NO;
    }
    GADInterstitial *adInterstitial = [self firstAdForKey:adKey];
    if (adInterstitial == nil) {
        [self checkPreloadAd:adKey];
        return NO;
    }
    if (!adInterstitial.isReady || adInterstitial.hasBeenUsed) {
        return NO;
    }
    return YES;
}

/** 显示插页广告 */
- (BOOL)showInterstitialAd:(NSString *)adKey
{
    LogTrace(@">>>> Interstitial Ad May Show");
    if (_haveInterstitialAdShow) {
        return NO;
    }
    
    GADInterstitial *adInterstitial = [self firstAdForKey:adKey];;
    if (adInterstitial == nil) {
        [self checkPreloadAd:adKey];
        return NO;
    }
    if (!adInterstitial.isReady) {
        return NO;
    }
    LogTrace(@">>>> Interstitial Ad Did Show");
    AdInfo *aAdInfo = _dicAdInfos[adKey];
    NSString *adName = aAdInfo.adName;
    if (adName.length == 0) {
        adName = adKey;
    }
    triggerEvent(stat_ShowCountInterstitialAd, @{@"name":adName});

    [[NSNotificationCenter defaultCenter] postNotificationName:kNoticAdWillShow object:adKey userInfo:@{@"ad":adInterstitial}];
    
    [adInterstitial presentFromRootViewController:[self.class topViewController]];
    _haveInterstitialAdShow = YES;
    return YES;
}

#pragma mark - MoreApp

- (BOOL)hadMoreApp
{
    return [self canShowAd:KEY_AD_MORE_APPS];
}

- (void)moreAppsClick
{
    [self showInterstitialAd:KEY_AD_MORE_APPS];
}


#pragma mark - Revarded Ad

- (void)addRewardedAdCount:(NSString *)adKey
{
    if (_haveInterstitialAdShow) {
        return;
    }
    AdInfo *aAdInfo = _dicAdInfos[adKey];
    if (aAdInfo == nil) {
        return;
    }
    
    NSMutableDictionary *countInfo = _dicAdCounts[adKey];
    if (countInfo == nil) {
        countInfo = [[NSMutableDictionary alloc] init];
        [_dicAdCounts setObject:countInfo forKey:adKey];
    }
    int enterCount = [countInfo[kEnterCount] intValue];
    if (enterCount%(aAdInfo.adActiveCount+1) == 1) {
        // 正在等待显示
    } else {
        enterCount++;
        if (enterCount > aAdInfo.adActiveCount) {
            enterCount = 0;
        }
        countInfo[kEnterCount] = [NSNumber numberWithInt:enterCount];
    }
}

- (BOOL)haveRewardedAd:(NSString *)adKey
{
    AdInfo *aAdInfo = _dicAdInfos[adKey];
    if (aAdInfo == nil) {
        return NO;
    }
    
    NSMutableDictionary *countInfo = _dicAdCounts[adKey];
    if (countInfo == nil) {
        countInfo = [[NSMutableDictionary alloc] init];
        [_dicAdCounts setObject:countInfo forKey:adKey];
    }
    
    if (aAdInfo.adActiveCount > 0) {
        int enterCount = [countInfo[kEnterCount] intValue];
        if (enterCount%(aAdInfo.adActiveCount+1) != 1) {
            return NO;
        }
    } else if (aAdInfo.adResetTime > 0) {
        NSDate *adFirstShowTime = countInfo[kAdFirstShowTime];
        NSDate *curDate = [NSDate date];
        if (adFirstShowTime && [curDate timeIntervalSinceDate:adFirstShowTime] < aAdInfo.adResetTime * 60) {
            return NO;
        }
    }
    
    GADRewardBasedVideoAd *adRewarded = [self firstAdForKey:adKey];
    if (adRewarded == nil) {
        [self checkPreloadAd:adKey];
        return NO;
    }
    if (!adRewarded.isReady) {
        return NO;
    }
    
    return YES;
}

- (BOOL)showRewardedAd:(NSString *)adKey completion:(AdVoidBlock)completion
{
    LogTrace(@">>>> Rewarded Ad May Show");
    if (_haveInterstitialAdShow) {
        return NO;
    }
    
    GADRewardBasedVideoAd *adRewarded = _dicAds[adKey];
    if (adRewarded == nil) {
        [self checkPreloadAd:adKey];
        return NO;
    }
    if (!adRewarded.isReady) {
        return NO;
    }
    LogTrace(@">>>> Rewarded Ad Did Show");
    AdInfo *aAdInfo = _dicAdInfos[adKey];
    NSString *adName = aAdInfo.adName;
    if (adName.length == 0) {
        adName = adKey;
    }
    triggerEvent(stat_ShowCountRewardedAd, @{@"name":adName});
    
    if (completion) {
        NSDictionary *aDic = @{kRewardedCallback:completion};
        [_dicCallback setObject:aDic forKey:adKey];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNoticAdWillShow object:adKey userInfo:@{@"ad":adRewarded}];
    
    [adRewarded presentFromRootViewController:[self.class topViewController]];
    _haveInterstitialAdShow = YES;
    NSMutableDictionary *countInfo = _dicAdCounts[adKey];
    countInfo[kAdFirstShowTime] = [NSDate date];
    return YES;
}


#pragma mark - Native Ad

- (void)setNativeAd:(NSString *)adKey withSize:(GADAdSize)aSize
{
    if (adKey.length == 0) {
        return;
    }
    NSValue *aValue = [NSValue valueWithBytes:&aSize objCType:@encode(GADAdSize)];
    [_dicAdSize setObject:aValue forKey:adKey];
}

- (GADAdSize)sizeForNativeAd:(NSString *)adKey
{
    NSValue *aValue = [_dicAdSize objectForKey:adKey];
    if (aValue) {
        GADAdSize aSize;
        [aValue getValue:&aSize];
        return aSize;
    }
    return kGADAdSizeLargeBanner;
}

- (NSInteger)insertNativeAd:(NSString *)adKey inArray:(NSMutableArray *)arrItems atIndex:(NSInteger)lastAdIndex
{
    AdInfo *aAdInfo = [self adInfoForKey:adKey];
    if (aAdInfo == nil) {
        return lastAdIndex;
    }
    
    int insertCount = aAdInfo.adActiveCount;
    if (insertCount < 1) {
        insertCount = 1;
    }
    
    while (lastAdIndex + insertCount+1 <= arrItems.count) {
        id adNative = [self popNativeAdForKey:adKey];
        if (adNative == nil) {
            return lastAdIndex;
        }
        
        // 插入该Ad
        lastAdIndex += insertCount+1;
        [arrItems insertObject:adNative atIndex:lastAdIndex];
    }
    return lastAdIndex;
}

- (GADNativeExpressAdView *)popNativeAdForKey:(NSString *)adKey
{
    // 是否能显示广告
    if (![self canShowAd]) {
        return nil;
    }
    // 是否有该广告信息
    AdInfo *aAdInfo = _dicAdInfos[adKey];
    if (aAdInfo == nil) {
        return nil;
    }
    
    // 读取已加载的广告列表
    GADNativeExpressAdView *aNativeAd = [self firstAdForKey:adKey];
    if (aNativeAd == nil) {
        [self checkPreloadAd:adKey];
        return nil;
    }
    [self removeAd:aNativeAd forKey:adKey];
    [self checkPreloadAd:adKey];
    return aNativeAd;
}

- (BOOL)isNativeAd:(id)aItem
{
    if ([aItem isKindOfClass:[GADNativeExpressAdView class]]) {
        return YES;
    }
    return NO;
}


#pragma mark - Private

- (id)createAdWith:(AdInfo *)aAdInfo
{
    id aAd = nil;
    if (aAdInfo.adId.length == 0) {
        return aAd;
    }
    if ([_dicAdRequest objectForKey:aAdInfo.adKey]) {
        LogError(@"Already have a request for %@", aAdInfo.adKey);
        return aAd;
    }
    switch (aAdInfo.adType) {
        case 1:
        {
            DFPBannerView *banner = [[DFPBannerView alloc] initWithFrame:CGRectZero];
            banner.adUnitID = aAdInfo.adId;
            banner.delegate = self;
            banner.rootViewController = [self.class topViewController];
//            [banner loadRequest:[GADRequest request]];
            aAd = banner;
            break;
        }
        case 2:
        {
            GADInterstitial *adInterstitial = [[GADInterstitial alloc] initWithAdUnitID:aAdInfo.adId];
            adInterstitial.delegate = self;
            GADRequest* request = [GADRequest request];
            [_dicAdRequest setObject:adInterstitial forKey:aAdInfo.adKey];
            [adInterstitial loadRequest:request];
            aAd = adInterstitial;
            break;
        }
        case 3:
        {
            GADRewardBasedVideoAd *adRewarded = [GADRewardBasedVideoAd sharedInstance];
            adRewarded.delegate = self;
            GADRequest* request = [GADRequest request];
            [_dicAdRequest setObject:adRewarded forKey:aAdInfo.adKey];
            [adRewarded loadRequest:request withAdUnitID:aAdInfo.adId];
            aAd = adRewarded;
            break;
        }
        case 4:
        {
            GADNativeExpressAdView *adNative = [[GADNativeExpressAdView alloc] initWithAdSize:[self sizeForNativeAd:aAdInfo.adKey]];
            adNative.adUnitID = aAdInfo.adId;
            adNative.delegate = self;
            adNative.rootViewController = [[self class] topViewController];
            GADRequest* request = [GADRequest request];
            [_dicAdRequest setObject:adNative forKey:aAdInfo.adKey];
            [adNative loadRequest:request];
            aAd = adNative;
            break;
        }
        default:
            break;
    }
    return aAd;
}

- (NSString *)adKeyForRequestAd:(id)aAd
{
    for (NSString *aKey in _dicAdRequest.allKeys) {
        if (_dicAdRequest[aKey] == aAd) {
            return aKey;
        }
    }
    return nil;
}

- (NSString *)adKeyForPrepareAd:(id)aAd
{
    for (NSString *aKey in _dicAds.allKeys) {
        id adData = _dicAds[aKey];
        if ([adData isKindOfClass:[NSMutableArray class]]) {
            if ([adData containsObject:aAd]) {
                return aKey;
            }
        } else if (adData == aAd) {
            return aKey;
        }
    }
    return nil;
}


/// 移除被购买的广告
- (void)removePurchaseAds
{
    for (NSString *adKey in _dicAds.allKeys) {
        AdInfo *aAdInfo = _dicAdInfos[adKey];
        if (aAdInfo.adType == 1) {
            NSDictionary *aDicCallback = _dicCallback[adKey];
            if (aDicCallback) {
                AdVoidBlock removeBlock = aDicCallback[kRemoveCallback];
                if (removeBlock) {
                    removeBlock();
                }
                [_dicCallback removeObjectForKey:adKey];
            }
            [_dicAds removeObjectForKey:adKey];
        } else if (aAdInfo.adType == 2) {
            if (!aAdInfo.forceLoad) {
                [_dicAds removeObjectForKey:adKey];
            }
        }
    }
}

- (void)checkPreloadAd:(NSString *)adKey
{
    // 读取广告信息，看是否需要继续加载广告
    AdInfo *aAdInfo = [_dicAdInfos objectForKey:adKey];
    if (aAdInfo) {
        if (aAdInfo.adPreloadCount <= 1) {
            id aAd = [_dicAds objectForKey:adKey];
            if (aAd) {
                if (![aAd isKindOfClass:[NSMutableArray class]]) {
                    return;
                } else {
                    [_dicAds removeObjectForKey:adKey];
                }
            }
            [self prepareForAd:adKey];
        } else {
            NSMutableArray *arrAds = [_dicAds objectForKey:adKey];
            if (arrAds && ![arrAds isKindOfClass:[NSMutableArray class]]) {
                [_dicAds removeObjectForKey:adKey];
                arrAds = nil;
            }
            if (arrAds == nil) {
                arrAds = [[NSMutableArray alloc] init];
                [_dicAds setObject:arrAds forKey:adKey];
            }
            if (arrAds.count < aAdInfo.adPreloadCount) {
                [self prepareForAd:adKey];
            }
        }
    }
}

#pragma mark - Ad For Key

- (void)setAd:(id)aAd forKey:(NSString *)adKey
{
    AdInfo *aAdInfo = [_dicAdInfos objectForKey:adKey];
    if (aAdInfo) {
        if (aAdInfo.adPreloadCount <= 1) {
            [_dicAds setObject:aAd forKey:adKey];
        } else {
            NSMutableArray *arrAds = [_dicAds objectForKey:adKey];
            if (arrAds == nil || ![arrAds isKindOfClass:[NSMutableArray class]]) {
                arrAds = [[NSMutableArray alloc] init];
                [_dicAds setObject:arrAds forKey:adKey];
            }
            [arrAds addObject:aAd];
        }
    }
}

- (id)firstAdForKey:(NSString *)adKey
{
    AdInfo *aAdInfo = [_dicAdInfos objectForKey:adKey];
    if (aAdInfo) {
        id aAd = nil;
        // 读取已加载的广告列表
        id adData = [_dicAds objectForKey:adKey];
        if (adData && [adData isKindOfClass:[NSMutableArray class]]) {
            if ([(NSArray *)adData count] > 0) {
                aAd = adData[0];
            }
        } else {
            aAd = adData;
        }
        return aAd;
    }
    return nil;
}

- (void)removeAd:(id)aAd forKey:(NSString *)adKey
{
    AdInfo *aAdInfo = [_dicAdInfos objectForKey:adKey];
    if (aAdInfo) {
        if (aAdInfo.adPreloadCount <= 1) {
            [_dicAds removeObjectForKey:adKey];
        } else {
            NSMutableArray *arrAds = [_dicAds objectForKey:adKey];
            if ([arrAds isKindOfClass:[NSMutableArray class]]) {
                [arrAds removeObject:aAd];
            } else {
                [_dicAds removeObjectForKey:adKey];
            }
        }
    }
}

#pragma mark - Review

- (void)checkReviewIsShow
{
    if (!_canShowReview) {
        return;
    }
    if (_haveAlertShow) {
        return;
    }
    if (_isReviewClick) {
        // 如果已经点击或，返回
        return;
    }
#ifdef MODULE_PROMOTION_MANAGER
    if ([[PromotionManager shareInstance] haveAnythingInShow]) {
        return;
    }
#endif
    // 是否在处理购买操作
#ifdef MODULE_IAP_MANAGER
    if ([[IAPManager shareInstance] isProcessing]) {
        return;
    }
#endif
    if (_reviewHadShow) {
        // 如果已经显示过，按天算
        NSDate *curDate = [NSDate date];
        if (_reviewLastShowDate == nil || [curDate timeIntervalSinceDate:_reviewLastShowDate] > INTERVAL_BETWEEN_REVIEW) {
            [self showReviewView];
        }
    } else {
        _reviewShowCount++;
        [[NSUserDefaults standardUserDefaults] setInteger:_reviewShowCount forKey:kReviewShowCount];
        if (_reviewShowCount >= REVIEW_ACTIVE_COUNT) {
            [self showReviewView];
        }
    }
}


- (void)showReviewView
{
    LogTrace(@">>>> Review View Show");
    if (_haveInterstitialAdShow) {
        return;
    }
    
    triggerEvent(stat_Review, @{@"name":@"显示"});
    _reviewHadShow = YES;
    _reviewLastShowDate = [NSDate date];
    _haveAlertShow = YES;
    [[NSUserDefaults standardUserDefaults] setBool:_reviewHadShow forKey:kReviewHadShow];
    [[NSUserDefaults standardUserDefaults] setObject:_reviewLastShowDate forKey:kReviewLastShowTime];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                        message:NSLocalizedString(@"alert_review_message", @"Rate Me")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"alert_noThanks", @"No, Thanks")
                                              otherButtonTitles:NSLocalizedString(@"alert_review_ok", @"Review"), nil];
    [alertView setTag:ALERT_TAG_START];
    [alertView show];
}

#pragma mark - GADBannerViewDelegate


/// Tells the delegate that an ad request successfully received an ad. The delegate may want to add
/// the banner view to the view hierarchy if it hasn't been added yet.
- (void)adViewDidReceiveAd:(GADBannerView *)bannerView
{
    LogInfo(@"Banner ad receive");
    NSString *adKey = [self adKeyForRequestAd:bannerView];
    if (adKey.length == 0) {
        return;
    }
    [_dicAdRequest removeObjectForKey:adKey];
    NSDictionary *dicBlock = _dicCallback[adKey];
    if (dicBlock) {
        AdBannerBlock receiveBlock = dicBlock[kReceiveCallback];
        if (receiveBlock) {
            receiveBlock((DFPBannerView *)bannerView);
        }
    }
    [bannerView setBackgroundColor:[UIColor clearColor]];
}

/// Tells the delegate that an ad request failed. The failure is normally due to network
/// connectivity or ad availablility (i.e., no fill).
- (void)adView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(GADRequestError *)error
{
    LogError(@"Load banner %@", error);
}

#pragma mark - GADInterstitialDelegate


/// Called when an interstitial ad request succeeded. Show it at the next transition point in your
/// application such as when transitioning between view controllers.
- (void)interstitialDidReceiveAd:(GADInterstitial *)ad
{
    NSString *adKey = [self adKeyForRequestAd:ad];
    if (adKey) {
        [_dicAdRequest removeObjectForKey:adKey];
        [self checkPreloadAd:adKey];
    }
}

/// Called when an interstitial ad request completed without an interstitial to
/// show. This is common since interstitials are shown sparingly to users.
- (void)interstitial:(GADInterstitial *)ad didFailToReceiveAdWithError:(GADRequestError *)error
{
    NSString *adKey = [self adKeyForRequestAd:ad];
    if (adKey) {
        [self removeAd:ad forKey:adKey];
        [_dicAdRequest removeObjectForKey:adKey];
        [self performSelector:@selector(prepareForAd:) withObject:adKey afterDelay:50];
    }
    
    LogError(@"Load Interstitial %@", error);
}


/// Called before the interstitial is to be animated off the screen.
- (void)interstitialWillDismissScreen:(GADInterstitial *)ad
{

}

- (void)interstitialDidDismissScreen:(GADInterstitial *)ad
{
    _haveInterstitialAdShow = NO;
    NSString *adKey = [self adKeyForPrepareAd:ad];
    [self removeAd:ad forKey:adKey];
    [self checkPreloadAd:adKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNoticAdDismiss object:adKey userInfo:@{@"ad":ad}];
}

#pragma mark - GADRewardBasedVideoAdDelegate

/// Tells the delegate that the reward based video ad has been received.
- (void)rewardBasedVideoAdDidReceiveAd:(GADRewardBasedVideoAd *)rewardBasedVideoAd
{
    NSLog(@"Received rewarded ad");
    NSString *adKey = [self adKeyForRequestAd:rewardBasedVideoAd];
    if (adKey) {
        [_dicAdRequest removeObjectForKey:adKey];
        [self checkPreloadAd:adKey];
    }
}

/// Tells the delegate that the reward based video ad has failed to load.
- (void)rewardBasedVideoAd:(GADRewardBasedVideoAd *)rewardBasedVideoAd
    didFailToLoadWithError:(NSError *)error
{
    NSString *adKey = [self adKeyForRequestAd:rewardBasedVideoAd];
    if (adKey) {
        [self removeAd:rewardBasedVideoAd forKey:adKey];
        [_dicAdRequest removeObjectForKey:adKey];
        [self performSelector:@selector(prepareForAd:) withObject:adKey afterDelay:50];
    }
    LogError(@"Load Rewarded %@", error);
}

/// Tells the delegate that the reward based video ad is opened.
- (void)rewardBasedVideoAdDidOpen:(GADRewardBasedVideoAd *)rewardBasedVideoAd
{

}

/// Tells the delegate that the reward based video ad has started playing.
- (void)rewardBasedVideoAdDidStartPlaying:(GADRewardBasedVideoAd *)rewardBasedVideoAd
{
    
}

/// Tells the delegate that the reward based video ad is closed.
- (void)rewardBasedVideoAdDidClose:(GADRewardBasedVideoAd *)rewardBasedVideoAd
{
    _haveInterstitialAdShow = NO;
    NSString *adKey = [self adKeyForPrepareAd:rewardBasedVideoAd];
    if (adKey) {
        NSDictionary *aDic = _dicCallback[adKey];
        if (aDic) {
            AdVoidBlock rewardedCallback = aDic[kRewardedCallback];
            if (rewardedCallback) {
                rewardedCallback();
            }
            [_dicCallback removeObjectForKey:adKey];
        }
        [self removeAd:rewardBasedVideoAd forKey:adKey];
        [self checkPreloadAd:adKey];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kNoticAdDismiss object:adKey userInfo:@{@"ad":rewardBasedVideoAd}];
}

/// Tells the delegate that the reward based video ad will leave the application.
- (void)rewardBasedVideoAdWillLeaveApplication:(GADRewardBasedVideoAd *)rewardBasedVideoAd
{
    
}

/// Tells the delegate that the reward based video ad has rewarded the user.
- (void)rewardBasedVideoAd:(GADRewardBasedVideoAd *)rewardBasedVideoAd
   didRewardUserWithReward:(GADAdReward *)reward
{
    
}


#pragma mark - GADNativeExpressAdViewDelegate

- (void)nativeExpressAdViewDidReceiveAd:(GADNativeExpressAdView *)nativeExpressAdView
{
    NSLog(@"Received native ad");
    NSString *adKey = [self adKeyForRequestAd:nativeExpressAdView];
    if (adKey) {
        [_dicAdRequest removeObjectForKey:adKey];
        [self setAd:nativeExpressAdView forKey:adKey];
        [self checkPreloadAd:adKey];
    }
}

- (void)nativeExpressAdView:(GADNativeExpressAdView *)nativeExpressAdView
didFailToReceiveAdWithError:(GADRequestError *)error
{
    LogError(@"Load native error %@", error);
    NSString *adKey = [self adKeyForRequestAd:nativeExpressAdView];
    if (adKey) {
        [self removeAd:nativeExpressAdView forKey:adKey];
        [_dicAdRequest removeObjectForKey:adKey];
        [self performSelector:@selector(prepareForAd:) withObject:adKey afterDelay:50];
    }

}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == ALERT_TAG_START) {
        if (buttonIndex == 1) {
            // 点击评论
            triggerEvent(stat_Review, @{@"name":@"点击"});
            _isReviewClick = YES;
            [[NSUserDefaults standardUserDefaults] setBool:_isReviewClick forKey:kReviewIsClick];
#ifdef AppComment
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:AppComment]];
#endif
        }
        _haveAlertShow = NO;
    }
}


#pragma mark - Other Function

+ (UIViewController *)topViewController
{
#ifdef MODULE_CONTROLLER_MANAGER
    return [MJControllerManager topNavViewController];
#else
    UIViewController *topVC = nil;
    
    // Find the top window (that is not an alert view or other window)
    UIWindow *topWindow = [[UIApplication sharedApplication] keyWindow];
    if (topWindow.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(topWindow in windows) {
            if (topWindow.windowLevel == UIWindowLevelNormal)
                break;
        }
    }
    
    UIView *rootView = [[topWindow subviews] objectAtIndex:0];
    id nextResponder = [rootView nextResponder];
    
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        topVC = nextResponder;
    } else if ([topWindow respondsToSelector:@selector(rootViewController)] && topWindow.rootViewController != nil) {
        topVC = topWindow.rootViewController;
    } else {
        NSAssert(NO, @"Could not find a root view controller.");
    }
    
    UIViewController *presentVC = topVC.presentedViewController;
    while (presentVC) {
        topVC = presentVC;
        presentVC = topVC.presentedViewController;
    }
    return topVC;
#endif
}

@end
