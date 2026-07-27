/// Where an avatar upload has got to.
///
/// Deliberately a sealed hierarchy rather than a bag of nullable fields: a
/// screen must not be able to render "uploading" and "failed" at once, and the
/// switch is exhaustive so a new state cannot be silently unhandled.
sealed class AvatarUploadState {
  const AvatarUploadState();
}

/// Nothing in flight. [url] carries the photo already on file, when known.
class AvatarIdle extends AvatarUploadState {
  const AvatarIdle({this.url});

  /// The current avatar URL, or null when the user has none.
  final String? url;
}

/// Bytes are on the wire. The picker has returned and the PUT is running.
class AvatarUploading extends AvatarUploadState {
  const AvatarUploading();
}

/// The upload landed. [url] is the stable URL to render.
class AvatarUploaded extends AvatarUploadState {
  const AvatarUploaded(this.url);

  final String url;
}

/// The upload failed. [message] is already user-facing — the controller maps
/// the server's error codes to sentences a rider can act on, so a screen may
/// show this verbatim rather than inventing its own copy.
class AvatarUploadFailed extends AvatarUploadState {
  const AvatarUploadFailed(this.message);

  final String message;
}
