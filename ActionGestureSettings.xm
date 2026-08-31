#import <UIKit/UIKit.h>
#import "ActionGestureHelper.h"

%group ActionGestureOfficialSettings
%hook NSUserDefaults
- (void)setObject:(id)value forKey:(NSString *)key { %orig; [[ActionGestureHelper sharedHelper] systemActionPreferenceDidChangeForKey:key]; }
- (void)removeObjectForKey:(NSString *)key { %orig; [[ActionGestureHelper sharedHelper] systemActionPreferenceDidChangeForKey:key]; }
%end

%hook ActionButtonSettings
%new
- (void)ag_systemActionChanged:(__unused NSNotification *)notification { [self ag_installSelectors]; }
%new
- (UIButton *)ag_selectorButtonWithTitle:(NSString *)title menu:(UIMenu *)menu accessibilityLabel:(NSString *)label {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *c = [UIButtonConfiguration tintedButtonConfiguration];
    c.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold], NSForegroundColorAttributeName:[UIColor colorWithWhite:1 alpha:.94]}];
    c.image = [UIImage systemImageNamed:@"chevron.up.chevron.down"]; c.imagePlacement = NSDirectionalRectEdgeTrailing; c.imagePadding = 4; c.contentInsets = NSDirectionalEdgeInsetsMake(4.5, 8, 4.5, 7); c.cornerStyle = UIButtonConfigurationCornerStyleCapsule; c.buttonSize = UIButtonConfigurationSizeSmall; c.baseForegroundColor = [UIColor colorWithWhite:1 alpha:.78]; c.baseBackgroundColor = [UIColor colorWithWhite:1 alpha:.10];
    button.configuration = c; button.menu = menu; button.showsMenuAsPrimaryAction = YES; button.accessibilityLabel = label; return button;
}

%new
- (void)ag_installSelectors {
    ActionGestureHelper *h = [ActionGestureHelper sharedHelper];
    NSString *gestureTitle = [h titleForGesture:h.currentGesture];
    NSString *quickTitle = [h titleForQuickAction:[h quickActionForGesture:h.currentGesture]];
    UIButton *gesture = [self ag_selectorButtonWithTitle:gestureTitle menu:[self ag_gestureMenu] accessibilityLabel:gestureTitle];
    UIButton *quick = [self ag_selectorButtonWithTitle:quickTitle menu:[self ag_quickActionMenu] accessibilityLabel:quickTitle];
    BOOL systemAction = [h currentNativeConfigurationHasSystemAction];
    quick.enabled = !systemAction;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ gesture, quick ]]; stack.axis = UILayoutConstraintAxisHorizontal; stack.alignment = UIStackViewAlignmentCenter; stack.spacing = 5;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:stack];
}

%new
- (UIMenu *)ag_gestureMenu {
    ActionGestureHelper *h = [ActionGestureHelper sharedHelper]; NSMutableArray *items = [NSMutableArray array]; __weak typeof(self) w = self;
    for (NSString *g in @[ AGGestureSingle, AGGestureDouble, AGGestureLong ]) { UIAction *a = [UIAction actionWithTitle:[h titleForGesture:g] image:[UIImage systemImageNamed:[h symbolForGesture:g]] identifier:nil handler:^(__unused UIAction *x){ [w ag_switchToGesture:g]; }]; a.state = [g isEqualToString:h.currentGesture] ? UIMenuElementStateOn : UIMenuElementStateOff; [items addObject:a]; }
    return [UIMenu menuWithTitle:[h localizedStringForKey:@"menu.title"] image:nil identifier:nil options:UIMenuOptionsSingleSelection children:items];
}

%new
- (UIMenu *)ag_quickActionMenu {
    ActionGestureHelper *h = [ActionGestureHelper sharedHelper]; __weak typeof(self) w = self; NSMutableArray *items = [NSMutableArray array]; BOOL disabled = [h currentNativeConfigurationHasSystemAction];
    for (NSString *action in [h quickActions]) { UIAction *a = [UIAction actionWithTitle:[h titleForQuickAction:action] image:nil identifier:nil handler:^(__unused UIAction *x){ [w ag_selectQuickAction:action]; }]; a.state = [action isEqualToString:[h quickActionForGesture:h.currentGesture]] ? UIMenuElementStateOn : UIMenuElementStateOff; if (disabled) a.attributes = UIMenuElementAttributesDisabled; [items addObject:a]; }
    return [UIMenu menuWithTitle:[h localizedStringForKey:@"quickAction.menu"] image:nil identifier:nil options:UIMenuOptionsSingleSelection children:items];
}

%new
- (void)ag_selectQuickAction:(NSString *)action { ActionGestureHelper *h = [ActionGestureHelper sharedHelper]; if (![h currentNativeConfigurationHasSystemAction]) { [h saveQuickAction:action forGesture:h.currentGesture]; [self ag_installSelectors]; } }

%new
- (void)ag_switchToGesture:(NSString *)gesture { ActionGestureHelper *h = [ActionGestureHelper sharedHelper]; if (![h isKnownGesture:gesture] || [gesture isEqualToString:h.currentGesture]) return; if ([h hasStoredConfigurationForGesture:h.currentGesture]) [h snapshotNativeConfigurationForGesture:h.currentGesture]; [h saveCurrentGesture:gesture]; [h applyNativeConfigurationForGesture:gesture]; [self ag_replaceController]; }

%new
- (void)ag_replaceController { UINavigationController *nav = self.navigationController; NSUInteger i = [nav.viewControllers indexOfObjectIdenticalTo:self]; if (!nav || i == NSNotFound) return; ActionButtonSettings *replacement = [[[self class] alloc] initWithNibName:nil bundle:[ActionGestureHelper sharedHelper].settingsBundle]; replacement.title = self.title; NSMutableArray *controllers = [nav.viewControllers mutableCopy]; controllers[i] = replacement; [nav setViewControllers:controllers animated:NO]; }

- (void)viewDidLoad { ActionGestureHelper *h = [ActionGestureHelper sharedHelper]; [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ag_systemActionChanged:) name:@"AGSystemActionChanged" object:nil]; [h beginSuppressingSystemActionSnapshots]; [h applyNativeConfigurationForGesture:h.currentGesture]; %orig; [h endSuppressingSystemActionSnapshots]; if (![h hasStoredConfigurationForGesture:h.currentGesture]) [h snapshotNativeConfigurationForGesture:h.currentGesture]; [self ag_installSelectors]; }
- (void)viewWillAppear:(BOOL)animated { %orig; [self ag_installSelectors]; }
- (void)viewWillDisappear:(BOOL)animated { %orig; [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AGSystemActionChanged" object:nil]; ActionGestureHelper *h = [ActionGestureHelper sharedHelper]; if ([h hasStoredConfigurationForGesture:h.currentGesture]) [h snapshotNativeConfigurationForGesture:h.currentGesture]; }
%end
%end

%ctor { @autoreleasepool { if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return; ActionGestureHelper *h = [ActionGestureHelper sharedHelper]; [h loadEditorState]; if (!h.settingsBundle.loaded) [h.settingsBundle loadAndReturnError:nil]; if (!NSClassFromString(@"ActionButtonSettings")) return; %init(ActionGestureOfficialSettings); } }
