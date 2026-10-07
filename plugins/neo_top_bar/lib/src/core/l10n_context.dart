/// The `BuildContext` half of the string catalogue.
///
/// `l10n.dart` holds the words and stays free of Flutter so the pure logic can
/// depend on it; this file is the two lines that need a widget tree. Splitting
/// them is what lets `neo_top_bar_logic.dart` run under plain `dart test`.
library;

import 'package:flutter/widgets.dart';

import 'l10n.dart';

/// The language Denial is running in, as seen from [context].
///
/// Denial's shell installs a `Localizations` scope around the whole surface, and
/// the locale it resolved — the user's explicit choice, or the platform's — is
/// what this reads. A context outside that scope reads as null rather than
/// throwing, which is what makes a bare widget test work.
NeoLanguage neoLanguageOf(BuildContext context) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode;
  return code == null ? neoFallbackLanguage : neoLanguageFromCode(code);
}

/// The string catalogue for the language Denial is running in.
NeoStrings neoStringsOf(BuildContext context) =>
    NeoStrings(neoLanguageOf(context));

/// The catalogue for a bare language code, for callers that have no context.
///
/// Null falls back rather than guessing, so a settings object built before a
/// locale is known still reads as one language for the whole build.
NeoStrings neoStringsFor(String? languageCode) => languageCode == null
    ? const NeoStrings(neoFallbackLanguage)
    : NeoStrings(neoLanguageFromCode(languageCode));

/// Shorthand for the case that only needs one or two phrases.
extension NeoStringsBuildContext on BuildContext {
  /// The catalogue for the language Denial is running in.
  NeoStrings get neoStrings => neoStringsOf(this);
}
