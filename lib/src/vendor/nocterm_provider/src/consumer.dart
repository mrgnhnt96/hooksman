import 'package:nocterm/nocterm.dart';
import 'package:hooksman/src/vendor/nocterm_nested/nested.dart';

import 'provider.dart';
import 'selector.dart' show Selector;

/// {@template provider.consumer}
/// Obtains [Provider<T>] from its ancestors and passes its value to [builder].
///
/// The [Consumer] Component doesn't do any fancy work. It just calls [Provider.of]
/// in a new Component, and delegates its `build` implementation to [builder].
///
/// [builder] must not be null and may be called multiple times (such as when
/// the provided value change).
///
/// The [Consumer] Component has two main purposes:
///
/// * It allows obtaining a value from a provider when we don't have a
///   [BuildContext] that is a descendant of said provider, and therefore
///   cannot use [Provider.of].
///
/// This scenario typically happens when the Component that creates the provider
/// is also one of its consumers, like in the following example:
///
/// ```dart
/// @override
/// Component build(BuildContext context) {
///   return ChangeNotifierProvider(
///     create: (_) => Foo(),
///     child: Text(Provider.of<Foo>(context).value),
///   );
/// }
/// ```
///
/// This example will throw a [ProviderNotFoundException], because [Provider.of]
/// is called with a [BuildContext] that is an ancestor of the provider.
///
/// Instead, we can use the [Consumer] Component, that will call [Provider.of]
/// with its own [BuildContext].
///
/// Using [Consumer], the previous example will become:
///
/// ```dart
/// @override
/// Component build(BuildContext context) {
///   return ChangeNotifierProvider(
///     create: (_) => Foo(),
///     child: Consumer<Foo>(
///       builder: (_, foo, __) => Text(foo.value),
///     },
///   );
/// }
/// ```
///
/// This won't throw a [ProviderNotFoundException] and will correctly build the
/// [Text]. It will also update the [Text] whenever the value `foo` changes.
///
///
/// * It helps with performance optimization by providing more granular rebuilds.
///
/// Unless `listen: false` is passed to [Provider.of], the Component
/// associated with the [BuildContext] passed to [Provider.of] will rebuild
/// whenever the obtained value changes. This is the expected behavior,
/// but sometimes it may rebuild more Components than needed.
///
/// Here's an example:
///
/// ```dart
///  @override
///  Component build(BuildContext context) {
///    return FooComponent(
///      child: BarComponent(
///        bar: Provider.of<Bar>(context),
///      ),
///    );
///  }
/// ```
///
/// In the above code, only `BarComponent` depends on the value returned by
/// [Provider.of]. But when `Bar` changes, then both `BarComponent` _and_
/// `FooComponent` will rebuild.
///
/// Ideally, only `BarComponent` should be rebuilt. One
/// solution to achieve that is to use [Consumer].
///
/// To do so, we will wrap _only_ the Components that depends on a provider into
/// a [Consumer]:
///
/// ```dart
///  @override
///  Component build(BuildContext context) {
///    return FooComponent(
///      child: Consumer<Bar>(
///        builder: (_, bar, __) => BarComponent(bar: bar),
///      ),
///    );
///  }
/// ```
///
/// In this situation, if `Bar` were to update, only `BarComponent` would rebuild.
///
/// But what if it was `FooComponent` that depended on a provider? Example:
///
/// ```dart
///  @override
///  Component build(BuildContext context) {
///    return FooComponent(
///      foo: Provider.of<Foo>(context),
///      child: BarComponent(),
///    );
///  }
/// ```
///
/// Using [Consumer], we can handle this kind of scenario using the optional
/// `child` argument:
///
/// ```dart
///  @override
///  Component build(BuildContext context) {
///    return Consumer<Foo>(
///      builder: (_, foo, child) => FooComponent(foo: foo, child: child),
///      child: BarComponent(),
///    );
///  }
/// ```
///
/// In that example, `BarComponent` is built outside of [builder]. Then, the
/// `BarComponent` instance is passed to [builder] as the last parameter.
///
/// This means that when [builder] is called again with new values, a new
/// instance of `BarComponent` will not be created.
/// This lets Flutter know that it doesn't have to rebuild `BarComponent`.
/// Therefore in such a configuration, only `FooComponent` will rebuild
/// if `Foo` changes.
///
/// ## Note:
///
/// The [Consumer] Component can also be used inside [MultiProvider]. To do so, it
/// must return the `child` passed to [builder] in the Component tree it creates.
///
/// ```dart
/// MultiProvider(
///   providers: [
///     Provider(create: (_) => Foo()),
///     Consumer<Foo>(
///       builder: (context, foo, child) =>
///         Provider.value(value: foo.bar, child: child),
///     )
///   ],
/// );
/// ```
///
/// See also:
///   * [Selector], a [Consumer] that can filter updates.
/// {@endtemplate}
class Consumer<T> extends SingleChildStatelessComponent {
  /// {@template provider.consumer.constructor}
  /// Consumes a [Provider<T>]
  /// {@endtemplate}
  Consumer({Key? key, required this.builder, Component? child})
      : super(key: key, child: child);

  /// {@template provider.consumer.builder}
  /// Build a Component tree based on the value from a [Provider<T>].
  ///
  /// Must not be `null`.
  /// {@endtemplate}
  final Component Function(BuildContext context, T value, Component? child)
      builder;

  @override
  Component buildWithChild(BuildContext context, Component? child) {
    return builder(context, Provider.of<T>(context), child);
  }
}

/// {@macro provider.consumer}
class Consumer2<A, B> extends SingleChildStatelessComponent {
  /// {@macro provider.consumer.constructor}
  Consumer2({Key? key, required this.builder, Component? child})
      : super(key: key, child: child);

  /// {@macro provider.consumer.builder}
  final Component Function(
    BuildContext context,
    A value,
    B value2,
    Component? child,
  ) builder;

  @override
  Component buildWithChild(BuildContext context, Component? child) {
    return builder(
      context,
      Provider.of<A>(context),
      Provider.of<B>(context),
      child,
    );
  }
}

/// {@macro provider.consumer}
class Consumer3<A, B, C> extends SingleChildStatelessComponent {
  /// {@macro provider.consumer.constructor}
  Consumer3({Key? key, required this.builder, Component? child})
      : super(key: key, child: child);

  /// {@macro provider.consumer.builder}
  final Component Function(
    BuildContext context,
    A value,
    B value2,
    C value3,
    Component? child,
  ) builder;

  @override
  Component buildWithChild(BuildContext context, Component? child) {
    return builder(
      context,
      Provider.of<A>(context),
      Provider.of<B>(context),
      Provider.of<C>(context),
      child,
    );
  }
}

/// {@macro provider.consumer}
class Consumer4<A, B, C, D> extends SingleChildStatelessComponent {
  /// {@macro provider.consumer.constructor}
  Consumer4({Key? key, required this.builder, Component? child})
      : super(key: key, child: child);

  /// {@macro provider.consumer.builder}
  final Component Function(
    BuildContext context,
    A value,
    B value2,
    C value3,
    D value4,
    Component? child,
  ) builder;

  @override
  Component buildWithChild(BuildContext context, Component? child) {
    return builder(
      context,
      Provider.of<A>(context),
      Provider.of<B>(context),
      Provider.of<C>(context),
      Provider.of<D>(context),
      child,
    );
  }
}

/// {@macro provider.consumer}
class Consumer5<A, B, C, D, E> extends SingleChildStatelessComponent {
  /// {@macro provider.consumer.constructor}
  Consumer5({Key? key, required this.builder, Component? child})
      : super(key: key, child: child);

  /// {@macro provider.consumer.builder}
  final Component Function(
    BuildContext context,
    A value,
    B value2,
    C value3,
    D value4,
    E value5,
    Component? child,
  ) builder;

  @override
  Component buildWithChild(BuildContext context, Component? child) {
    return builder(
      context,
      Provider.of<A>(context),
      Provider.of<B>(context),
      Provider.of<C>(context),
      Provider.of<D>(context),
      Provider.of<E>(context),
      child,
    );
  }
}

/// {@macro provider.consumer}
class Consumer6<A, B, C, D, E, F> extends SingleChildStatelessComponent {
  /// {@macro provider.consumer.constructor}
  Consumer6({Key? key, required this.builder, Component? child})
      : super(key: key, child: child);

  /// {@macro provider.consumer.builder}
  final Component Function(
    BuildContext context,
    A value,
    B value2,
    C value3,
    D value4,
    E value5,
    F value6,
    Component? child,
  ) builder;

  @override
  Component buildWithChild(BuildContext context, Component? child) {
    return builder(
      context,
      Provider.of<A>(context),
      Provider.of<B>(context),
      Provider.of<C>(context),
      Provider.of<D>(context),
      Provider.of<E>(context),
      Provider.of<F>(context),
      child,
    );
  }
}
