import 'api/api_exception.dart';

/// The return type of every repository method. Forces callers to handle
/// failure at the point of use rather than by catching somewhere distant.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
  ApiException? get errorOrNull =>
      this is Err<T> ? (this as Err<T>).error : null;

  R when<R>({
    required R Function(T value) ok,
    required R Function(ApiException error) err,
  }) =>
      this is Ok<T> ? ok((this as Ok<T>).value) : err((this as Err<T>).error);
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final ApiException error;
  const Err(this.error);
}
