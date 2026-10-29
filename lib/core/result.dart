import 'package:printer_app/models/app_error.dart';

/// 统一的业务层结果包装。
///
/// 业务方法（发现 / IPP / 导入等）建议返回 [Result]，
/// 由 UI 统一通过 [status_banner] 展示，避免到处抛异常。
class Result<T> {
  /// 成功时的返回值（失败为 null）
  final T? value;

  /// 失败时的错误（成功为 null）
  final AppError? error;

  const Result._({this.value, this.error});

  /// 构造成功结果
  const Result.ok(T value) : this._(value: value);

  /// 构造失败结果
  const Result.fail(AppError error) : this._(error: error);

  /// 是否成功
  bool get isOk => error == null;

  /// 是否失败
  bool get isFail => error != null;
}
