import 'package:dino_app/data/services/identification_heuristics.dart';
import 'package:dino_app/data/services/rock_lithology.dart';
import 'package:dino_app/data/services/taxon_fact_mapper.dart';
import 'package:dino_app/models/pbdb_taxon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaxonFactMapper', () {
    test('taxonomyLabelsFromChain skips root noise and keeps tip ranks', () {
      final chain = [
        const PbdbTaxon(name: 'Life', rank: 'unranked clade'),
        const PbdbTaxon(name: 'Mollusca', rank: 'phylum'),
        const PbdbTaxon(name: 'Cephalopoda', rank: 'class'),
        const PbdbTaxon(name: 'Ammonoidea', rank: 'subclass'),
        const PbdbTaxon(name: 'Dactylioceras', rank: 'genus'),
      ];
      final labels = TaxonFactMapper.taxonomyLabelsFromChain(chain);
      expect(labels, isNot(contains('Life')));
      expect(labels.last, 'Dactylioceras');
      expect(labels.length, lessThanOrEqualTo(4));
    });

    test('factsFromTaxon maps age and occurrence count', () {
      const taxon = PbdbTaxon(
        name: 'Dactylioceras',
        rank: 'genus',
        firstInterval: 'Hettangian',
        lastInterval: 'Bajocian',
        occurrenceCount: 496,
      );
      final facts = TaxonFactMapper.factsFromTaxon(taxon);
      expect(facts, isNotEmpty);
      expect(facts.any((f) => f.label == 'PBDB range'), isTrue);
      expect(facts.any((f) => f.value == '496'), isTrue);
    });
  });

  group('IdentificationHeuristics', () {
    test('does not boost below 60% even with catalog and PBDB signals', () {
      final score = IdentificationHeuristics.adjustedConfidence(
        modelConfidence: 35,
        inLocalCatalog: true,
        pbdbGenusRank: true,
        pbdbOccurrences: 457,
      );
      expect(score, 35);
    });

    test('applies soft corroboration boosts at or above 60%', () {
      final score = IdentificationHeuristics.adjustedConfidence(
        modelConfidence: 70,
        inLocalCatalog: true,
        pbdbGenusRank: true,
        pbdbOccurrences: 150,
      );
      // 70 + 3 catalog + 2 genus rank + 3 occ = 78
      expect(score, 78);
    });

    test('name-in-PBDB alone is not a boost (pbdbGenusRank false)', () {
      final score = IdentificationHeuristics.adjustedConfidence(
        modelConfidence: 70,
        inLocalCatalog: false,
        pbdbGenusRank: false,
        pbdbOccurrences: null,
      );
      expect(score, 70);
    });

    test('doubleCheckNote is provisional below boost floor', () {
      final note = IdentificationHeuristics.doubleCheckNote(
        modelConfidence: 35,
        inPbdb: true,
        inLocalCatalog: true,
        pbdbOccurrences: 100,
      );
      expect(note.toLowerCase(), contains('provisional'));
      expect(note.toLowerCase(), isNot(contains('verified against')));
    });
  });

  group('RockLithology', () {
    test('normalizes synonyms onto the fixed list', () {
      expect(RockLithology.normalize('Conglomerate'), 'conglomerate');
      expect(RockLithology.normalize('pebble conglomerate'), 'conglomerate');
      expect(RockLithology.normalize('flint'), 'chert');
      expect(RockLithology.normalize('mystery stone'), 'other_rock');
    });

    test('displayName uses friendly labels', () {
      expect(RockLithology.displayName('other_rock'), 'Other rock / material');
      expect(RockLithology.displayName('sandstone'), 'Sandstone');
    });
  });
}
