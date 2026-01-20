class ShipTemplate {
  final String shipClass;
  final String modelName;
  final int price;
  final int baseSpeed;
  final int maxSpeed;
  final int baseCargo;
  final int maxCargo;
  final int baseFuel;
  final int maxFuel;
  final int baseShield;
  final int maxShield;
  final int baseAI;
  final int maxAI;

  const ShipTemplate({
    required this.shipClass,
    required this.modelName,
    required this.price,
    required this.baseSpeed,
    required this.maxSpeed,
    required this.baseCargo,
    required this.maxCargo,
    required this.baseFuel,
    required this.maxFuel,
    required this.baseShield,
    required this.maxShield,
    required this.baseAI,
    required this.maxAI,
  });

  static const List<ShipTemplate> all = [
    // MULE CLASS
    ShipTemplate(shipClass: "Mule", modelName: "Rusty Tug", price: 1000, baseSpeed: 2, maxSpeed: 4, baseCargo: 4, maxCargo: 6, baseFuel: 3, maxFuel: 5, baseShield: 1, maxShield: 3, baseAI: 1, maxAI: 2),
    ShipTemplate(shipClass: "Mule", modelName: "Iron Snail", price: 4500, baseSpeed: 3, maxSpeed: 5, baseCargo: 5, maxCargo: 7, baseFuel: 4, maxFuel: 6, baseShield: 2, maxShield: 4, baseAI: 2, maxAI: 3),
    ShipTemplate(shipClass: "Mule", modelName: "Bulk Carrier", price: 12000, baseSpeed: 3, maxSpeed: 6, baseCargo: 7, maxCargo: 9, baseFuel: 5, maxFuel: 7, baseShield: 3, maxShield: 5, baseAI: 3, maxAI: 4),
    ShipTemplate(shipClass: "Mule", modelName: "Solar Whale", price: 28000, baseSpeed: 3, maxSpeed: 5, baseCargo: 9, maxCargo: 12, baseFuel: 6, maxFuel: 8, baseShield: 4, maxShield: 6, baseAI: 4, maxAI: 5),
    ShipTemplate(shipClass: "Mule", modelName: "Titan Hauler", price: 65000, baseSpeed: 4, maxSpeed: 6, baseCargo: 12, maxCargo: 18, baseFuel: 7, maxFuel: 10, baseShield: 5, maxShield: 8, baseAI: 5, maxAI: 7),
    
    // SPRINTER CLASS
    ShipTemplate(shipClass: "Sprinter", modelName: "Dart", price: 1200, baseSpeed: 5, maxSpeed: 7, baseCargo: 1, maxCargo: 2, baseFuel: 4, maxFuel: 6, baseShield: 1, maxShield: 2, baseAI: 2, maxAI: 4),
    ShipTemplate(shipClass: "Sprinter", modelName: "Comet", price: 5500, baseSpeed: 7, maxSpeed: 9, baseCargo: 1, maxCargo: 2, baseFuel: 5, maxFuel: 7, baseShield: 2, maxShield: 3, baseAI: 3, maxAI: 5),
    ShipTemplate(shipClass: "Sprinter", modelName: "Silver Streak", price: 15000, baseSpeed: 8, maxSpeed: 10, baseCargo: 2, maxCargo: 3, baseFuel: 6, maxFuel: 8, baseShield: 3, maxShield: 4, baseAI: 4, maxAI: 6),
    ShipTemplate(shipClass: "Sprinter", modelName: "Velocity", price: 35000, baseSpeed: 9, maxSpeed: 10, baseCargo: 2, maxCargo: 4, baseFuel: 7, maxFuel: 9, baseShield: 4, maxShield: 5, baseAI: 6, maxAI: 8),
    ShipTemplate(shipClass: "Sprinter", modelName: "Warp Shadow", price: 75000, baseSpeed: 10, maxSpeed: 12, baseCargo: 3, maxCargo: 5, baseFuel: 8, maxFuel: 11, baseShield: 5, maxShield: 7, baseAI: 8, maxAI: 10),

    // TANKER CLASS
    ShipTemplate(shipClass: "Tanker", modelName: "Fuel Buoy", price: 3000, baseSpeed: 2, maxSpeed: 4, baseCargo: 2, maxCargo: 3, baseFuel: 6, maxFuel: 8, baseShield: 2, maxShield: 4, baseAI: 2, maxAI: 3),
    ShipTemplate(shipClass: "Tanker", modelName: "Gas Giant", price: 8000, baseSpeed: 3, maxSpeed: 5, baseCargo: 3, maxCargo: 4, baseFuel: 7, maxFuel: 9, baseShield: 3, maxShield: 5, baseAI: 3, maxAI: 4),
    ShipTemplate(shipClass: "Tanker", modelName: "Deep Oiler", price: 18000, baseSpeed: 4, maxSpeed: 6, baseCargo: 4, maxCargo: 5, baseFuel: 8, maxFuel: 10, baseShield: 4, maxShield: 6, baseAI: 4, maxAI: 5),
    ShipTemplate(shipClass: "Tanker", modelName: "Voyager", price: 42000, baseSpeed: 5, maxSpeed: 7, baseCargo: 5, maxCargo: 7, baseFuel: 9, maxFuel: 12, baseShield: 5, maxShield: 7, baseAI: 5, maxAI: 7),
    ShipTemplate(shipClass: "Tanker", modelName: "Infinite Reach", price: 90000, baseSpeed: 6, maxSpeed: 8, baseCargo: 6, maxCargo: 8, baseFuel: 10, maxFuel: 14, baseShield: 7, maxShield: 9, baseAI: 6, maxAI: 8),

    // MINER CLASS
    ShipTemplate(shipClass: "Miner", modelName: "Gravel Picker", price: 5000, baseSpeed: 2, maxSpeed: 4, baseCargo: 3, maxCargo: 5, baseFuel: 3, maxFuel: 5, baseShield: 4, maxShield: 6, baseAI: 2, maxAI: 4),
    ShipTemplate(shipClass: "Miner", modelName: "Rock Biter", price: 12500, baseSpeed: 3, maxSpeed: 5, baseCargo: 4, maxCargo: 6, baseFuel: 4, maxFuel: 6, baseShield: 5, maxShield: 7, baseAI: 3, maxAI: 5),
    ShipTemplate(shipClass: "Miner", modelName: "Ore Hound", price: 25000, baseSpeed: 4, maxSpeed: 6, baseCargo: 5, maxCargo: 7, baseFuel: 5, maxFuel: 7, baseShield: 6, maxShield: 8, baseAI: 4, maxAI: 6),
    ShipTemplate(shipClass: "Miner", modelName: "Asteroid Eater", price: 55000, baseSpeed: 5, maxSpeed: 7, baseCargo: 6, maxCargo: 9, baseFuel: 6, maxFuel: 8, baseShield: 8, maxShield: 10, baseAI: 5, maxAI: 7),
    ShipTemplate(shipClass: "Miner", modelName: "Core Driller", price: 110000, baseSpeed: 6, maxSpeed: 8, baseCargo: 8, maxCargo: 12, baseFuel: 7, maxFuel: 10, baseShield: 10, maxShield: 14, baseAI: 7, maxAI: 9),

    // HARVESTER CLASS
    ShipTemplate(shipClass: "Harvester", modelName: "Rift Skimmer", price: 15000, baseSpeed: 4, maxSpeed: 6, baseCargo: 2, maxCargo: 3, baseFuel: 4, maxFuel: 6, baseShield: 4, maxShield: 6, baseAI: 5, maxAI: 7),
    ShipTemplate(shipClass: "Harvester", modelName: "Soul Beacon", price: 35000, baseSpeed: 5, maxSpeed: 7, baseCargo: 3, maxCargo: 4, baseFuel: 5, maxFuel: 7, baseShield: 5, maxShield: 7, baseAI: 7, maxAI: 9),
    ShipTemplate(shipClass: "Harvester", modelName: "Void Weaver", price: 80000, baseSpeed: 6, maxSpeed: 8, baseCargo: 4, maxCargo: 6, baseFuel: 6, maxFuel: 8, baseShield: 6, maxShield: 8, baseAI: 8, maxAI: 10),
    ShipTemplate(shipClass: "Harvester", modelName: "Eon Traveler", price: 160000, baseSpeed: 7, maxSpeed: 9, baseCargo: 5, maxCargo: 8, baseFuel: 8, maxFuel: 11, baseShield: 7, maxShield: 9, baseAI: 9, maxAI: 11),
    ShipTemplate(shipClass: "Harvester", modelName: "Singularity", price: 350000, baseSpeed: 8, maxSpeed: 11, baseCargo: 6, maxCargo: 10, baseFuel: 9, maxFuel: 13, baseShield: 8, maxShield: 10, baseAI: 10, maxAI: 15),
  ];
}
