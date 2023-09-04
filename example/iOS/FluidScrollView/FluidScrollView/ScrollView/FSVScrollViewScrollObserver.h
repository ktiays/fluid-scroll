//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <UIKit/UIKit.h>

@class FSVScrollView;

NS_ASSUME_NONNULL_BEGIN

@protocol FSVScrollViewScrollObserver <NSObject>

- (void)observeScrollViewDidScroll:(FSVScrollView *)scrollView;

@end

NS_ASSUME_NONNULL_END
