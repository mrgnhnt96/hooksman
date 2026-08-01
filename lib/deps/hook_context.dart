import 'package:hooksman/models/hook_context.dart';
import 'package:scoped_deps/scoped_deps.dart';

final hookContextProvider = create(() => HookContext.empty);

HookContext get hookContext => read(hookContextProvider);
