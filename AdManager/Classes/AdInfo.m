//
//  AdInfo.m
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "AdInfo.h"

@implementation AdInfo

- (instancetype)initWithData:(NSDictionary *)aDic
{
    self = [super init];
    if (self) {
        self.adKey = aDic[@"adKey"];
        self.adId = aDic[@"adId"];
        self.adName = aDic[@"adName"];
        self.adType = [aDic[@"adType"] intValue];
        self.autoLoad = [aDic[@"autoLoad"] boolValue];
        self.adActiveCount = [aDic[@"adActiveCount"] intValue];
        self.adMaxShowCount = [aDic[@"adMaxShowCount"] intValue];
        self.adResetTime = [aDic[@"adResetTime"] intValue];
    }
    return self;
}

@end
