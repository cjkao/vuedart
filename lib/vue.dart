@JS()
library vue2;


import 'package:initialize/initialize.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'dart:async';
import 'dart:html';

export 'package:initialize/initialize.dart' show initMethod;


@JS('eval')
external dynamic _eval(String value);
dynamic _window = _eval('window');

dynamic getWindowProperty(String name) {
  return getProperty(_window, name);
}

dynamic _vue = getWindowProperty('Vue');

// @JS('console.log')
// external dynamic _log(dynamic value);

dynamic mapToJs(Map<String, dynamic> map) {
  var obj = newObject();
  for (var key in map.keys) {
    setProperty(obj, key, map[key]);
  }
  return obj;
}

dynamic _mapMethodsToJs(Map<String, Function> methods) =>
  mapToJs(new Map.fromIterables(methods.keys,
                                methods.values.map(allowInteropCaptureThis)));

dynamic vueGetObj(dynamic vuethis) => getProperty(vuethis, '\$dartobj');
dynamic _interopWithObj(Function func) =>
  allowInteropCaptureThis((context) => func(vueGetObj(context)));

typedef dynamic CreateElement(dynamic tag, [dynamic arg1, dynamic arg2]);

class VueProp {
  final Function validator;
  final Object initializer;

  VueProp(this.validator, this.initializer);
}

class VueComputed {
  final Function getter, setter;

  VueComputed(this.getter, this.setter);
}

class VueWatcher {
  final Function watcher;
  final bool deep;

  VueWatcher(this.watcher, this.deep);
}

dynamic _convertComputed(Map<String, VueComputed> computed) {
  var jscomputed = <String, dynamic>{};

  for (var name in computed.keys) {
    var comp = computed[name];
    jscomputed[name] = newObject();
    setProperty(jscomputed[name], 'get',
                allowInteropCaptureThis((vuethis, misc) => comp.getter(vuethis)));

    if (comp.setter != null) {
      setProperty(jscomputed[name], 'set', allowInteropCaptureThis(comp.setter));
    }
  }

  return mapToJs(jscomputed);
}

dynamic _convertWatchers(Map<String, VueWatcher> watchers) {
  var jswatch = <String, dynamic>{};

  for (var name in watchers.keys) {
    var watcher = watchers[name];
    jswatch[name] = newObject();
    setProperty(jswatch[name], 'handler', allowInteropCaptureThis(watcher.watcher));
    setProperty(jswatch[name], 'deep', watcher.deep);
  }

  return mapToJs(jswatch);
}

class VueComponentConstructor {
  final String name, template, styleInject;
  final Map<String, VueProp> props;
  final Map<String, Object> data;
  final Map<String, VueComputed> computed;
  final Map<String, Function> methods;
  final Map<String, VueWatcher> watchers;
  final List<VueComponentConstructor> mixins;
  Function creator;

  VueComponentConstructor({this.name: null, this.template: null, this.styleInject: null,
                           this.props: null, this.data: null, this.computed: null,
                           this.methods: null, this.watchers: null, this.creator: null,
                           this.mixins: null});

  dynamic jsprops() {
    var jsprops = <String, dynamic>{};

    for (var prop in props.keys) {
      jsprops[prop] = mapToJs({
        'default': props[prop].initializer,
        'validator': allowInterop(props[prop].validator),
      });
    }

    return mapToJs(jsprops);
  }

  dynamic jscomputed() => _convertComputed(computed);
  dynamic jswatch() => _convertWatchers(watchers);
}

class VueAppConstructor {
  final String el;
  final Map<String, Object> data;
  final Map<String, VueComputed> computed;
  final Map<String, Function> methods;
  final Map<String, VueWatcher> watchers;

  VueAppConstructor({this.el, this.data, this.computed, this.methods, this.watchers});

  dynamic jscomputed() => _convertComputed(computed);
  dynamic jswatch() => _convertWatchers(watchers);
}

class _VueBase {
  dynamic vuethis;

  dynamic vuedart_get(String key) => getProperty(vuethis, key);
  void vuedart_set(String key, dynamic value) => setProperty(vuethis, key, value);

  dynamic render(CreateElement createElement) => null;

  void mounted() {}
  void beforeUpdate() {}
  void updated() {}
  void activated() {}
  void deactivated() {}
  void beforeDestroy() { }
  void destroyed() {}

  static Map<String, dynamic> lifecycleHooks = {
    'mounted': _interopWithObj((obj) => obj.mounted()),
    'beforeUpdate': _interopWithObj((obj) => obj.beforeUpdate()),
    'updated': _interopWithObj((obj) => obj.updated()),
    'activated': _interopWithObj((obj) => obj.activated()),
    'deactivated': _interopWithObj((obj) => obj.deactivated()),
    'beforeDestroy': _interopWithObj((obj) => obj.beforeDestroy()),
    'destroyed': _interopWithObj((obj) => obj.destroyed()),
  };

  dynamic $ref(String name) {
    var refs = getProperty(vuethis, '\$refs');
    var ref = getProperty(refs, name);
    if (ref == null) return null;
    return vueGetObj(ref) ?? ref;
  }

  dynamic get $data => vuedart_get('\$data');
  dynamic get $props => vuedart_get('\$props');
  Element get $el => vuedart_get('\$el');
  dynamic get $options => vuedart_get('\$options');

  dynamic get $parent {
    var parent = vuedart_get('\$parent');
    if (parent == null) return null;

    return vueGetObj(parent) ?? parent;
  }

  dynamic get $root {
    var root = vuedart_get('\$root');
    return vueGetObj(root) ?? root;
  }

  void $on(dynamic event, Function callback) =>
    callMethod(vuethis, '\$on', [event, allowInterop(callback)]);

  void $once(dynamic event, Function callback) =>
    callMethod(vuethis, '\$once', [event, allowInterop(callback)]);

  void $off(dynamic event, Function callback) =>
    callMethod(vuethis, '\$off', [event, allowInterop(callback)]);

  void $emit(String event, [List args]) =>
    callMethod(vuethis, '\$emit', [event]..addAll(args ?? []));

  Future<Null> $nextTick() {
    var compl = new Completer();
    callMethod(vuethis, '\$nextTick', [allowInterop(() => compl.complete(null))]);
    return compl.future;
  }

  void $forceUpdate() => callMethod(vuethis, '\$forceUpdate', []);
  void $destroy() => callMethod(vuethis, '\$destroy', []);
}

class _FakeException {
  VueAppConstructor constr;
  _FakeException(this.constr);
}

class VueComponentBase extends _VueBase {
  VueComponentBase(dynamic context) {
    vuethis = context;
    setProperty(vuethis, '\$dartobj', this);
  }

  static dynamic componentArgs(VueComponentConstructor constr, {bool isMixin: false}) {
    var props = constr.jsprops();
    var computed = constr.jscomputed();
    var watch = constr.jswatch();
    var renderFunc;

    if (constr.styleInject.isNotEmpty) {
      var el = new StyleElement();
      el.appendText(constr.styleInject);
      document.head.append(el);
    }

    if (constr.template == null) {
      renderFunc = allowInteropCaptureThis((context, jsCreateElement) {
        dynamic createElement(dynamic tag, [dynamic arg1, dynamic arg2]) {
          return jsCreateElement(tag is Map ? mapToJs(tag) : tag,
                                 arg1 != null && arg1 is Map ? mapToJs(arg1) : arg1,
                                 arg2);
        };

        return vueGetObj(context).render(createElement);
      });
    }

    return mapToJs({
      'props': props,
      'created': !isMixin ? allowInteropCaptureThis(constr.creator) : null,
      'data': allowInterop(() {
        var data = mapToJs(constr.data);
        setProperty(data, '\$dartobj', null);
        return data;
      }),
      'computed': computed,
      'methods': _mapMethodsToJs(constr.methods),
      'watch': watch,
      'template': constr.template,
      'render': renderFunc,
      'mixins': constr.mixins
                  .map((mx) => VueComponentBase.componentArgs(mx, isMixin: true))
                  .toList(),
    }..addAll(_VueBase.lifecycleHooks));
  }

  static void register(VueComponentConstructor constr) {
    callMethod(_vue, 'component', [constr.name,
                                   VueComponentBase.componentArgs(constr)]);
  }
}

class VueAppBase extends _VueBase {
  VueAppConstructor get constructor => null;

  VueAppBase(dynamic context) {
    if (context == null) throw new _FakeException(constructor);
    vuethis = context;
    setProperty(vuethis, '\$dartobj', this);
  }

  static create(Function creator) {
    var constr;

    try {
      creator(null);
    } on _FakeException catch (ex) {
      constr = ex.constr;
    }

    var computed = constr.jscomputed();
    var watch = constr.jswatch();
    var result;

    var args = mapToJs({
      'el': constr.el,
      'created': allowInteropCaptureThis((context) {
        result = creator(context);
      }),
      'data': mapToJs(constr.data),
      'computed': computed,
      'methods': _mapMethodsToJs(constr.methods),
      'watch': watch,
    }..addAll(_VueBase.lifecycleHooks));

    callConstructor(_vue, [args]);
    return result;
  }
}

class VuePlugin {
  static Set<String> _plugins = new Set<String>();

  static void use(String pluginName) {
    if (_plugins.contains(pluginName)) {
      return;
    }

    var plugin = getWindowProperty(pluginName);
    callMethod(_vue, 'use', [plugin]);
    _plugins.add(pluginName);
  }
}

class VueComponent {
  final String name, template;
  final List mixins;
  const VueComponent(this.name, {this.template, this.mixins});
}

class VueApp {
  final String el;
  const VueApp({this.el});
}

class VueMixin {
  const VueMixin();
}

class _VueData { const _VueData(); }
class _VueProp { const _VueProp(); }
class _VueComputed { const _VueComputed(); }
class _VueMethod { const _VueMethod(); }
class _VueRef { const _VueRef(); }

const data = const _VueData();
const prop = const _VueProp();
const computed = const _VueComputed();
const method = const _VueMethod();
const ref = const _VueRef();

class watch {
  final String name;
  final bool deep;
  const watch(this.name, {this.deep});
}

Future initVue() async => run();
