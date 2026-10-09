import 'dart:async';

import '../errors/app_exception.dart';

/// Result of every network call: [Success] or [Failure].
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(data: final d) => d,
        Failure<T>() => null,
      };

  AppException? get exceptionOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(exception: final e) => e,
      };

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) =>
      switch (this) {
        Success<T>(data: final d) => success(d),
        Failure<T>(exception: final e) => failure(e),
      };

  FutureOr<void> onSuccess(FutureOr<void> Function(T data) callback) async {
    final self = this;
    if (self is Success<T>) await callback(self.data);
  }

  void onFailure(void Function(AppException exception) callback) {
    final self = this;
    if (self is Failure<T>) callback(self.exception);
  }
}

final class Success<T> extends ApiResult<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends ApiResult<T> {
  const Failure(this.exception);
  final AppException exception;
}

extension ApiResultFutureX<T> on Future<ApiResult<T>> {
  /// Resolves to the data on success, throws the [AppException] on failure.
  /// Handy for `FutureProvider`s.
  Future<T> unwrap() =>
      then((r) => r.when(success: (d) => d, failure: (e) => throw e));
}
