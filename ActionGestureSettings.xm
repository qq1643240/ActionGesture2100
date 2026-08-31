#import <UIKit/UIKit.h>

#import "ActionGestureHelper.h"

%group ActionGestureOfficialSettings

%hook NSUserDefaults

- (void)setObject:(id)value forKey:(NSString *)key {
    %orig;
    [[ActionGestureHelper sharedHelper]
        systemActionPreferenceDidChangeForKey:key];
}

- (void)removeObjectForKey:(NSString *)key {
    %orig;
    [[ActionGestureHelper sharedHelper]
        systemActionPreferenceDidChangeForKey:key];
}

%end

%hook ActionButtonSettings

%new
- (void)ag_systemActionChanged:(NSNotification *)notification {
    (void)notification;
    [self ag_installSelectors];
}

%new
- (UIButton *)ag_selectorButtonWithTitle:(NSString *)title
                                    menu:(UIMenu *)menu
                      accessibilityLabel:(NSString *)label {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration =
        [UIButtonConfiguration tintedButtonConfiguration];
    configuration.attributedTitle =
        [[NSAttributedString alloc]
            initWithString:title
                attributes:@{
                    NSFontAttributeName:
                        [UIFont systemFontOfSize:12.5
                                           weight:UIFontWeightSemibold],
                    NSForegroundColorAttributeName:
                        [UIColor colorWithWhite:1.0 alpha:0.94]
                }];
    configuration.image =
        [UIImage systemImageNamed:@"chevron.up.chevron.down"];
    configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
    configuration.imagePadding = 4.0;
    configuration.contentInsets =
        NSDirectionalEdgeInsetsMake(4.5, 8.0, 4.5, 7.0);
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.buttonSize = UIButtonConfigurationSizeSmall;
    configuration.baseForegroundColor =
        [UIColor colorWithWhite:1.0 alpha:0.78];
    configuration.baseBackgroundColor =
        [UIColor colorWithWhite:1.0 alpha:0.10];
    button.configuration = configuration;
    button.menu = menu;
    button.showsMenuAsPrimaryAction = YES;
    button.accessibilityLabel = label;
    return button;
}

%new
- (void)ag_installSelectors {
    ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
    NSString *gestureTitle =
        [helper titleForGesture:helper.currentGesture];
    NSString *quickTitle =
        [helper titleForQuickAction:
                  [helper quickActionForGesture:helper.currentGesture]];
    UIButton *gestureButton =
        [self ag_selectorButtonWithTitle:gestureTitle
                                    menu:[self ag_gestureMenu]
                      accessibilityLabel:gestureTitle];
    UIButton *quickButton =
        [self ag_selectorButtonWithTitle:quickTitle
                                    menu:[self ag_quickActionMenu]
                      accessibilityLabel:quickTitle];
    quickButton.enabled =
        ![helper currentNativeConfigurationHasSystemAction];

    UIStackView *selectors =
        [[UIStackView alloc]
            initWithArrangedSubviews:@[ gestureButton, quickButton ]];
    selectors.axis = UILayoutConstraintAxisHorizontal;
    selectors.alignment = UIStackViewAlignmentCenter;
    selectors.spacing = 5.0;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:selectors];
}

%new
- (UIMenu *)ag_gestureMenu {
    ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    __weak ActionButtonSettings *weakSelf = self;
    for (NSString *gesture in
            @[ AGGestureSingle, AGGestureDouble, AGGestureLong ]) {
        UIAction *action =
            [UIAction
                actionWithTitle:[helper titleForGesture:gesture]
                          image:[UIImage systemImageNamed:
                                    [helper symbolForGesture:gesture]]
                     identifier:nil
                        handler:^(UIAction *selectedAction) {
                            (void)selectedAction;
                            [weakSelf ag_switchToGesture:gesture];
                        }];
        action.state = [gesture isEqualToString:helper.currentGesture]
            ? UIMenuElementStateOn
            : UIMenuElementStateOff;
        [actions addObject:action];
    }
    return [UIMenu
        menuWithTitle:[helper localizedStringForKey:@"menu.title"]
                image:nil
           identifier:nil
              options:UIMenuOptionsSingleSelection
             children:actions];
}

%new
- (UIMenu *)ag_quickActionMenu {
    ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    __weak ActionButtonSettings *weakSelf = self;
    BOOL disabled = [helper currentNativeConfigurationHasSystemAction];
    NSString *currentAction =
        [helper quickActionForGesture:helper.currentGesture];
    for (NSString *quickAction in [helper quickActions]) {
        UIAction *action =
            [UIAction
                actionWithTitle:[helper titleForQuickAction:quickAction]
                          image:nil
                     identifier:nil
                        handler:^(UIAction *selectedAction) {
                            (void)selectedAction;
                            [weakSelf ag_selectQuickAction:quickAction];
                        }];
        action.state = [quickAction isEqualToString:currentAction]
            ? UIMenuElementStateOn
            : UIMenuElementStateOff;
        if (disabled) {
            action.attributes = UIMenuElementAttributesDisabled;
        }
        [actions addObject:action];
    }
    return [UIMenu
        menuWithTitle:[helper localizedStringForKey:@"quickAction.menu"]
                image:nil
           identifier:nil
              options:UIMenuOptionsSingleSelection
             children:actions];
}

%new
- (void)ag_selectQuickAction:(NSString *)action {
    ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
    if ([helper currentNativeConfigurationHasSystemAction]) return;
    [helper saveQuickAction:action forGesture:helper.currentGesture];
    [self ag_installSelectors];
}

%new
- (void)ag_switchToGesture:(NSString *)gesture {
    ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
    if (![helper isKnownGesture:gesture] ||
        [gesture isEqualToString:helper.currentGesture]) {
        return;
    }
    if ([helper hasStoredConfigurationForGesture:helper.currentGesture]) {
        [helper snapshotNativeConfigurationForGesture:helper.currentGesture];
    }
    [helper saveCurrentGesture:gesture];
    [helper applyNativeConfigurationForGesture:gesture];
    [self ag_replaceController];
}

%new
- (void)ag_replaceController {
    UINavigationController *navigationController = self.navigationController;
    NSUInteger index =
        [navigationController.viewControllers indexOfObjectIdenticalTo:self];
    if (!navigationController || index == NSNotFound) return;
    ActionButtonSettings *replacement =
        [[[self class] alloc]
            initWithNibName:nil
                     bundle:[ActionGestureHelper sharedHelper].settingsBundle];
    replacement.title = self.title;
    NSMutableArray<UIViewController *> *controllers =
        [navigationController.viewControllers mutableCopy];
    controllers[index] = replacement;
    [navigationController setViewControllers:controllers animated:NO];
}

- (void)viewDidLoad {
    ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(ag_systemActionChanged:)
               name:@"AGSystemActionChanged"
             object:nil];
    [helper beginSuppressingSystemActionSnapshots];
    [helper applyNativeConfigurationForGesture:helper.currentGesture];
    %orig;
    [helper endSuppressingSystemActionSnapshots];
    if (![helper hasStoredConfigurationForGesture:helper.currentGesture]) {
        [helper snapshotNativeConfigurationForGesture:helper.currentGesture];
    }
    [self ag_installSelectors];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self ag_installSelectors];
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:@"AGSystemActionChanged"
                object:nil];
    ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
    if ([helper hasStoredConfigurationForGesture:helper.currentGesture]) {
        [helper snapshotNativeConfigurationForGesture:helper.currentGesture];
    }
}

%end
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier
                isEqualToString:@"com.apple.Preferences"]) {
            return;
        }
        ActionGestureHelper *helper = [ActionGestureHelper sharedHelper];
        [helper loadEditorState];
        if (!helper.settingsBundle.loaded) {
            [helper.settingsBundle loadAndReturnError:nil];
        }
        if (!NSClassFromString(@"ActionButtonSettings")) return;
        %init(ActionGestureOfficialSettings);
    }
}
