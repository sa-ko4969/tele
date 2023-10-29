import Foundation
import UIKit
import Display

public extension TabBarControllerTheme {
    convenience public init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.tabBar
        self.init(backgroundColor: rootControllerTheme.list.plainBackgroundColor, tabBarBackgroundColor: theme.backgroundColor, tabBarSeparatorColor: theme.separatorColor, tabBarTextColor: theme.textColor, tabBarSelectedTextColor: theme.selectedIconColor, tabBarBadgeBackgroundColor: theme.badgeBackgroundColor, tabBarBadgeStrokeColor: theme.badgeStrokeColor, tabBarBadgeTextColor: theme.badgeTextColor)
    }
}

public extension NavigationBarTheme {
    convenience public init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.navigationBar
        self.init(buttonColor: theme.buttonColor, disabledButtonColor: theme.disabledButtonColor, primaryTextColor: theme.primaryTextColor, backgroundColor: theme.backgroundColor, separatorColor: theme.separatorColor, badgeBackgroundColor: theme.badgeBackgroundColor, badgeStrokeColor: theme.badgeStrokeColor, badgeTextColor: theme.badgeTextColor)
    }
}

public extension NavigationBarStrings {
    convenience public init(presentationStrings: PresentationStrings) {
        self.init(back: presentationStrings.Common_Back, close: presentationStrings.Common_Close)
    }
}

public extension NavigationBarPresentationData {
    convenience public init(presentationData: PresentationData) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }
}

public extension ActionSheetControllerTheme {
    convenience public init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(dimColor: actionSheet.dimColor, backgroundType: actionSheet.backgroundType == .light ? .light : .dark, itemBackgroundColor: actionSheet.itemBackgroundColor, itemHighlightedBackgroundColor: actionSheet.itemHighlightedBackgroundColor, standardActionTextColor: actionSheet.standardActionTextColor, destructiveActionTextColor: actionSheet.destructiveActionTextColor, disabledActionTextColor: actionSheet.disabledActionTextColor, primaryTextColor: actionSheet.primaryTextColor, secondaryTextColor: actionSheet.secondaryTextColor, controlAccentColor: actionSheet.controlAccentColor, controlColor: presentationTheme.list.disclosureArrowColor, switchFrameColor: presentationTheme.list.itemSwitchColors.frameColor, switchContentColor: presentationTheme.list.itemSwitchColors.contentColor, switchHandleColor: presentationTheme.list.itemSwitchColors.handleColor)
    }
}

public extension ActionSheetController {
    convenience public init(presentationTheme: PresentationTheme) {
        self.init(theme: ActionSheetControllerTheme(presentationTheme: presentationTheme))
    }
}

public extension AlertControllerTheme {
    convenience public init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(backgroundType: actionSheet.backgroundType == .light ? .light : .dark, backgroundColor: actionSheet.itemBackgroundColor, separatorColor: actionSheet.itemHighlightedBackgroundColor, highlightedItemColor: actionSheet.itemHighlightedBackgroundColor, primaryColor: actionSheet.primaryTextColor, secondaryColor: actionSheet.secondaryTextColor, accentColor: actionSheet.controlAccentColor, destructiveColor: actionSheet.destructiveActionTextColor, disabledColor: actionSheet.disabledActionTextColor)
    }
}

extension PeekControllerTheme {
    convenience public init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(isDark: actionSheet.backgroundType == .dark, menuBackgroundColor: actionSheet.opaqueItemBackgroundColor, menuItemHighligtedColor: actionSheet.opaqueItemHighlightedBackgroundColor, menuItemSeparatorColor: actionSheet.opaqueItemSeparatorColor, accentColor: actionSheet.controlAccentColor, destructiveColor: actionSheet.destructiveActionTextColor)
    }
}

public extension NavigationControllerTheme {
    convenience public init(presentationTheme: PresentationTheme) {
        self.init(navigationBar: NavigationBarTheme(rootControllerTheme: presentationTheme), emptyAreaColor: presentationTheme.chatList.backgroundColor, emptyDetailIcon: generateTintedImage(image: UIImage(named: "Chat List/EmptyMasterDetailIcon", in: Bundle(for: PresentationTheme.self), compatibleWith: nil), color: presentationTheme.chatList.messageTextColor.withAlphaComponent(0.2)))
    }
}
