import 'package:el_flutter/ext.dart';
import 'package:flutter/material.dart';

class _State {
  void dispose() {}
}

class DemoPage extends HookWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = useMemoized(() => _State());

    useEffect(() {
      return state.dispose;
    }, []);

    return Scaffold(
      appBar: AppBar(title: const Text('首页')),
      body: Container(),
    );
  }
}
