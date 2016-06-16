//
//  AdInfo.h
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AdInfo : NSObject

@property (nonatomic, strong) NSString *adKey;                  ///< 广告标示key
@property (nonatomic, strong) NSString *adId;                   ///< 广告Id
@property (nonatomic, strong) NSString *adName;                 ///< 广告名称
@property (nonatomic, assign) int adType;                       ///< 广告类型<1-banner, 2-插页广告, 3-奖励广告, 4-Native广告>
@property (nonatomic, assign) BOOL forceLoad;                   ///< 强制加载
@property (nonatomic, assign) BOOL autoLoad;                    ///< 是否自动加载
@property (nonatomic, assign) int adActiveCount;                ///< 广告显示所需触发次数
@property (nonatomic, assign) int adMaxShowCount;               ///< 广告在adResetTime时间内最多显示次数
@property (nonatomic, assign) int adResetTime;                  ///< 最多显示次数重置时间
@property (nonatomic, assign) int adPreloadCount;               ///< 广告预加载条数，默认是1

- (instancetype)initWithData:(NSDictionary *)aDic;

@end
