# Cupertino Context Menu Plus

Based on cupertino_context_menu_plus 1.0.3:
https://github.com/esentis/cupertino_context_menu_plus

Local changes retain the upstream gestures and animation implementation:

- Optional nearest-Navigator routing and overlay-relative preview coordinates.
- Route creation callback for binding menus to their source page and pane.
- Immediate controller dismissal for hidden panes, including pending previews.
- Restore the source widget when a route is removed without a pop animation.

The application uses this package through AppContextMenu only. Retain these
changes when updating the upstream source. The upstream BSD license is in LICENSE.
