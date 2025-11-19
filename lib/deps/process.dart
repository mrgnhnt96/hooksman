import 'package:hooksman/utils/process/process.dart';
import 'package:scoped_deps/scoped_deps.dart';

final processProvider = create(Process.new);

Process get process => read(processProvider);
