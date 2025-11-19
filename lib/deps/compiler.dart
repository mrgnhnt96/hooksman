import 'package:hooksman/models/compiler.dart';
import 'package:scoped_deps/scoped_deps.dart';

final compilerProvider = create(Compiler.new);

Compiler get compiler => read(compilerProvider);
