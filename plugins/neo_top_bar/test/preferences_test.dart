import 'dart:convert';
import 'dart:io';

import 'package:neo_top_bar/neo_top_bar_logic.dart';
import 'package:test/test.dart';

/// The first instance of [descriptor]: what a bare module id means.
NeoModulePlacement _firstInstance(
  NeoTopBarConfig config,
  NeoModuleDescriptor descriptor,
) => resolvePlacements(
  descriptors: <NeoModuleDescriptor>[descriptor],
  config: config,
).first;

void main() {
  late Directory directory;
  late NeoTopBarPreferencesStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('neo_top_bar_test');
    store = NeoTopBarPreferencesStore(
      File('${directory.path}/neo_top_bar.json'),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('a missing file reads as an empty configuration', () async {
    final config = await store.read();
    expect(config.instances, isEmpty);
    expect(config.order, isEmpty);
  });

  test('a malformed file is surfaced rather than silently replaced', () async {
    await store.file.writeAsString('{not json');
    expect(store.read(), throwsA(isA<FormatException>()));
  });

  test('writing preserves keys the plugin does not own', () async {
    await store.file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schema': 1,
        'somethingElse': <String, Object?>{'kept': true},
      }),
    );
    await store.save(
      NeoTopBarConfig.empty.withInstance(
        'tray',
        const NeoModuleInstancePreference(moduleId: 'tray', enabled: false),
      ),
    );
    final raw = await store.readRaw();
    expect(raw['somethingElse'], <String, Object?>{'kept': true});
    expect(
      (raw['instances']! as Map<String, Object?>)['tray'],
      <String, Object?>{'module': 'tray', 'enabled': false},
    );
  });

  test(
    'a malformed file is backed up before the first successful write',
    () async {
      await store.file.writeAsString('{not json');
      await store.save(
        NeoTopBarConfig.empty.withInstance(
          'cpu',
          const NeoModuleInstancePreference(moduleId: 'cpu', enabled: true),
        ),
      );
      expect(await File('${store.file.path}.broken').exists(), isTrue);
      final config = await store.read();
      expect(_firstInstance(config, _cpuDescriptor).enabled, isTrue);
    },
  );

  test(
    'creates the parent directory and leaves no temp files behind',
    () async {
      final nested = NeoTopBarPreferencesStore(
        File('${directory.path}/deep/nested/neo_top_bar.json'),
      );
      await nested.save(
        NeoTopBarConfig.empty.withInstance(
          'tray',
          const NeoModuleInstancePreference(moduleId: 'tray', enabled: false),
        ),
      );
      expect(await nested.file.exists(), isTrue);
      final leftovers = directory
          .listSync(recursive: true)
          .where((entry) => entry.path.contains('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    },
  );

  test('coalesces rapid saves into the newest configuration', () async {
    final first = store.save(
      NeoTopBarConfig.empty.withInstance(
        'tray',
        const NeoModuleInstancePreference(moduleId: 'tray', enabled: false),
      ),
    );
    final second = store.save(
      NeoTopBarConfig.empty.withInstance(
        'cpu',
        const NeoModuleInstancePreference(moduleId: 'cpu', enabled: true),
      ),
    );
    await Future.wait(<Future<void>>[first, second]);
    final config = await store.read();
    // The newest request wins; the intermediate state is not required to be
    // written at all, only that the final file matches the last call.
    expect(_firstInstance(config, _cpuDescriptor).enabled, isTrue);
  });

  test('serializes overlapping writes without losing the last one', () async {
    await Future.wait(<Future<void>>[
      for (var index = 0; index < 8; index++)
        store.save(
          NeoTopBarConfig(
            order: <NeoZone, List<String>>{
              NeoZone.start: <String>['tray', 'workspaces'],
            },
            instances: <String, NeoModuleInstancePreference>{
              'cpu': NeoModuleInstancePreference(
                moduleId: 'cpu',
                enabled: index.isEven,
              ),
            },
          ),
        ),
    ]);
    final config = await store.read();
    expect(config.order[NeoZone.start], <String>['tray', 'workspaces']);
    // Whichever save ran last must be fully present, not a partial merge.
    expect(config.instances.containsKey('cpu'), isTrue);
  });
}

const _cpuDescriptor = NeoModuleDescriptor(
  id: 'cpu',
  label: 'CPU',
  description: '',
  zone: NeoZone.end,
  defaultEnabled: false,
);
