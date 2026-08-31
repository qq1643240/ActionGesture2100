#import "ActionGestureHelper.h"
#import <objc/runtime.h>
#if __has_include(<roothide.h>)
#import <roothide.h>
#else
static inline const char *jbroot(const char *path) { return path; }
#endif

NSString *const AGGestureSingle = @"single";
NSString *const AGGestureDouble = @"double";
NSString *const AGGestureLong = @"long";
NSString *const AGQuickActionNone = @"none";
NSString *const AGQuickActionWeChatScan = @"wechat.scan";
NSString *const AGQuickActionWeChatPay = @"wechat.pay";
NSString *const AGQuickActionAlipayScan = @"alipay.scan";
NSString *const AGQuickActionAlipayPay = @"alipay.pay";

@interface AGGestureConfiguration : NSObject
@property (nonatomic) BOOL hasSection;
@property (nonatomic) BOOL hasArchive;
@property (nonatomic, copy) NSString *sectionIdentifier;
@property (nonatomic, copy) NSData *configuredActionArchive;
@end
@implementation AGGestureConfiguration
@end

typedef void (*AGButtonEventIMP)(SBRingerHardwareButton *, SEL, id<AGHardwareButtonEvent>);

@interface ActionGestureHelper ()
@property (nonatomic, readwrite) NSBundle *settingsBundle;
@property (nonatomic) AGButtonEventIMP originalButtonDown;
@property (nonatomic) AGButtonEventIMP originalButtonLongPress;
@property (nonatomic) AGButtonEventIMP originalButtonUp;
@property (nonatomic) NSMutableDictionary<NSString *, NSDictionary *> *systemActionCache;
@property (nonatomic) BOOL snapshotScheduled;
@property (nonatomic, copy) NSString *pendingSnapshotGesture;
@property (nonatomic) BOOL suppressSystemActionSnapshots;
@end

@implementation ActionGestureHelper
+ (instancetype)sharedHelper { static ActionGestureHelper *h; static dispatch_once_t t; dispatch_once(&t, ^{ h = [self new]; }); return h; }
- (instancetype)init { if ((self = [super init])) { _currentGesture = AGGestureSingle; _systemActionCache = [NSMutableDictionary dictionary]; _settingsBundle = [NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/ActionButtonSettings.bundle"]; } return self; }
- (id)preferenceValueForKey:(NSString *)key { return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.huami.actiongesture"))); }
- (void)setPreferenceValue:(id)value forKey:(NSString *)key { CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, CFSTR("com.huami.actiongesture")); }
- (NSUserDefaults *)springBoardDefaults { return [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.springboard"]; }
- (BOOL)isKnownGesture:(NSString *)gesture { return [@[ AGGestureSingle, AGGestureDouble, AGGestureLong ] containsObject:gesture]; }
- (NSArray<NSString *> *)quickActions { return @[ AGQuickActionNone, AGQuickActionWeChatScan, AGQuickActionWeChatPay, AGQuickActionAlipayScan, AGQuickActionAlipayPay ]; }
- (BOOL)isKnownQuickAction:(NSString *)action { return [[self quickActions] containsObject:action]; }
- (void)loadEditorState { CFPreferencesAppSynchronize(CFSTR("com.huami.actiongesture")); NSString *g = [self preferenceValueForKey:@"editorGesture"]; self.currentGesture = [self isKnownGesture:g] ? g : AGGestureSingle; }
- (void)saveCurrentGesture:(NSString *)gesture { if (![self isKnownGesture:gesture]) return; self.currentGesture = gesture; [self setPreferenceValue:gesture forKey:@"editorGesture"]; CFPreferencesAppSynchronize(CFSTR("com.huami.actiongesture")); }
- (NSString *)quickActionForGesture:(NSString *)gesture { NSString *a = [self preferenceValueForKey:[NSString stringWithFormat:@"quickAction.%@", gesture]]; return [self isKnownQuickAction:a] ? a : AGQuickActionNone; }
- (void)saveQuickAction:(NSString *)action forGesture:(NSString *)gesture { if (![self isKnownQuickAction:action] || ![self isKnownGesture:gesture]) return; [self setPreferenceValue:action forKey:[NSString stringWithFormat:@"quickAction.%@", gesture]]; CFPreferencesAppSynchronize(CFSTR("com.huami.actiongesture")); }
- (NSString *)titleForQuickAction:(NSString *)action { NSDictionary *keys = @{ AGQuickActionNone:@"quickAction.close", AGQuickActionWeChatScan:@"quickAction.wechatScan", AGQuickActionWeChatPay:@"quickAction.wechatPay", AGQuickActionAlipayScan:@"quickAction.alipayScan", AGQuickActionAlipayPay:@"quickAction.alipayPay" }; return [self localizedStringForKey:keys[action] ?: @"quickAction.close"]; }
- (NSString *)storageKeyForGesture:(NSString *)gesture suffix:(NSString *)suffix { return [NSString stringWithFormat:@"native.%@.%@", gesture, suffix]; }
- (AGGestureConfiguration *)configurationForGesture:(NSString *)gesture synchronize:(BOOL)sync { if (![self isKnownGesture:gesture]) return nil; if (sync) CFPreferencesAppSynchronize(CFSTR("com.huami.actiongesture")); if (![[self preferenceValueForKey:[self storageKeyForGesture:gesture suffix:@"initialized"]] boolValue]) return nil; AGGestureConfiguration *c = [AGGestureConfiguration new]; c.hasSection = [[self preferenceValueForKey:[self storageKeyForGesture:gesture suffix:@"hasSection"]] boolValue]; c.hasArchive = [[self preferenceValueForKey:[self storageKeyForGesture:gesture suffix:@"hasArchive"]] boolValue]; id s = [self preferenceValueForKey:[self storageKeyForGesture:gesture suffix:@"section"]]; id a = [self preferenceValueForKey:[self storageKeyForGesture:gesture suffix:@"archive"]]; if ([s isKindOfClass:NSString.class]) c.sectionIdentifier = s; if ([a isKindOfClass:NSData.class]) c.configuredActionArchive = a; return c; }
- (BOOL)hasStoredConfigurationForGesture:(NSString *)gesture { return [self configurationForGesture:gesture synchronize:YES] != nil; }
- (AGGestureConfiguration *)currentNativeConfiguration { NSUserDefaults *d = [self springBoardDefaults]; NSString *s = [d objectForKey:@"SBSystemActionSelectedSectionIdentifier"]; NSData *a = [d objectForKey:@"SBSystemActionConfiguredActionArchive"]; AGGestureConfiguration *c = [AGGestureConfiguration new]; c.hasSection = [s isKindOfClass:NSString.class]; c.hasArchive = [a isKindOfClass:NSData.class]; c.sectionIdentifier = c.hasSection ? s : nil; c.configuredActionArchive = c.hasArchive ? a : nil; return c; }
- (BOOL)currentNativeConfigurationHasSystemAction { AGGestureConfiguration *c = [self currentNativeConfiguration]; return c.hasArchive; }
- (void)storeConfiguration:(AGGestureConfiguration *)c forGesture:(NSString *)g synchronize:(BOOL)sync { if (!c || ![self isKnownGesture:g]) return; [self setPreferenceValue:@YES forKey:[self storageKeyForGesture:g suffix:@"initialized"]]; [self setPreferenceValue:@(c.hasSection) forKey:[self storageKeyForGesture:g suffix:@"hasSection"]]; [self setPreferenceValue:@(c.hasArchive) forKey:[self storageKeyForGesture:g suffix:@"hasArchive"]]; [self setPreferenceValue:c.hasSection ? c.sectionIdentifier : nil forKey:[self storageKeyForGesture:g suffix:@"section"]]; [self setPreferenceValue:c.hasArchive ? c.configuredActionArchive : nil forKey:[self storageKeyForGesture:g suffix:@"archive"]]; if (sync) CFPreferencesAppSynchronize(CFSTR("com.huami.actiongesture")); }
- (void)snapshotNativeConfigurationForGesture:(NSString *)gesture { [self storeConfiguration:[self currentNativeConfiguration] forGesture:gesture synchronize:YES]; }
- (BOOL)applyNativeConfigurationForGesture:(NSString *)gesture { AGGestureConfiguration *c = [self configurationForGesture:gesture synchronize:YES]; if (!c) return NO; NSUserDefaults *d = [self springBoardDefaults]; BOOL old = self.suppressSystemActionSnapshots; self.suppressSystemActionSnapshots = YES; @try { if (c.hasSection && c.sectionIdentifier) [d setObject:c.sectionIdentifier forKey:@"SBSystemActionSelectedSectionIdentifier"]; else [d removeObjectForKey:@"SBSystemActionSelectedSectionIdentifier"]; if (c.hasArchive && c.configuredActionArchive) [d setObject:c.configuredActionArchive forKey:@"SBSystemActionConfiguredActionArchive"]; else [d removeObjectForKey:@"SBSystemActionConfiguredActionArchive"]; [d synchronize]; } @finally { self.suppressSystemActionSnapshots = old; } return YES; }
- (void)beginSuppressingSystemActionSnapshots { self.suppressSystemActionSnapshots = YES; }
- (void)endSuppressingSystemActionSnapshots { self.suppressSystemActionSnapshots = NO; }
- (void)systemActionPreferenceDidChangeForKey:(NSString *)key { if (self.suppressSystemActionSnapshots || (![key isEqualToString:@"SBSystemActionSelectedSectionIdentifier"] && ![key isEqualToString:@"SBSystemActionConfiguredActionArchive"])) return; NSString *g = self.currentGesture; dispatch_block_t b = ^{ self.pendingSnapshotGesture = g; if (self.snapshotScheduled) return; self.snapshotScheduled = YES; dispatch_async(dispatch_get_main_queue(), ^{ NSString *p = self.pendingSnapshotGesture; self.pendingSnapshotGesture = nil; self.snapshotScheduled = NO; [self snapshotNativeConfigurationForGesture:p]; [[NSNotificationCenter defaultCenter] postNotificationName:@"AGSystemActionChanged" object:nil]; }); }; if (NSThread.isMainThread) b(); else dispatch_async(dispatch_get_main_queue(), b); }
- (NSBundle *)localizationBundle { static NSBundle *b; static dispatch_once_t t; dispatch_once(&t, ^{ b = [NSBundle bundleWithPath:jbroot(@"/Library/Application Support/ActionGesture.bundle")]; }); return b; }
- (NSString *)localizedStringForKey:(NSString *)key { return [[self localizationBundle] localizedStringForKey:key value:key table:nil]; }
- (NSString *)titleForGesture:(NSString *)g { return [self localizedStringForKey:[g isEqualToString:AGGestureDouble] ? @"gesture.double" : ([g isEqualToString:AGGestureLong] ? @"gesture.long" : @"gesture.single")]; }
- (NSString *)symbolForGesture:(NSString *)g { return [g isEqualToString:AGGestureDouble] ? @"hand.tap.fill" : ([g isEqualToString:AGGestureLong] ? @"hand.point.up.left.fill" : @"hand.tap"); }
- (BOOL)prepareSpringBoardRuntime { Class c = objc_getClass("SBRingerHardwareButton"); Method d = class_getInstanceMethod(c, @selector(performActionsForButtonDown:)); Method l = class_getInstanceMethod(c, @selector(performActionsForButtonLongPress:)); Method u = class_getInstanceMethod(c, @selector(performActionsForButtonUp:)); if (!c || !objc_getClass("SBSystemActionControl") || !objc_getClass("SBLinkSystemAction") || !d || !l || !u || !class_getInstanceVariable(c, "_systemActionControl") || !class_getInstanceVariable(objc_getClass("SBSystemActionControl"), "_dataSource") || !class_getInstanceMethod(objc_getClass("SBLinkSystemAction"), @selector(initWithConfiguredAction:))) return NO; self.originalButtonDown = (AGButtonEventIMP)method_getImplementation(d); self.originalButtonLongPress = (AGButtonEventIMP)method_getImplementation(l); self.originalButtonUp = (AGButtonEventIMP)method_getImplementation(u); return self.originalButtonDown && self.originalButtonLongPress && self.originalButtonUp; }
- (SBSystemActionAbstractDataSource *)dataSourceForButton:(SBRingerHardwareButton *)button { Ivar ci = class_getInstanceVariable(object_getClass(button), "_systemActionControl"); if (!ci) return nil; id control = object_getIvar(button, ci); Ivar di = class_getInstanceVariable(object_getClass(control), "_dataSource"); if (!di) return nil; SBSystemActionAbstractDataSource *data = object_getIvar(control, di); for (NSUInteger i = 0; data && i < 4; i++) { Ivar inner = class_getInstanceVariable(object_getClass(data), "_innerDataSource"); if (!inner) break; data = object_getIvar(data, inner); } return data; }
- (BOOL)canHandleButton:(SBRingerHardwareButton *)button { return self.originalButtonDown && self.originalButtonLongPress && self.originalButtonUp && [[self dataSourceForButton:button] respondsToSelector:@selector(setSelectedSystemAction:)]; }
- (SBLinkSystemAction *)systemActionForAssignmentIdentifier:(NSString *)identifier configuration:(AGGestureConfiguration *)c { if (!c.hasArchive || !c.configuredActionArchive) return nil; NSDictionary *cached = self.systemActionCache[identifier]; if ([cached[@"archive"] isEqualToData:c.configuredActionArchive]) return cached[@"action"]; NSError *error = nil; WFConfiguredStaccatoAction *configured = nil; @try { configured = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:c.configuredActionArchive error:&error]; } @catch (__unused NSException *e) { return nil; } if (!configured || error) return nil; SBLinkSystemAction *a = [(SBLinkSystemAction *)[objc_getClass("SBLinkSystemAction") alloc] initWithConfiguredAction:configured]; if (!a) return nil; self.systemActionCache[identifier] = @{@"archive":c.configuredActionArchive, @"action":a}; return a; }
- (BOOL)selectConfiguration:(AGGestureConfiguration *)c identifier:(NSString *)identifier onButton:(SBRingerHardwareButton *)button { SBSystemActionAbstractDataSource *d = [self dataSourceForButton:button]; if (![d respondsToSelector:@selector(setSelectedSystemAction:)]) return NO; if (!c.hasArchive) { [d setSelectedSystemAction:nil]; return YES; } SBLinkSystemAction *a = [self systemActionForAssignmentIdentifier:identifier configuration:c]; if (!a) return NO; [d setSelectedSystemAction:a]; return YES; }
- (BOOL)reloadSelectedActionOnButton:(SBRingerHardwareButton *)button { SBSystemActionAbstractDataSource *d = [self dataSourceForButton:button]; if (![d respondsToSelector:@selector(updateSelectedAction)]) return NO; [d updateSelectedAction]; return YES; }
- (BOOL)replayNativeActionOnButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event { if (!self.originalButtonDown || !self.originalButtonLongPress || !self.originalButtonUp || !button || !event) return NO; self.originalButtonDown(button, @selector(performActionsForButtonDown:), event); self.originalButtonLongPress(button, @selector(performActionsForButtonLongPress:), event); dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ self.originalButtonUp(button, @selector(performActionsForButtonUp:), event); }); return YES; }
- (void)replayNativeTapOnButton:(SBRingerHardwareButton *)button downEvent:(id<AGHardwareButtonEvent>)downEvent upEvent:(id<AGHardwareButtonEvent>)upEvent { if (self.originalButtonDown && self.originalButtonUp && button && downEvent && upEvent) { self.originalButtonDown(button, @selector(performActionsForButtonDown:), downEvent); self.originalButtonUp(button, @selector(performActionsForButtonUp:), upEvent); } }
- (BOOL)openURLString:(NSString *)s { NSURL *url = [NSURL URLWithString:s]; if (!url) return NO; UIApplication *app = UIApplication.sharedApplication; if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) { [app openURL:url options:@{} completionHandler:nil]; return YES; } return [app openURL:url]; }
- (BOOL)executeQuickAction:(NSString *)action { NSDictionary *urls = @{ AGQuickActionWeChatScan:@"weixin://dl/scan", AGQuickActionWeChatPay:@"weixin://widget/pay", AGQuickActionAlipayScan:@"alipays://platformapi/startapp?appId=10000007", AGQuickActionAlipayPay:@"alipays://platformapi/startapp?appId=20000056" }; NSString *s = urls[action]; return s ? [self openURLString:s] : YES; }
- (BOOL)executeGesture:(NSString *)gesture onButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event { if (!button || !event || ![self isKnownGesture:gesture]) return NO; AGGestureConfiguration *c = [self configurationForGesture:gesture synchronize:YES]; if (!c) { [self snapshotNativeConfigurationForGesture:gesture]; c = [self configurationForGesture:gesture synchronize:YES]; } if (!c) return NO; if (c.hasArchive) { BOOL selected = [self selectConfiguration:c identifier:gesture onButton:button]; if (!selected) { selected = [self applyNativeConfigurationForGesture:gesture]; if (selected) { __weak typeof(self) w = self; __weak SBRingerHardwareButton *b = button; dispatch_async(dispatch_get_main_queue(), ^{ [w reloadSelectedActionOnButton:b]; }); } } return selected && [self replayNativeActionOnButton:button event:event]; } NSString *quick = [self quickActionForGesture:gesture]; if ([quick isEqualToString:AGQuickActionNone]) return YES; return [self executeQuickAction:quick]; }
@end
