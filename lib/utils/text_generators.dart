import 'dart:math';

class TextGenerators {
  static String generateCompanyName() {
    final List<String> adjectives = [
      "Heavy", "Deep", "Interstellar", "Prime", "Apex", "Vanguard", "Bulk",
      "Stellar", "Void", "Infinite", "Solar", "Divine", "Rusty", "Frontier",
      "Nebular", "Titan", "Core", "Iron", "Cobalt", "Graviton"
    ];

    final List<String> nouns = [
      "Freight", "Haulage", "Cargo", "Transit", "Relay", "Extraction",
      "Mineral", "Ore", "Orbit", "Voyager", "Asteroid", "Nebula", "Comet",
      "Forge", "Vector", "Drift", "Logistics", "Shipping", "Transport"
    ];

    final List<String> businessWords = [
      "Inc.", "Enterprises", "LLC", "Corp", "Solutions", "Group",
      "Logistics", "Consolidated", "Ventures", "Systems", "Combine",
      "Syndicate", "United", "Limited", "Dynamics"
    ];

    final random = Random();
    String adj = adjectives[random.nextInt(adjectives.length)];
    String noun = nouns[random.nextInt(nouns.length)];
    String selectedBiz = businessWords[random.nextInt(businessWords.length)];

    return "$adj $noun $selectedBiz";
  }
}