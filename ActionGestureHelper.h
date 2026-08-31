#import <Foundation/Foundation.h>

#import "ActionGestureHeaders.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const AGGestureSingle;
FOUNDATION_EXPORT NSString *const AGGestureDouble;
FOUNDATION_EXPORT NSString *const AGGestureLong;

FOUNDATION_EXPORT NSString *const AGQuickActionNone;
FOUNDATION_EXPORT NSString *const AGQuickActionWeChatScan;
FOUNDATION_EXPORT NSString *const AGQuickActionWeChatPay;
FOUNDATION_EXPORT NSString *const AGQuickActionAlipayScan;
FOUNDATION_EXPORT NSString *const AGQuickActionAlipayPay;

@interface ActionGestureHelper : NSObject

@property (nonatomic, copy) NSString *currentGesture;
@property (nonatomic, readonly) NSBundle *settingsBundle;

+ (instancetype)sharedHelper;

- (void)loadEditorState;
- (BOOL)isKnownGesture:(NSString *)gesture;
- (NSArray<NSString *> *)quickActions;
- (BOOL)isKnownQuickAction:(NSString *)action;
- (NSString *)quickActionForGesture:(NSString *)gesture;
- (void)saveQuickAction:(NSString *)action forGesture:(NSString *)gesture;
- (NSString *)titleForQuickAction:(NSString *)action;
- (BOOL)hasStoredConfigurationForGesture:(NSString *)gesture;
- (BOOL)currentNativeConfigurationHasSystemAction;
- (void)snapshotNativeConfigurationForGesture:(NSString *)gesture;
- (BOOL)applyNativeConfigurationForGesture:(NSString *)gesture;
- (void)saveCurrentGesture:(NSString *)gesture;
- (void)beginSuppressingSystemActionSnapshots;
- (void)endSuppressingSystemActionSnapshots;
- (void)systemActionPreferenceDidChangeForKey:(NSString *)key;

- (NSString *)localizedStringForKey:(NSString *)key;
- (NSString *)titleForGesture:(NSString *)gesture;
- (NSString *)symbolForGesture:(NSString *)gesture;

- (BOOL)prepareSpringBoardRuntime;
- (BOOL)canHandleButton:(SBRingerHardwareButton *)button;
- (BOOL)executeGesture:(NSString *)gesture
              onButton:(SBRingerHardwareButton *)button
                 event:(id<AGHardwareButtonEvent>)event;
- (BOOL)replayNativeActionOnButton:(SBRingerHardwareButton *)button
                              event:(id<AGHardwareButtonEvent>)event;
- (void)replayNativeTapOnButton:(SBRingerHardwareButton *)button
                      downEvent:(id<AGHardwareButtonEvent>)downEvent
                        upEvent:(id<AGHardwareButtonEvent>)upEvent;

@end

NS_ASSUME_NONNULL_END
