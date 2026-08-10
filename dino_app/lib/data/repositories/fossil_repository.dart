import '../../models/fossil_match.dart';

abstract class FossilRepository {
  List<FossilMatch> getRecentMatches();
}

class MockFossilRepository implements FossilRepository {
  const MockFossilRepository();

  @override
  List<FossilMatch> getRecentMatches() => const [
        FossilMatch(
          id: 'velo-1',
          speciesName: 'Velociraptor',
          era: 'Cretaceous',
          ageMa: 75,
          confidence: 92,
          imageAsset: 'assets/images/fossil_velociraptor.png',
        ),
        FossilMatch(
          id: 'dact-1',
          speciesName: 'Dactylioceras',
          era: 'Jurassic',
          ageMa: 180,
          confidence: 88,
          imageAsset: 'assets/images/fossil_ammonite.png',
        ),
        FossilMatch(
          id: 'tri-1',
          speciesName: 'Elrathia',
          era: 'Cambrian',
          ageMa: 500,
          confidence: 81,
          imageAsset: 'assets/images/fossil_trilobite.png',
        ),
      ];
}
