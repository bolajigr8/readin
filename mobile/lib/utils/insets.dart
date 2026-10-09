import 'package:flutter/widgets.dart';

/// Bottom system inset of the **device** (gesture/nav bar), unaffected by a
/// parent `Scaffold` that already consumed it for its bottom bar.
/// RN `useSafeAreaInsets().bottom` behaves the same way inside tab screens.
double deviceBottomInset(BuildContext context) =>
    MediaQueryData.fromView(View.of(context)).viewPadding.bottom;
