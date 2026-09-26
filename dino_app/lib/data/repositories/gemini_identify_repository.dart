import 'dart:typed_data';

import '../../models/id_result.dart';
import '../../models/pbdb_taxon.dart';
import '../catalog/id_catalog.dart';
import '../services/gemini_vision_service.dart';
import '../services/identification_heuristics.dart';
import '../services/image_compressor.dart';
import '../services/rock_lithology.dart';
import '../services/taxon_fact_mapper.dart';
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
  Future<IdResult> identify(Uint8List bytes, {String? userNotes}) async {
    final jpegBytes = _compressor.forVision(bytes);
    final vision = await _vision.identifyPhoto(
      jpegBytes: jpegBytes,
      catalogGenera: _catalog.genusNames,
      userNotes: userNotes,
    );

    switch (vision.assessment) {
      case IdentifyAssessment.mayNotBeFossil:
        return _rockResult(vision);
      case IdentifyAssessment.uncertain:
        return _uncertainResult(vision);
      case IdentifyAssessment.fossil:
        return _fossilResult(vision);
    }
  }

  IdResult _rockResult(GeminiVisionResult vision) {
    final rockKey = RockLithology.normalize(vision.rockType);
    final rockLabel = RockLithology.displayName(rockKey);
    final confidence = vision.confidence ?? 70;
    return IdResult(
      id: 'rock-$rockKey',
      specimenImage: 'assets/images/fossil_trilobite.png',
      confidenceLabel: IdentificationHeuristics.confidenceLabel(confidence),
      matchLabel: 'May not be a fossil — check details',
      tip: vision.reason?.trim().isNotEmpty == true
          ? vision.reason!.trim()
          : 'This looks like rock or non-biogenic material rather than a fossil.',
      taxonomy: const [],
      candidates: const [],
      facts: [
        TaxonFact(icon: 'public', value: rockLabel, label: 'Likely material'),
        TaxonFact(
          icon: 'straighten',
          value: '$confidence%',
          label: 'Model confidence',
        ),
      ],
      source: IdentificationSource.geminiPbdb,
      assessment: IdentifyAssessment.mayNotBeFossil,
      rockType: rockKey,
      reason: vision.reason,
      pbdbVerified: false,
      primaryConfidence: confidence,
    );
  }

  Future<IdResult> _uncertainResult(GeminiVisionResult vision) async {
    final photoTip = vision.reason?.trim().isNotEmpty == true
        ? vision.reason!.trim()
        : 'Photo quality is too weak for a reliable ID. Retake with sharper '
            'focus, even lighting, and a scale bar.';

    if (vision.candidates.isEmpty) {
      final confidence = vision.confidence ?? 40;
      return IdResult(
        id: 'uncertain',
        specimenImage: 'assets/images/fossil_ammonite.png',
        confidenceLabel: 'LOW CONFIDENCE',
        matchLabel: 'Potential — need more information',
        tip: photoTip,
        taxonomy: const [],
        candidates: const [],
        facts: [
          TaxonFact(
            icon: 'straighten',
            value: '$confidence%',
            label: 'Model confidence',
          ),
        ],
        source: IdentificationSource.geminiPbdb,
        assessment: IdentifyAssessment.uncertain,
        reason: photoTip,
        pbdbVerified: false,
        primaryConfidence: confidence,
      );
    }

    // Provisional genera + photo-quality warning (top match still shown).
    final base = await _buildEnrichedFossilResult(
      vision.candidates,
      assessment: IdentifyAssessment.uncertain,
      matchLabel: 'Potential — provisional best guess',
      tipOverride: photoTip,
      idPrefix: 'uncertain',
    );
    return base;
  }

  Future<IdResult> _fossilResult(GeminiVisionResult vision) async {
    if (vision.candidates.isEmpty) {
      throw GeminiVisionException('No genera returned from vision model.');
    }
    return _buildEnrichedFossilResult(
      vision.candidates,
      assessment: IdentifyAssessment.fossil,
      matchLabel: 'Gemini vision · PBDB double-check',
      tipOverride: null,
      idPrefix: 'live',
    );
  }

  Future<IdResult> _buildEnrichedFossilResult(
    List<GeminiVisionCandidate> rawCandidates, {
    required IdentifyAssessment assessment,
    required String matchLabel,
    required String? tipOverride,
    required String idPrefix,
  }) async {
    final enriched = <_EnrichedCandidate>[];
    for (final raw in rawCandidates.take(3)) {
      PbdbTaxon? pbdb;
      try {
        pbdb = await _taxonRepository.findTaxon(raw.genus);
      } catch (_) {
        pbdb = null;
      }

      final catalogEntry = _catalog.entryFor(raw.genus);
      final pbdbGenusRank =
          pbdb != null && pbdb.rank.toLowerCase() == 'genus';
      final confidence = IdentificationHeuristics.adjustedConfidence(
        modelConfidence: raw.confidence,
        inLocalCatalog: catalogEntry != null,
        pbdbGenusRank: pbdbGenusRank,
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

    enriched.sort(
      (a, b) => b.adjustedConfidence.compareTo(a.adjustedConfidence),
    );
    final best = enriched.first;

    List<String> taxonomy = best.catalog?.taxonomy ?? [];
    if (taxonomy.isEmpty && best.pbdb != null) {
      try {
        final chain = await _taxonRepository.getTimelineChain(best.genus);
        taxonomy = TaxonFactMapper.taxonomyLabelsFromChain(chain);
      } catch (_) {
        taxonomy = const [];
      }
    }

    final facts = _buildFacts(best);
    final tip = tipOverride ??
        IdentificationHeuristics.doubleCheckNote(
          modelConfidence: best.modelConfidence,
          inPbdb: best.pbdb != null,
          inLocalCatalog: best.catalog != null,
          pbdbOccurrences: best.pbdb?.occurrenceCount,
        );

    final potential = best.adjustedConfidence < IdentificationHeuristics.boostFloor ||
        best.modelConfidence < IdentificationHeuristics.boostFloor ||
        assessment == IdentifyAssessment.uncertain;
    final resolvedLabel = potential && assessment == IdentifyAssessment.fossil
        ? 'Potential match — needs more information'
        : matchLabel;

    return IdResult(
      id: '$idPrefix-${best.genus.toLowerCase()}',
      specimenImage:
          best.catalog?.specimenImage ?? 'assets/images/fossil_ammonite.png',
      confidenceLabel:
          IdentificationHeuristics.confidenceLabel(best.adjustedConfidence),
      matchLabel: resolvedLabel,
      tip: tip,
      taxonomy: taxonomy,
      timelineLabel: best.pbdb?.ageRangeLabel,
      pbdbVerified: best.pbdb != null,
      source: IdentificationSource.geminiPbdb,
      assessment: assessment,
      reason: tipOverride,
      primaryConfidence: best.adjustedConfidence,
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

  List<TaxonFact> _buildFacts(_EnrichedCandidate best) {
    final facts = <TaxonFact>[];

    if (best.pbdb != null) {
      facts.addAll(TaxonFactMapper.factsFromTaxon(best.pbdb!, maxFacts: 2));
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
