class Mission {
  final String id;
  final String title;
  final String description;
  final String requiredClass;
  
  final double distanceAU;
  final int minShieldLevel;
  final int minCargo;
  
  final int rewardSolars; // Direct cash payment (Delivery contracts)
  final String? rewardResource; // "Ore", "Gas", "Crystals" (Mining/Harvesting)
  final int rewardResourceAmount; 

  final int baseDurationMinutes;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredClass,
    required this.distanceAU,
    required this.minShieldLevel,
    required this.minCargo,
    required this.rewardSolars,
    this.rewardResource,
    this.rewardResourceAmount = 0,
    required this.baseDurationMinutes,
  });

  // This is the logic your Mission Board uses to enable/disable the Launch button
  String? getMissingRequirement(dynamic ship) {
    if (ship.shipClass != requiredClass) return "Needs $requiredClass class";
    if ((ship.fuelCapacity * 10) < distanceAU) return "Insufficient Fuel Range";
    if (ship.shieldLevel < minShieldLevel) return "Shields too weak";
    if (ship.cargoCapacity < minCargo) return "Cargo bay too small";
    if (ship.condition < 0.25) return "Ship requires repairs";
    return null; 
  }
}
