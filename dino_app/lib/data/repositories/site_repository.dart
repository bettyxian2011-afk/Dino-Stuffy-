import '../../models/geological_site.dart';

abstract class SiteRepository {
  GeologicalSite? getNearYou();
}

class MockSiteRepository implements SiteRepository {
  const MockSiteRepository();

  @override
  GeologicalSite? getNearYou() => const GeologicalSite(
        id: 'hell-creek',
        headline: '3 fossil-bearing sites within 40 mi',
        formation: 'Hell Creek Fm',
        stage: 'Maastrichtian',
        ageMa: 66,
        siteCount: 3,
        radiusMiles: 40,
        imageAsset: 'assets/images/near_you_site.png',
      );
}
