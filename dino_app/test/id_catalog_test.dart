import 'package:dino_app/data/catalog/id_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IdCatalog.load', () {
    late IdCatalog catalog;

    setUpAll(() async {
      catalog = await IdCatalog.load();
    });

    test('indexes at least 20 curated genera', () {
      expect(catalog.genusNames.length, greaterThanOrEqualTo(20));
    });

    test('entryFor Dactylioceras is non-null with coherent metadata', () {
      final entry = catalog.entryFor('Dactylioceras');
      expect(entry, isNotNull);
      expect(entry!.genus, 'Dactylioceras');
      expect(entry.commonGroup, isNotEmpty);
      expect(entry.family, isNotEmpty);
      expect(entry.thumbnail, isNotEmpty);
      expect(entry.specimenImage, isNotEmpty);
      expect(entry.taxonomy, isNotEmpty);
      expect(entry.facts, isNotEmpty);
    });

    test('genusNames covers multiple fossil groups', () {
      final names = catalog.genusNames;
      expect(names, contains('Dactylioceras'));
      expect(names, contains('Elrathia'));
      expect(names, contains('Glossopteris'));
      expect(names, contains('Tyrannosaurus'));
      expect(names, contains('Mucrospirifer'));
      expect(names, contains('Favosites'));
    });
  });
}
