import 'dart:io' as io;

import 'package:scoped_deps/scoped_deps.dart';

final stdoutProvider = create(() => io.stdout);

io.Stdout get stdout => read(stdoutProvider);
