import 'dart:typed_data';

import '../../models/id_result.dart';
import '../../models/pbdb_taxon.dart';
import '../catalog/id_catalog.dart';
import '../services/gemini_vision_service.dart';
import '../services/identification_heuristics.dart';
import '../services/image_compressor.dart';
import 'identify_repository.dart';
import 'taxon_repository.dart';

/// Gemini vision + PBDB enrichment, grounded on the local id_results catalog.
class GeminiIdentifyRepository implements IdentifyRepository {
  GeminiIdentifyRepository({
    required GeminiVisionService vision,
    required TaxonRepository taxonRepository,
    required IdCatalog catalog,
    MockIdentifyRepository? fallback,
    ImageCompressor? compressor,
  })  : _vision = vision,
        _taxonRepository = taxonRepository,
        _catalog = catalog,
        _fallback = fallback ?? MockIdentifyRepository(),
        _compressor = compressor ?? const ImageCompressor();

  final GeminiVisionService _vision;
  final TaxonRepository _taxonRepository;
  final IdCatalog _catalog;
  final MockIdentifyRepository _fallback;
  final ImageCompressor _compressor;

  @override
  Future<IdResult> getMockResult(String imageId) {
    return _fallback.getMockResult(imageId);
  }

  @override
  Future<IdResult> identify(Uint8List bytes) async {
    final jpegBytes = _compressor.forVision(bytes);
    final rawCandidates = await _vision.identifyGenera(
      jpegBytes: jpegBytes,
      catalogGenera: _catalog.genusNames,
    );

    if (rawCandidates.isEmpty) {
      throw GeminiVisionException('No genera returned from vision model.');
    }

    final enriched = <_EnrichedCandidate>[];
    for (final raw in rawCandidates.take(3)) {
      PbdbTaxon? pbdb;
      try {
        pbdb = await _taxonRepository.findTaxon(raw.genus);
      } catch (_) {
        pbdb = null;
      }

      final catalogEntry = _catalog.entryFor(raw.genus);
      final confidence = IdentificationHeuristics.adjustedConfidence(
        modelConfidence: raw.confidence,
        inLocalCatalog: catalogEntry != null,
        inPbdb: pbdb != null,
        pbdbOccurrences: pbdb?.occurrenceCount,
      );

      enriched.add(
        _EnrichedCandidate(
          genus: raw.genus,
          modelConfidence: raw.confidence,
          adjustedConfidence: confidence,
          catalog: catalogEntry,
          pbdb: pbdb,
        ),
      );
    }

    enriched.sort((a, b) => b.adjustedConfidence.compareTo(a.adjustedConfidence));
    final best = enriched.first;

    List<String> taxonomy = best.catalog?.taxonomy ?? [];
    if (taxonomy.isEmpty && best.pbdb != null) {
      try {
        final chain = await _taxonRepository.getTimelineChain(best.genus);
        taxonomy = _taxonomyFromChain(chain);
      } catch (_) {
        taxonomy = const [];
      }
    }

    final facts = _buildFacts(best);
    final tip = IdentificationHeuristics.verificationNote(
      inPbdb: best.pbdb != null,
      inLocalCatalog: best.catalog != null,
      pbdbOccurrences: best.pbdb?.occurrenceCount,
    );

    return IdResult(
      id: 'live-${best.genus.toLowerCase()}',
      specimenImage:
          best.catalog?.specimenImage ?? 'assets/images/fossil_ammonite.png',
      confidenceLabel:
          IdentificationHeuristics.confidenceLabel(best.adjustedConfidence),
      matchLabel: 'Gemini vision · PBDB-enriched match',
      tip: tip,
      taxonomy: taxonomy,
      timelineLabel: best.pbdb?.ageRangeLabel,
      pbdbVerified: best.pbdb != null,
      source: IdentificationSource.geminiPbdb,
      candidates: [
        for (var i = 0; i < enriched.length; i++)
          IdCandidate(
            genus: enriched[i].genus,
            commonGroup: enriched[i].catalog?.commonGroup ??
                enriched[i].pbdb?.rank ??
                'Fossil',
            family: enriched[i].catalog?.family ??
                (enriched[i].pbdb?.attribution ?? 'Unknown'),
            confidence: enriched[i].adjustedConfidence,
            modelConfidence: enriched[i].modelConfidence,
            thumbnail: enriched[i].catalog?.thumbnail ??
                'assets/images/fossil_ammonite.png',
            isBestMatch: i == 0,
          ),
      ],
      facts: facts,
    );
  }

  List<String> _taxonomyFromChain(List<PbdbTaxon> chain) {
    const skip = {'Life', 'Eucarya', 'Opisthokonta'};
    final names = chain
        .map((t) => t.name)
        .where((name) => !skip.contains(name))
        .toList();
    if (names.length <= 4) return names;
    return names.sublist(names.length - 4);
  }

  List<TaxonFact> _buildFacts(_EnrichedCandidate best) {
    final facts = <TaxonFact>[];

    if (best.pbdb != null) {
      facts.add(
        TaxonFact(
          icon: 'schedule',
          value: best.pbdb!.ageRangeLabel,
          label: 'PBDB range',
        ),
      );
      if (best.pbdb!.occurrenceCount != null) {
        facts.add(
          TaxonFact(
            icon: 'public',
            value: '${best.pbdb!.occurrenceCount}',
            label: 'PBDB records',
          ),
        );
      }
    } else if (best.catalog != null && best.catalog!.facts.isNotEmpty) {
      facts.add(best.catalog!.facts.first);
    }

    facts.add(
      TaxonFact(
        icon: 'straighten',
        value: '${best.modelConfidence}%',
        label: 'Raw AI score',
      ),
    );

    if (best.catalog != null) {
      for (final fact in best.catalog!.facts) {
        if (facts.length >= 3) break;
        if (facts.any((f) => f.label == fact.label)) continue;
        facts.add(fact);
      }
    }

    while (facts.length < 3 && best.catalog != null) {
      for (final fact in best.catalog!.facts) {
        if (facts.length >= 3) break;
        if (!facts.contains(fact)) facts.add(fact);
      }
      break;
    }

    return facts.take(3).toList();
  }
}

class _EnrichedCandidate {
  const _EnrichedCandidate({
    required this.genus,
    required this.modelConfidence,
    required this.adjustedConfidence,
    required this.catalog,
    required this.pbdb,
  });

  final String genus;
  final int modelConfidence;
  final int adjustedConfidence;
  final IdCatalogEntry? catalog;
  final PbdbTaxon? pbdb;
}
