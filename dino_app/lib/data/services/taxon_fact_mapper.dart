import '../../models/id_result.dart';
import '../../models/pbdb_taxon.dart';

/// Maps Paleobiology Database records into Strata UI facts / taxonomy chips.
class TaxonFactMapper {
  const TaxonFactMapper._();

  static const _skipChainNames = {
    'Life',
    'Eucarya',
    'Opisthokonta',
  };

  /// Last few meaningful ranks from a PBDB parent chain (root → tip).
  static List<String> taxonomyLabelsFromChain(
    List<PbdbTaxon> chain, {
    int maxLabels = 4,
  }) {
    final names = chain
        .map((t) => t.name.trim())
        .where((name) => name.isNotEmpty && !_skipChainNames.contains(name))
        .toList();
    if (names.isEmpty) return const [];
    if (names.length <= maxLabels) return names;
    return names.sublist(names.length - maxLabels);
  }

  /// Quick-facts for ID Result / profile when catalog facts are missing.
  static List<TaxonFact> factsFromTaxon(
    PbdbTaxon taxon, {
    int maxFacts = 3,
  }) {
    final facts = <TaxonFact>[];

    if (taxon.ageRangeLabel != 'Age unknown') {
      facts.add(
        TaxonFact(
          icon: 'schedule',
          value: taxon.ageRangeLabel,
          label: 'PBDB range',
        ),
      );
    }

    final count = taxon.occurrenceCount;
    if (count != null) {
      facts.add(
        TaxonFact(
          icon: 'public',
          value: '$count',
          label: 'PBDB records',
        ),
      );
    }

    if (taxon.rank.isNotEmpty && taxon.rank != 'unknown') {
      facts.add(
        TaxonFact(
          icon: 'straighten',
          value: _titleCase(taxon.rank),
          label: 'Taxon rank',
        ),
      );
    }

    return facts.take(maxFacts).toList();
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
