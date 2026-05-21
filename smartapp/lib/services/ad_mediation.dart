// Mediation adapter plugins register native SDKs at build time.
// These imports keep the federated plugins linked in release builds.
import 'package:gma_mediation_liftoffmonetize/gma_mediation_liftoffmonetize.dart';
import 'package:gma_mediation_meta/gma_mediation_meta.dart';
import 'package:gma_mediation_mintegral/gma_mediation_mintegral.dart';

/// Ensures AdMob mediation adapter packages are linked into the app.
void ensureMediationAdaptersLinked() {
  // References prevent tree-shaking from dropping unused plugin registrations.
  final adapters = <Object>[
    GmaMediationMeta(),
    GmaMediationLiftoffmonetize(),
    GmaMediationMintegral(),
  ];
  assert(adapters.isNotEmpty);
}
