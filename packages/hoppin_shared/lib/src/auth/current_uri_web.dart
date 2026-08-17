import 'dart:html' as html;

const _kSavedAuthHref = 'hoppin_auth_href';

bool _looksLikeAuthHref(String href) {
  final u = href.toLowerCase();
  return u.contains('token_hash=') ||
      u.contains('access_token=') ||
      u.contains('code=') ||
      u.contains('type=magiclink') ||
      u.contains('type=invite') ||
      u.contains('type=recovery');
}

/// Live URL, or the one we stashed when the magic-link hash was still present.
/// PathUrlStrategy / go_router both rewrite the bar and drop `#access_token=`.
Uri hoppinCurrentUri() {
  final live = html.window.location.href;
  if (_looksLikeAuthHref(live)) {
    html.window.sessionStorage[_kSavedAuthHref] = live;
    return Uri.parse(live);
  }
  final saved = html.window.sessionStorage[_kSavedAuthHref];
  if (saved != null && saved.isNotEmpty) return Uri.parse(saved);
  return Uri.parse(live);
}

void hoppinClearSavedAuthUri() {
  html.window.sessionStorage.remove(_kSavedAuthHref);
}
