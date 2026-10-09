import 'package:flutter/material.dart';

/// Icon set used by the app, with the same names as RN's Ionicons.
///
/// This file is a **Material-icons fallback** so the app builds without any
/// extra step (the `ionicons` pub package no longer compiles: it extends
/// `IconData`, which is a final class in current Flutter).
///
/// For the EXACT icons of the RN app run (once) from the project root:
///
///     dart run tool/gen_ionicons.dart <path-to-your-RN-project>
///
/// which regenerates THIS file from the RN project's Ionicons font + glyph map,
/// copies the font to `assets/fonts/Ionicons.ttf` and registers it in
/// `pubspec.yaml`. No other code changes are needed (same `Ionicons.name` API).
class Ionicons {
  Ionicons._();

  static const IconData add = Icons.add;
  static const IconData add_circle_outline = Icons.add_circle_outline;
  static const IconData alert_circle_outline = Icons.error_outline;
  static const IconData arrow_back = Icons.arrow_back;
  static const IconData arrow_forward = Icons.arrow_forward;
  static const IconData book = Icons.menu_book;
  static const IconData book_outline = Icons.menu_book_outlined;
  static const IconData bookmark = Icons.bookmark;
  static const IconData bookmark_outline = Icons.bookmark_border;
  static const IconData checkmark = Icons.check;
  static const IconData checkmark_circle = Icons.check_circle;
  static const IconData checkmark_circle_outline = Icons.check_circle_outline;
  static const IconData chevron_back = Icons.chevron_left;
  static const IconData chevron_down = Icons.keyboard_arrow_down;
  static const IconData chevron_forward = Icons.chevron_right;
  static const IconData chevron_up = Icons.keyboard_arrow_up;
  static const IconData close = Icons.close;
  static const IconData close_circle = Icons.cancel;
  static const IconData cloud_download_outline = Icons.cloud_download_outlined;
  static const IconData cloud_upload = Icons.cloud_upload;
  static const IconData cloud_upload_outline = Icons.cloud_upload_outlined;
  static const IconData color_palette_outline = Icons.palette_outlined;
  static const IconData color_wand_outline = Icons.auto_fix_high;
  static const IconData compass = Icons.explore;
  static const IconData compass_outline = Icons.explore_outlined;
  static const IconData create_outline = Icons.edit_outlined;
  static const IconData document_text_outline = Icons.description_outlined;
  static const IconData eye_off_outline = Icons.visibility_off_outlined;
  static const IconData eye_outline = Icons.visibility_outlined;
  static const IconData flash_outline = Icons.flash_on_outlined;
  static const IconData funnel_outline = Icons.filter_list;
  static const IconData grid_outline = Icons.grid_view_outlined;
  static const IconData headset = Icons.headset;
  static const IconData headset_outline = Icons.headset_outlined;
  static const IconData home = Icons.home;
  static const IconData home_outline = Icons.home_outlined;
  static const IconData information_circle_outline = Icons.info_outline;
  static const IconData language_outline = Icons.language;
  static const IconData library = Icons.library_books;
  static const IconData library_outline = Icons.library_books_outlined;
  static const IconData list_outline = Icons.list;
  static const IconData lock_closed_outline = Icons.lock_outline;
  static const IconData log_out_outline = Icons.logout;
  static const IconData logo_google = Icons.g_mobiledata;
  static const IconData mail_outline = Icons.mail_outline;
  static const IconData menu = Icons.menu;
  static const IconData notifications_outline = Icons.notifications_none;
  static const IconData pause = Icons.pause;
  static const IconData person = Icons.person;
  static const IconData person_outline = Icons.person_outline;
  static const IconData play = Icons.play_arrow;
  static const IconData play_skip_back_outline = Icons.skip_previous_outlined;
  static const IconData play_skip_forward_outline = Icons.skip_next_outlined;
  static const IconData refresh_outline = Icons.refresh;
  static const IconData remove_circle_outline = Icons.remove_circle_outline;
  static const IconData search_outline = Icons.search;
  static const IconData settings_outline = Icons.settings_outlined;
  static const IconData shield_checkmark_outline = Icons.verified_user_outlined;
  static const IconData star = Icons.star;
  static const IconData text_outline = Icons.text_fields;
  static const IconData trash_outline = Icons.delete_outline;
  static const IconData warning_outline = Icons.warning_amber_outlined;
  static const IconData wifi_outline = Icons.wifi;
  static const IconData copy_outline = Icons.content_copy_outlined;
  static const IconData menu_outline = Icons.format_align_left;
  static const IconData reorder_four_outline = Icons.format_line_spacing;
  static const IconData resize_outline = Icons.format_indent_increase;
  static const IconData sunny_outline = Icons.wb_sunny_outlined;
  static const IconData swap_horizontal_outline = Icons.swap_horiz;
  static const IconData volume_high_outline = Icons.volume_up_outlined;
  static const IconData cafe_outline = Icons.local_cafe_outlined;
  static const IconData cloudy_outline = Icons.cloud_outlined;
  static const IconData document_attach_outline = Icons.attach_file;
  static const IconData download_outline = Icons.download_outlined;
  static const IconData flame_outline = Icons.local_fire_department_outlined;
  static const IconData folder_open_outline = Icons.folder_open;
  static const IconData image_outline = Icons.image_outlined;
  static const IconData moon_outline = Icons.dark_mode_outlined;
  static const IconData open_outline = Icons.open_in_new;
  static const IconData partly_sunny_outline = Icons.wb_twilight;
  static const IconData play_forward_outline = Icons.fast_forward_outlined;
  static const IconData pulse_outline = Icons.graphic_eq;
  static const IconData radio_outline = Icons.radio;
  static const IconData rainy_outline = Icons.grain;
  static const IconData share_outline = Icons.share_outlined;
  static const IconData volume_medium_outline = Icons.volume_down_outlined;
  static const IconData water_outline = Icons.water_drop_outlined;
}
