import 'package:hooksman/services/git/git_service.dart';
import 'package:scoped_deps/scoped_deps.dart';

final gitProvider = create(GitService.new);

GitService get git => read(gitProvider);
