import '../models/milestone_model.dart';
import '../providers/game_state.dart';

class MilestoneService {
  // This would eventually be loaded from your database/backend
  List<Milestone> getHardcodedMilestones() {
    return [
      Milestone(id: 'rename_company', title: 'Corporate Identity', description: 'First company to rename themselves'),
      Milestone(id: 'solars_10m', title: 'Deca-Millionaire', description: 'First company to be worth 10 million solars'),
      Milestone(id: 'solars_50m', title: 'Centurion Club', description: 'First company to be worth 50 million solars'),
      Milestone(id: 'contracts_1000', title: 'Logistics Legend', description: 'First company to complete 1000 shipping contracts'),
      Milestone(id: 'tier5_mule', title: 'Heavy Hauler Expert', description: 'First company to have a Tier 5 Mule'),
      Milestone(id: 'tier5_sprinter', title: 'Void Racer', description: 'First company to have a Tier 5 Sprinter'),
      Milestone(id: 'tier5_miner', title: 'Core Stripper', description: 'First company to have a Tier 5 Miner'),
      Milestone(id: 'tier5_tanker', title: 'Gas Giant', description: 'First company to have a Tier 5 Tanker'),
      Milestone(id: 'tier5_harvester', title: 'Rift Walker', description: 'First company to have a Tier 5 Harvester'),
      Milestone(id: 'all_tier5', title: 'Fleet Master', description: 'First company to have a Tier 5 ship of every class'),
      Milestone(id: 'dist_30au', title: 'Long Haul Hero', description: 'First company to complete a contract of over 30 AU'),
      Milestone(id: 'ore_5000', title: 'Mineral Mogul', description: 'First company to mine 5000 m3 of Ore'),
      Milestone(id: 'gas_5000', title: 'Atmospheric Tycoon', description: 'First company to bring in 5000 m3 of Gas'),
      Milestone(id: 'crystals_5000', title: 'Resonance King', description: 'First company to harvest 5000 m3 of Crystals'),
      Milestone(id: 'max_base', title: 'Command Center', description: 'First company to Max out base upgrades'),
    ];
  }

  /// The logic "Ping" - Call this whenever a major action happens
  void checkForNewClaims(GameState state, List<Milestone> currentMilestones) {
    // Note: In a real multiplayer scenario, this would be a server-side check.
    // For now, we'll outline the logic that triggers a "Claim" request.

    for (var milestone in currentMilestones) {
      if (milestone.isClaimed) continue; // Skip if already won

      bool requirementMet = false;

      switch (milestone.id) {
        case 'rename_company':
          // Assuming default is "New Company" or empty
          if (state.companyName != "New Company" && state.companyName.isNotEmpty) requirementMet = true;
          break;
        case 'solars_10m':
          if (state.solars >= 10000000) requirementMet = true;
          break;
        case 'contracts_1000':
          // You'll need a counter in GameState for total missions
          // if (state.totalMissionsCompleted >= 1000) requirementMet = true;
          break;
        case 'max_base':
          // Checks all three upgrade tracks against their max level (5)
          if (state.relayLevel >= 5 && state.broadcastingLevel >= 5 && state.tradeDepotLevel >= 5) requirementMet = true;
          break;
        // ... add cases for Tier 5 checks and resource totals
      }

      if (requirementMet) {
        _claimMilestone(milestone.id, state.companyName);
      }
    }
  }

  void _claimMilestone(String id, String companyName) {
    // This is where you'd call your Firestore/Backend to lock in the win
    print("LOG: $companyName is claiming $id!");
  }
}