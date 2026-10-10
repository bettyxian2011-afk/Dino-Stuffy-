import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dino_app/data/catalog/id_catalog.dart';
import 'package:dino_app/data/catalog/knowledge_assets.dart';
import 'package:dino_app/models/fossil_taxon.dart';
import 'package:dino_app/models/geologic_period.dart';
import 'package:dino_app/models/red_list_species.dart';
import 'package:dino_app/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled periods', () {
    late List<GeologicPeriod> periods;

    setUpAll(() async {
      periods = await KnowledgeAssets.loadPeriods();
    });

    test('covers the 12 Phanerozoic periods, Cambrian first', () {
      expect(periods, hasLength(12));
      expect(periods.first.id, 'cambrian');
      expect(periods.last.id, 'quaternary');
      expect(periods.last.endMa, 0);
    });

    test('periods are contiguous with no gaps or overlaps', () {
      for (var i = 0; i < periods.length - 1; i++) {
        expect(periods[i].endMa, periods[i + 1].startMa,
            reason: '${periods[i].name} → ${periods[i + 1].name}');
      }
    });

    test('Cretaceous is Mesozoic and has a blurb', () {
      final cretaceous = periods.singleWhere((p) => p.id == 'cretaceous');
      expect(cretaceous.era, GeologicEra.mesozoic);
      expect(cretaceous.endMa, 66);
      expect(cretaceous.blurb, isNotEmpty);
    });
  });

  group('bundled taxa', () {
    late Map<String, FossilTaxon> taxa;
    late IdCatalog catalog;
    late Set<String> periodIds;

    setUpAll(() async {
      taxa = await KnowledgeAssets.loadTaxa();
      catalog = await IdCatalog.load();
      periodIds = (await KnowledgeAssets.loadPeriods()).map((p) => p.id).toSet();
    });

    test('every Identify catalog genus has a taxon used by Identify', () {
      for (final genus in catalog.genusNames) {
        final taxon = taxa[genus.toLowerCase()];
        expect(taxon, isNotNull, reason: genus);
        expect(taxon!.scientificName, genus);
        expect(taxon.useInIdentify, isTrue, reason: genus);
        expect(taxon.commonGroup, catalog.entryFor(genus)!.commonGroup);
        expect(taxon.family, catalog.entryFor(genus)!.family);
      }
    });

    test('the five Cretaceous demo dinosaurs are iconic land taxa', () {
      for (final id in [
        'triceratops',
        'velociraptor',
        'tyrannosaurus',
        'pachycephalosaurus',
        'ankylosaurus',
      ]) {
        final taxon = taxa[id];
        expect(taxon, isNotNull, reason: id);
        expect(taxon!.realm, TaxonRealm.land, reason: id);
        expect(taxon.periodIds, contains('cretaceous'), reason: id);
        expect(taxon.iconic, isTrue, reason: id);
      }
    });

    test('every taxon points at known periods and cites PBDB', () {
      for (final taxon in taxa.values) {
        expect(taxon.periodIds, isNotEmpty, reason: taxon.id);
        expect(periodIds.containsAll(taxon.periodIds), isTrue, reason: taxon.id);
        expect(taxon.pbdb?.taxonNo, startsWith('txn:'), reason: taxon.id);
        expect(taxon.facts, isNotEmpty, reason: taxon.id);
      }
    });
  });

  group('JSON round trips', () {
    test('FossilTaxon', () async {
      final taxon = (await KnowledgeAssets.loadTaxa())['dactylioceras']!;
      final copy = FossilTaxon.fromJson(taxon.id, taxon.toJson());
      expect(copy.toJson(), taxon.toJson());
    });

    test('GeologicPeriod', () async {
      final period = (await KnowledgeAssets.loadPeriods()).first;
      final copy = GeologicPeriod.fromJson(period.id, period.toJson());
      expect(copy.toJson(), period.toJson());
    });

    test('UserProfile defaults to a standard account', () {
      final created = DateTime.utc(2026, 10, 10);
      final profile = UserProfile.fromJson('uid-1', {
        'displayName': 'Betty',
        'createdAt': Timestamp.fromDate(created),
        'friendCode': 'ABC123',
      });
      expect(profile.accountKind, AccountKind.standard);
      expect(profile.badgeCount, 0);
      expect(profile.createdAt.isAtSameMomentAs(created), isTrue);

      final copy = UserProfile.fromJson('uid-1', profile.toJson());
      expect(copy.toJson(), profile.toJson());
    });

    test('RedListSpecies', () {
      final species = RedListSpecies.fromJson('axolotl', {
        'commonName': 'Axolotl',
        'scientificName': 'Ambystoma mexicanum',
        'status': 'CR',
        'habitat': 'Lake Xochimilco canals, Mexico',
        'imageAsset': 'assets/images/axolotl.png',
      });
      expect(species.status, IucnStatus.criticallyEndangered);
      expect(species.kidSafe, isFalse);

      final copy = RedListSpecies.fromJson(species.id, species.toJson());
      expect(copy.toJson(), species.toJson());
    });
  });
}
