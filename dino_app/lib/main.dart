import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/strata_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StrataServices.init();
  runApp(StrataApp());
}
