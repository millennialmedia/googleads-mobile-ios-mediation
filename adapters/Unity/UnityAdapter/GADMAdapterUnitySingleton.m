// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GADMAdapterUnitySingleton.h"

#import "GADMAdapterUnityConstants.h"
#import "GADMAdapterUnityWeakReference.h"

@interface GADMAdapterUnitySingleton () <UnityAdsExtendedDelegate, UnityAdsBannerDelegate> {
  /// Array to hold all adapter delegates.
  NSMutableArray *_adapterDelegates;

  /// Connector from unity adapter to send Unity callbacks.
  __weak id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate> _currentShowingUnityDelegate;

  /// Connector from unity adapter to send Banner callbacks
  __weak id<GADMAdapterUnityDataProvider, UnityAdsBannerDelegate> _currentBannerDelegate;

}

@end

@implementation GADMAdapterUnitySingleton

NSString* _bannerPlacementID = nil;
bool _bannerRequested = false;

+ (instancetype)sharedInstance {
  static GADMAdapterUnitySingleton *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
  });
  return sharedManager;
}

- (id)init {
  self = [super init];
  if (self) {
    _adapterDelegates = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)initializeWithGameID:(NSString *)gameID {
  // Metadata needed by Unity Ads SDK before initialization.
  UADSMediationMetaData *mediationMetaData = [[UADSMediationMetaData alloc] init];
  [mediationMetaData setName:GADMAdapterUnityMediationNetworkName];
  [mediationMetaData setVersion:GADMAdapterUnityVersion];
  [mediationMetaData commit];
  // Initializing Unity Ads with |gameID|.
  [UnityAds initialize:gameID delegate:self];
}

- (void)addAdapterDelegate:
                      (id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate>)adapterDelegate {
  GADMAdapterUnityWeakReference *delegateReference =
      [[GADMAdapterUnityWeakReference alloc] initWithObject:adapterDelegate];
  // Removes duplicate delegate references.
  [self removeAdapterDelegate:delegateReference];
  [_adapterDelegates addObject:delegateReference];
}

- (void)removeAdapterDelegate:(GADMAdapterUnityWeakReference *)adapterDelegate {
  // Removes duplicate mediation adapter delegate references.
  NSMutableArray *delegatesToRemove = [NSMutableArray array];
  [_adapterDelegates
      enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        GADMAdapterUnityWeakReference *weakReference = obj;
        if ([weakReference isEqual:adapterDelegate]) {
          [delegatesToRemove addObject:obj];
        }
      }];
  [_adapterDelegates removeObjectsInArray:delegatesToRemove];
}

#pragma mark - Rewardbased video ad methods

- (BOOL)configureRewardBasedVideoAdWithGameID:(NSString *)gameID
                                     delegate:
                                        (id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate>)
                                            adapterDelegate {
  if ([UnityAds isSupported]) {
    if (![UnityAds isInitialized]) {
      // Add delegate reference in adapterDelegate list only if Unity Ads is not initialized.
      [self addAdapterDelegate:adapterDelegate];
      [self initializeWithGameID:gameID];
    }
    return YES;
  }
  return NO;
}

- (void)requestRewardBasedVideoAdWithDelegate:
        (id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate>)adapterDelegate {
  if ([UnityAds isInitialized]) {
    NSString *placementID = [adapterDelegate getPlacementID];
    if ([UnityAds isReady:placementID]) {
      [adapterDelegate unityAdsReady:placementID];
    } else {
      NSString *description =
          [[NSString alloc] initWithFormat:@"%@ failed to receive reward based video ad.",
                                           NSStringFromClass([UnityAds class])];
      [adapterDelegate unityAdsDidError:kUnityAdsErrorShowError withMessage:description];
    }
  }
}

- (void)presentRewardBasedVideoAdForViewController:(UIViewController *)viewController
                                          delegate:
                                        (id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate>)
                                            adapterDelegate {
  _currentShowingUnityDelegate = adapterDelegate;
  // The Unity Ads show method checks whether an ad is available.
  [UnityAds show:viewController placementId:[adapterDelegate getPlacementID]];
}

#pragma mark - Interstitial ad methods

- (void)configureInterstitialAdWithGameID:(NSString *)gameID
                                 delegate:
                                        (id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate>)
                                            adapterDelegate {
  if ([UnityAds isSupported]) {
    if ([UnityAds isInitialized]) {
      NSString *placementID = [adapterDelegate getPlacementID];
      if ([UnityAds isReady:placementID]) {
        [adapterDelegate unityAdsReady:placementID];
      } else {
        NSString *description =
            [[NSString alloc] initWithFormat:@"%@ failed to receive interstitial ad.",
                                             NSStringFromClass([UnityAds class])];
        [adapterDelegate unityAdsDidError:kUnityAdsErrorShowError withMessage:description];
      }
    } else {
      // Add delegate reference in adapterDelegate list only if Unity Ads is not initialized.
      [self addAdapterDelegate:adapterDelegate];
      [self initializeWithGameID:gameID];
    }
  } else {
    NSString *description =
        [[NSString alloc] initWithFormat:@"%@ is not supported for this device.",
                                         NSStringFromClass([UnityAds class])];
    [adapterDelegate unityAdsDidError:kUnityAdsErrorNotInitialized withMessage:description];
  }
}

- (void)presentInterstitialAdForViewController:(UIViewController *)viewController
                                      delegate:
                                        (id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate>)
                                            adapterDelegate {
  _currentShowingUnityDelegate = adapterDelegate;
  // The Unity Ads show method checks whether an ad is available.
  [UnityAds show:viewController placementId:[adapterDelegate getPlacementID]];
}

#pragma mark - Banner ad methods

- (void)presentBannerAd:(NSString *)gameID
                                 delegate:
(id<GADMAdapterUnityDataProvider, UnityAdsBannerDelegate>) adapterDelegate {
    _currentBannerDelegate = adapterDelegate;
    
    if ([UnityAds isSupported]) {
        NSString *placementID = [_currentBannerDelegate getPlacementID];
        if(placementID == nil){
            NSString *description =
            [[NSString alloc] initWithFormat:@"Tried to show banners with a nil placement ID"];
            [_currentBannerDelegate unityAdsBannerDidError:description];
            return;
        }else{
            _bannerPlacementID = placementID;
        }
        
        if (![UnityAds isInitialized]) {
            [self initializeWithGameID:gameID];
            _bannerRequested = true;
        }else{
            [UnityAdsBanner setDelegate:self];
            [UnityAdsBanner loadBanner:_bannerPlacementID];
        }
    } else {
        NSString *description =
        [[NSString alloc] initWithFormat:@"Unity Ads is not supported for this device."];
        [_currentBannerDelegate unityAdsBannerDidError:description];
    }
}

#pragma mark - Unity Banner Delegate Methods

-(void)unityAdsBannerDidLoad:(NSString *)placementId view:(UIView *)view {
    [_currentBannerDelegate unityAdsBannerDidLoad:_bannerPlacementID view:view];
}

-(void)unityAdsBannerDidUnload:(NSString *)placementId {
    [_currentBannerDelegate unityAdsBannerDidUnload:_bannerPlacementID];
}

-(void)unityAdsBannerDidShow:(NSString *)placementId {
    [_currentBannerDelegate unityAdsBannerDidShow:_bannerPlacementID];
}

-(void)unityAdsBannerDidHide:(NSString *)placementId {
    [_currentBannerDelegate unityAdsBannerDidHide:_bannerPlacementID];
}

-(void)unityAdsBannerDidClick:(NSString *)placementId {
    [_currentBannerDelegate unityAdsBannerDidClick:_bannerPlacementID];
}

-(void)unityAdsBannerDidError:(NSString *)message {
    NSString *description = [[NSString alloc] initWithFormat:@"Internal Unity Ads banner error"];
    [_currentBannerDelegate unityAdsBannerDidError:description];
}

#pragma mark - Unity Delegate Methods

- (void)unityAdsPlacementStateChanged:(NSString *)placementId
                             oldState:(UnityAdsPlacementState)oldState
                             newState:(UnityAdsPlacementState)newState {
  // The unityAdsReady: and unityAdsDidError: callback methods are used to forward Unity Ads SDK
  // states to the adapters. No need to forward this callback to the adapters.
}

- (void)unityAdsDidFinish:(NSString *)placementID withFinishState:(UnityAdsFinishState)state {
  [_currentShowingUnityDelegate unityAdsDidFinish:placementID withFinishState:state];
}

- (void)unityAdsDidStart:(NSString *)placementID {
  [_currentShowingUnityDelegate unityAdsDidStart:placementID];
}

- (void)unityAdsReady:(NSString *)placementID {
  NSMutableArray *delegatesToRemove = [NSMutableArray array];
  [_adapterDelegates
      enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        GADMAdapterUnityWeakReference *weakReference = obj;
        if ([[(id<GADMAdapterUnityDataProvider>)weakReference.weakObject getPlacementID]
                isEqualToString:placementID]) {
          [(id<UnityAdsExtendedDelegate>)weakReference.weakObject unityAdsReady:placementID];
          [delegatesToRemove addObject:obj];
        }
      }];
  [_adapterDelegates removeObjectsInArray:delegatesToRemove];
}

- (void)unityAdsDidClick:(NSString *)placementID {
  [_currentShowingUnityDelegate unityAdsDidClick:placementID];
}

- (void)unityAdsDidError:(UnityAdsError)error withMessage:(NSString *)message {
  // If the error is of type show, we will not have it's delegate reference in our adapterDelegate
  // list. Delegate instances are being removed when we get unityAdsReady callback.
  if (error == kUnityAdsErrorShowError) {
    [_currentShowingUnityDelegate unityAdsDidError:error withMessage:message];
    return;
  }
  NSMutableArray *delegatesToRemove = [NSMutableArray array];
  [_adapterDelegates
      enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        GADMAdapterUnityWeakReference *weakReference = obj;
        [(id<UnityAdsExtendedDelegate>)weakReference.weakObject unityAdsDidError:error
                                                                     withMessage:message];
        [delegatesToRemove addObject:obj];
      }];
  [_adapterDelegates removeObjectsInArray:delegatesToRemove];
}

- (void)stopTrackingDelegate:(id<GADMAdapterUnityDataProvider, UnityAdsExtendedDelegate>)
                                 adapterDelegate {
  GADMAdapterUnityWeakReference *delegateReference =
      [[GADMAdapterUnityWeakReference alloc] initWithObject:adapterDelegate];
  [self removeAdapterDelegate:delegateReference];
}

@end
