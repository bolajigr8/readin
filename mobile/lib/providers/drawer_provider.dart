import 'package:flutter_riverpod/flutter_riverpod.dart';

/// RN `DrawerContext.isOpen`. Auto-disposed so the drawer is always closed
/// after sign-out / sign-in.
final drawerOpenProvider = StateProvider.autoDispose<bool>((ref) => false);
