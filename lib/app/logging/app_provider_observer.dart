import 'package:fbooks/app/logging/app_logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final providerName = context.provider.name ?? context.provider.runtimeType;
    reportUnhandledError('Provider failed: $providerName.', error, stackTrace);
  }
}
