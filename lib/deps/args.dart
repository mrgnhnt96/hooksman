import 'package:hooksman/models/args.dart';
import 'package:scoped_deps/scoped_deps.dart';

final argsProvider = create(Args.new);

Args get args => read(argsProvider);
