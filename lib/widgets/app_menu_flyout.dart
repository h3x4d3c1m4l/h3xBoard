import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

/// A patched copy of fluent_ui 4.16.0's `MenuFlyout` / `MenuFlyoutSubItem`
/// (`lib/src/controls/flyouts/menu_flyout.dart`).
///
/// Fluent only closes a *sibling* sub-menu when another opens via a mouse
/// `onHover` handler on the parent menu. On a tap/touch interaction there is no
/// hovering pointer, so opening a second sub-menu never closes the first and
/// both stay open at once. [_AppMenuFlyoutSubItemState.show] adds a
/// sibling-close step so only the most recently opened sub-menu remains.
///
/// Only the two sub-menu lifecycle classes are vendored here; every leaf item
/// type ([MenuFlyoutItem], [ToggleMenuFlyoutItem], [RadioMenuFlyoutItem],
/// [MenuFlyoutSeparator], [MenuFlyoutItemBuilder]) is reused unchanged from
/// fluent_ui via [MenuFlyoutItemBase].

/// The default padding for the [AppMenuFlyout] content.
const _kDefaultMenuPadding = EdgeInsetsDirectional.symmetric(vertical: 2);

/// Tight gap between item highlights. The comfortable touch height comes from
/// [_kMenuTileTextPadding] *inside* the row (part of the clickable, highlighted
/// area) rather than from the item margin — fluent's `itemMargin` sits outside
/// each item's `HoverButton`, so using it for spacing leaves dead, unclickable
/// gaps between rows.
const _kMenuTileMargin = EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 1);

/// Vertical padding added around each item's label, growing the highlighted &
/// tappable row into a comfortable touch target (≈40px tall).
const _kMenuTileTextPadding = EdgeInsetsDirectional.symmetric(vertical: 7);

/// Renders a single [MenuFlyoutItem]-style row as a [FlyoutListTile] with a
/// generous, fully-clickable padding. Shared by leaf items and sub-item rows so
/// every menu row reads and behaves the same.
///
/// [useIconPlaceholder] reserves the leading-icon column for items without an
/// icon so their labels still line up with icon-bearing siblings (mirrors
/// fluent's own `_useIconPlaceholder`).
Widget _buildAppMenuTile(
  BuildContext context, {
  required Widget text,
  required VoidCallback? onPressed,
  required bool useIconPlaceholder,
  Widget? leading,
  Widget? trailing,
  VoidCallback? onLongPress,
  FocusNode? focusNode,
  bool selected = false,
  bool closeAfterClick = true,
}) {
  return FlyoutListTile(
    margin: _kMenuTileMargin,
    selected: selected,
    showSelectedIndicator: false,
    icon: leading ?? (useIconPlaceholder ? const Icon(null) : null),
    text: Padding(padding: _kMenuTileTextPadding, child: text),
    trailing: trailing == null
        ? null
        : IconTheme.merge(data: const IconThemeData(size: 12), child: trailing),
    onPressed: onPressed == null
        ? null
        : () {
            if (closeAfterClick) Navigator.of(context).maybePop();
            onPressed();
          },
    onLongPress: onLongPress,
    focusNode: focusNode,
  );
}

/// Menu flyouts are used in menu and context menu scenarios to display a list
/// of commands or options when requested by the user.
///
/// This is a drop-in replacement for fluent's `MenuFlyout` that makes sibling
/// sub-menus mutually exclusive on touch as well as on hover.
class AppMenuFlyout extends StatefulWidget {

  /// Creates a menu flyout.
  const AppMenuFlyout({
    super.key,
    this.items = const [],
    this.color,
    this.shape,
    this.shadowColor = Colors.black,
    this.elevation = 8.0,
    this.constraints,
    this.itemMargin = kDefaultMenuItemMargin,
  });

  /// {@macro fluent_ui.flyouts.menu.items}
  final List<MenuFlyoutItemBase> items;

  /// The background color of the box.
  final Color? color;

  /// The shape to fill the [color] of the box.
  final ShapeBorder? shape;

  /// The shadow color.
  final Color shadowColor;

  /// The z-coordinate relative to the box at which to place this physical
  /// object.
  final double elevation;

  /// Additional constraints to apply to the child.
  final BoxConstraints? constraints;

  /// The spacing between the items.
  final EdgeInsetsGeometry itemMargin;

  @override
  State<AppMenuFlyout> createState() => _AppMenuFlyoutState();

}

class _AppMenuFlyoutState extends State<AppMenuFlyout> {

  List<GlobalKey<State<StatefulWidget>>> keys = <GlobalKey>[];

  void generateKeys() {
    if (widget.items.whereType<AppMenuFlyoutSubItem>().isNotEmpty) {
      keys = widget.items.map((item) {
        if (item is AppMenuFlyoutSubItem) {
          return GlobalKey<_AppMenuFlyoutSubItemState>();
        }

        return GlobalKey(debugLabel: 'AppMenuFlyout key#$item');
      }).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    generateKeys();
  }

  @override
  Widget build(BuildContext context) {
    final menuInfo = MenuInfoProvider.of(context);
    final parent = Flyout.maybeOf(context);

    // Reserve the leading-icon column for icon-less items whenever any sibling
    // has an icon, so labels line up (mirrors fluent's own placeholder logic).
    final hasLeading = widget.items.whereType<MenuFlyoutItem>().any((item) => item.leading != null);

    Widget content = IntrinsicWidth(
      child: FlyoutContent(
        color: widget.color,
        constraints: widget.constraints ?? kFlyoutMinConstraints,
        elevation: widget.elevation,
        shadowColor: widget.shadowColor,
        shape: widget.shape,
        padding: _kDefaultMenuPadding,
        useAcrylic: DisableAcrylic.of(context) != null,
        child: ScrollConfiguration(
          behavior: const _MenuScrollBehavior(),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final Widget child;
                if (item is AppMenuFlyoutSubItem) {
                  if (keys.isNotEmpty) {
                    item
                      .._key = keys[index] as GlobalKey<_AppMenuFlyoutSubItemState>?
                      ..disableAcyrlic = DisableAcrylic.of(context) != null;
                  }
                  item.useIconPlaceholder = hasLeading;
                  // The sub-item builds its own (padded) tile via its state.
                  child = item.build(context);
                } else if (item is MenuFlyoutItem) {
                  // Leaf items (including Toggle/Radio) — render as a padded,
                  // fully-clickable tile instead of fluent's tight row + dead
                  // outer margin.
                  child = _buildAppMenuTile(
                    context,
                    text: item.text,
                    leading: item.leading,
                    trailing: item.trailing,
                    onPressed: item.onPressed,
                    onLongPress: item.onLongPress,
                    focusNode: item.focusNode,
                    selected: item.selected,
                    closeAfterClick: item.closeAfterClick,
                    useIconPlaceholder: hasLeading,
                  );
                } else {
                  // Separators and other bespoke item types keep the margin.
                  child = Padding(padding: widget.itemMargin, child: item.build(context));
                }
                return KeyedSubtree(key: item.key, child: child);
              }),
            ),
          ),
        ),
      ),
    );

    if (keys.isNotEmpty) {
      content = MouseRegion(
        onHover: (event) {
          for (final subItem in keys.whereType<GlobalKey<_AppMenuFlyoutSubItemState>>()) {
            final state = subItem.currentState;
            if (state == null || subItem.currentContext == null) continue;
            if (!state.isShowing(menuInfo)) continue;
            if (parent == null) continue;

            final itemBox = subItem.currentContext!.findRenderObject()! as RenderBox;
            final parentBox = parent.widget.root!.context.findRenderObject()! as RenderBox;
            final translation = parentBox.getTransformTo(null).getTranslation();
            final offset = Offset(translation[0], translation[1]);
            final itemRect =
                (itemBox.localToGlobal(Offset.zero, ancestor: parentBox) + offset) & itemBox.size;

            if (!itemRect.contains(event.position)) {
              state.close(menuInfo);
            }
          }
        },
        child: content,
      );
    }

    return content;
  }

}

// Do not use the platform-specific default scroll configuration.
// Menus should never overscroll or display an overscroll indicator.
class _MenuScrollBehavior extends FluentScrollBehavior {

  const _MenuScrollBehavior();

  @override
  TargetPlatform getPlatform(BuildContext context) => defaultTargetPlatform;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

}

/// The default trailing widget for [AppMenuFlyoutSubItem].
///
/// It shows a [WindowsIcons.chevron_right] icon in left-to-right mode and a
/// [WindowsIcons.chevron_left] icon in right-to-left mode.
class _AppMenuFlyoutSubItemChevron extends StatelessWidget {

  const _AppMenuFlyoutSubItemChevron();

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return WindowsIcon(
      isRtl ? WindowsIcons.chevron_left : WindowsIcons.chevron_right,
    );
  }

}

/// Represents a menu item that displays a sub-menu in an [AppMenuFlyout].
///
/// See fluent's `MenuFlyoutSubItem`. Unlike fluent's version, opening this
/// sub-menu closes any sibling sub-menu regardless of pointer/hover state.
class AppMenuFlyoutSubItem extends MenuFlyoutItem {

  /// Creates a menu flyout sub item
  AppMenuFlyoutSubItem({
    required super.text,
    required this.items,
    super.key,
    super.leading,
    super.trailing = const _AppMenuFlyoutSubItemChevron(),
    this.showBehavior = SubItemShowAction.hover,
    this.showHoverDelay = const Duration(milliseconds: 450),
  }) : super(onPressed: null);

  /// It is the key of `_AppMenuFlyoutSubItem`, built in the `build` method. It
  /// can not use the parent `key` widget because it's already used by
  /// `AppMenuFlyout` to build the widget. It is assigned by `AppMenuFlyout` with
  /// a key generated by `generateKeys()`. It is used to close the child menu
  /// when its parent is closed.
  GlobalKey<_AppMenuFlyoutSubItemState>? _key;

  /// The collection used to generate the content of the menu.
  final MenuItemsBuilder items;

  /// Represent which user action will show the sub-menu.
  ///
  /// Defaults to [SubItemShowAction.hover]
  final SubItemShowAction showBehavior;

  /// The sub-menu will be only shown after this delay.
  ///
  /// Only applied if [showBehavior] is [SubItemShowAction.hover]
  final Duration showHoverDelay;

  /// Whether to disable the acrylic effect for this sub-menu.
  ///
  /// This is set internally by [AppMenuFlyout].
  bool disableAcyrlic = false;

  /// Whether the parent menu reserves a leading-icon column. Set internally by
  /// [AppMenuFlyout] so an icon-less sub-item row still aligns with its siblings.
  bool useIconPlaceholder = false;

  @override
  Widget build(BuildContext context) {
    return _AppMenuFlyoutSubItem(key: _key, item: this, items: items);
  }

}

class _AppMenuFlyoutSubItem extends StatefulWidget {

  final AppMenuFlyoutSubItem item;
  final MenuItemsBuilder items;

  const _AppMenuFlyoutSubItem({
    required this.item,
    required this.items,
    super.key,
  });

  @override
  State<_AppMenuFlyoutSubItem> createState() => _AppMenuFlyoutSubItemState();

}

class _AppMenuFlyoutSubItemState extends State<_AppMenuFlyoutSubItem> with SingleTickerProviderStateMixin {

  /// The animation controller responsible for the animation of the flyout.
  ///
  /// The duration is defined at build time.
  late final transitionController = AnimationController(vsync: this);

  final menuKey = GlobalKey<_AppMenuFlyoutState>();

  Timer? showTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = Flyout.of(context);
    transitionController.duration = parent.transitionDuration;
    transitionController.reverseDuration = parent.reverseTransitionDuration;
  }

  @override
  void dispose() {
    transitionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AppMenuFlyoutSubItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final parent = Flyout.of(context);
    if (transitionController.duration == null || transitionController.duration != parent.transitionDuration) {
      transitionController.duration = parent.transitionDuration;
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuInfo = MenuInfoProvider.of(context);

    final item = _buildAppMenuTile(
      context,
      text: widget.item.text,
      leading: widget.item.leading,
      trailing: widget.item.trailing,
      selected: isShowing(menuInfo),
      closeAfterClick: false,
      useIconPlaceholder: widget.item.useIconPlaceholder,
      onPressed: () {
        show(menuInfo);
      },
    );

    if (widget.item.showBehavior == SubItemShowAction.hover) {
      return MouseRegion(
        onEnter: (event) {
          showTimer = Timer(widget.item.showHoverDelay, () {
            show(menuInfo);
          });
        },
        onExit: (event) {
          if (showTimer != null && showTimer!.isActive) {
            showTimer!.cancel();
          }
        },
        child: item,
      );
    }

    return item;
  }

  bool isShowing(MenuInfoProviderState menuInfo) {
    return menuInfo.contains(menuKey);
  }

  void show(MenuInfoProviderState menuInfo) {
    // fluent only closes sibling sub-menus on mouse hover, which never fires on a
    // tap/touch — so two sibling sub-menus could stay open at once. Close any open
    // sibling here so only the most recently opened sub-menu remains.
    final parentMenu = context.findAncestorStateOfType<_AppMenuFlyoutState>();
    if (parentMenu != null) {
      for (final key in parentMenu.keys.whereType<GlobalKey<_AppMenuFlyoutSubItemState>>()) {
        final siblingState = key.currentState;
        if (siblingState != null && !identical(siblingState, this) && siblingState.isShowing(menuInfo)) {
          siblingState.close(menuInfo);
        }
      }
    }

    final parent = Flyout.of(context);

    final menuFlyout = context.findAncestorWidgetOfExactType<AppMenuFlyout>();

    final itemBox = context.findRenderObject()! as RenderBox;
    final itemRect =
        itemBox.localToGlobal(
          Offset.zero,
          ancestor: parent.widget.root?.context.findRenderObject(),
        ) &
        itemBox.size;

    menuInfo.add(
      CustomSingleChildLayout(
        delegate: _SubItemPositionDelegate(
          parentRect: itemRect,
          parentSize: itemBox.size,
          margin: parent.margin,
          textDirection: Directionality.of(context),
        ),
        child: Flyout(
          rootFlyout: parent.rootFlyout,
          menuKey: menuKey,
          additionalOffset: parent.additionalOffset,
          margin: parent.margin,
          transitionDuration: parent.transitionDuration,
          reverseTransitionDuration: parent.reverseTransitionDuration,
          transitionBuilder: parent.transitionBuilder,
          root: parent.widget.root,
          placementMode: parent.placementMode,
          builder: (context) {
            var w = parent.transitionBuilder.call(
              context,
              transitionController,
              FlyoutPlacementMode.bottomCenter,
              AppMenuFlyout(
                key: menuKey,
                color: menuFlyout?.color,
                constraints: menuFlyout?.constraints,
                elevation: menuFlyout?.elevation ?? 8.0,
                itemMargin: menuFlyout?.itemMargin ?? kDefaultMenuItemMargin,
                shadowColor: menuFlyout?.shadowColor ?? Colors.black,
                shape: menuFlyout?.shape,
                items: widget.items(context),
              ),
            );

            if (widget.item.disableAcyrlic) {
              w = DisableAcrylic(child: w);
            }

            return w;
          },
        ),
      ),
      menuKey,
    );

    transitionController.forward();
    setState(() {});
  }

  /// Closes this menu and its children
  Future<void> close(MenuInfoProviderState menuInfo) async {
    await Future.wait([
      if (menuKey.currentState != null)
        ...menuKey.currentState!.keys
            .whereType<GlobalKey<_AppMenuFlyoutSubItemState>>()
            .map((child) => child.currentState!.close(menuInfo)),
      transitionController.reverse(),
    ]);

    menuInfo.remove(menuKey);

    if (mounted) setState(() {});
  }

}

class _SubItemPositionDelegate extends SingleChildLayoutDelegate {

  final Rect parentRect;
  final Size parentSize;
  final double margin;
  final TextDirection textDirection;

  const _SubItemPositionDelegate({
    required this.parentRect,
    required this.parentSize,
    required this.margin,
    required this.textDirection,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // The margin should include a top and a bottom
    final maxHeight = constraints.maxHeight - margin * 2;
    return constraints.loosen().copyWith(maxHeight: maxHeight);
  }

  @override
  Offset getPositionForChild(Size rootSize, Size flyoutSize) {
    final isRtl = textDirection == TextDirection.rtl;
    double x;

    if (isRtl) {
      // In RTL, the sub-menu should open to the left of the parent item by
      // default.
      x = parentRect.left - flyoutSize.width;

      // if the flyout will overflow the screen on the left
      final willOverflowX = x < margin;

      if (willOverflowX) {
        // try to the right of the parent item
        final rightX = parentRect.left + parentRect.size.width;
        if (rightX + flyoutSize.width + margin <= rootSize.width) {
          x = rightX;
        } else {
          x = clampDouble(margin, 0, rootSize.width);
        }
      }
    } else {
      // In LTR, the sub-menu should open to the right of the parent item by
      // default.
      x = parentRect.left + parentRect.size.width;

      // if the flyout will overflow the screen on the right
      final willOverflowX = x + flyoutSize.width + margin > rootSize.width;

      // if overflow x on the right, we check for some cases
      //
      // if the space available on the right is greater than the space available
      // on the left, use the right.
      //
      // otherwise, we position the flyout at the end of the screen
      if (willOverflowX) {
        final leftX = parentRect.left - flyoutSize.width;
        if (leftX > margin) {
          x = leftX;
        } else {
          x = clampDouble(
            rootSize.width - flyoutSize.width - margin,
            0,
            rootSize.width,
          );
        }
      }
    }

    var y = parentRect.top;
    final willOverflowY = y + flyoutSize.height + margin > rootSize.height;

    if (willOverflowY) {
      y = parentRect.top + parentRect.height - flyoutSize.height;
      if (y < margin) y = margin;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _SubItemPositionDelegate oldDelegate) {
    return oldDelegate.parentRect != parentRect ||
        oldDelegate.parentSize != parentSize ||
        oldDelegate.margin != margin ||
        oldDelegate.textDirection != textDirection;
  }

}
