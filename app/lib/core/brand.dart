/// Product identity. Change the name here and in `config.app` (database) to rebrand.
class Brand {
  Brand._();
  static const name = 'Flying Cobra';
  static const tagline = 'Run. Collect. Keep.';
  static const promise = 'Run. Get an animal. Collect India.';
  static const defaultTimezone = 'Asia/Kolkata';
  static const serialPad = 4;

  /// Typeface controller (design_system/tokens.json → typography.typefaces). 'satoshi' is bundled; 'classic'
  /// (Fraunces + Manrope, the pair used before 2 Oct 2026) is reserved and loads via google_fonts when selected.
  static const typeface = 'satoshi';
}
