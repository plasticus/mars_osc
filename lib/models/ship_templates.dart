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
    // ======================
    // MULE — classic hauler, widest spread
    // ======================
    ShipTemplate(shipClass: "Mule", modelName: "Rusty Tug",    price: 1000,  baseSpeed: 2, maxSpeed: 4,  baseCargo: 4,  maxCargo: 6,  baseFuel: 3,  maxFuel: 5,  baseShield: 2,  maxShield: 4,  baseAI: 1,  maxAI: 3),
    ShipTemplate(shipClass: "Mule", modelName: "Iron Snail",   price: 5200,  baseSpeed: 3, maxSpeed: 5,  baseCargo: 5,  maxCargo: 8,  baseFuel: 4,  maxFuel: 6,  baseShield: 3,  maxShield: 5,  baseAI: 2,  maxAI: 4),
    ShipTemplate(shipClass: "Mule", modelName: "Bulk Carrier", price: 14000, baseSpeed: 3, maxSpeed: 6,  baseCargo: 7,  maxCargo: 11, baseFuel: 5,  maxFuel: 7,  baseShield: 4,  maxShield: 6,  baseAI: 3,  maxAI: 6),
    ShipTemplate(shipClass: "Mule", modelName: "Solar Whale",  price: 34000, baseSpeed: 3, maxSpeed: 5,  baseCargo: 9,  maxCargo: 14, baseFuel: 6,  maxFuel: 9,  baseShield: 5,  maxShield: 7,  baseAI: 5,  maxAI: 8),
    ShipTemplate(shipClass: "Mule", modelName: "Titan Hauler", price: 82000, baseSpeed: 4, maxSpeed: 6,  baseCargo: 12, maxCargo: 18, baseFuel: 7,  maxFuel: 11, baseShield: 6,  maxShield: 8,  baseAI: 6,  maxAI: 10),

    // ======================
    // SPRINTER — fast, low cargo, intentionally short-range
    // NOTE: Fuel is kept extremely low so Sprinters never become distance ships
    // under EffectiveRange = Fuel + 0.5*AI (AI max 16).
    // ======================
    ShipTemplate(shipClass: "Sprinter", modelName: "Dart",         price: 1600,  baseSpeed: 6,  maxSpeed: 9,  baseCargo: 1, maxCargo: 2, baseFuel: 1, maxFuel: 1, baseShield: 1, maxShield: 2, baseAI: 3,  maxAI: 6),
    ShipTemplate(shipClass: "Sprinter", modelName: "Comet",        price: 7200,  baseSpeed: 8,  maxSpeed: 12, baseCargo: 2, maxCargo: 3, baseFuel: 1, maxFuel: 1, baseShield: 1, maxShield: 2, baseAI: 4,  maxAI: 8),
    ShipTemplate(shipClass: "Sprinter", modelName: "Silver Streak",price: 19000, baseSpeed: 10, maxSpeed: 15, baseCargo: 3, maxCargo: 4, baseFuel: 1, maxFuel: 1, baseShield: 2, maxShield: 3, baseAI: 6,  maxAI: 11),
    ShipTemplate(shipClass: "Sprinter", modelName: "Velocity",     price: 42000, baseSpeed: 14, maxSpeed: 19, baseCargo: 4, maxCargo: 5, baseFuel: 1, maxFuel: 1, baseShield: 2, maxShield: 3, baseAI: 8,  maxAI: 13),
    ShipTemplate(shipClass: "Sprinter", modelName: "Warp Shadow",  price: 90000, baseSpeed: 16, maxSpeed: 20, baseCargo: 5, maxCargo: 6, baseFuel: 1, maxFuel: 1, baseShield: 2, maxShield: 3, baseAI: 10, maxAI: 16),

    // ======================
    // TANKER — biggest cargo + fuel, moderate shields, moderate AI
    // ======================
    ShipTemplate(shipClass: "Tanker", modelName: "Fuel Buoy",      price: 4200,  baseSpeed: 3, maxSpeed: 5, baseCargo: 4,  maxCargo: 7,  baseFuel: 7,  maxFuel: 9,  baseShield: 1, maxShield: 3, baseAI: 2, maxAI: 5),
    ShipTemplate(shipClass: "Tanker", modelName: "Gas Giant",      price: 10500, baseSpeed: 4, maxSpeed: 6, baseCargo: 6,  maxCargo: 10, baseFuel: 8,  maxFuel: 10, baseShield: 2, maxShield: 4, baseAI: 3, maxAI: 7),
    ShipTemplate(shipClass: "Tanker", modelName: "Deep Oiler",     price: 24000, baseSpeed: 5, maxSpeed: 7, baseCargo: 8,  maxCargo: 14, baseFuel: 9,  maxFuel: 12, baseShield: 3, maxShield: 5, baseAI: 4, maxAI: 9),
    ShipTemplate(shipClass: "Tanker", modelName: "Voyager",        price: 52000, baseSpeed: 6, maxSpeed: 8, baseCargo: 10, maxCargo: 18, baseFuel: 10, maxFuel: 13, baseShield: 4, maxShield: 6, baseAI: 6, maxAI: 11),
    ShipTemplate(shipClass: "Tanker", modelName: "Infinite Reach", price: 110000,baseSpeed: 7, maxSpeed: 9, baseCargo: 12, maxCargo: 20, baseFuel: 12, maxFuel: 14, baseShield: 5, maxShield: 7, baseAI: 7, maxAI: 12),

    // ======================
    // MINER — slowest, best shields, low AI, moderate range
    // ======================
    ShipTemplate(shipClass: "Miner", modelName: "Gravel Picker",  price: 6500,   baseSpeed: 1, maxSpeed: 3, baseCargo: 3, maxCargo: 5,  baseFuel: 4, maxFuel: 6,  baseShield: 6,  maxShield: 9,  baseAI: 1, maxAI: 3),
    ShipTemplate(shipClass: "Miner", modelName: "Rock Biter",     price: 15000,  baseSpeed: 2, maxSpeed: 4, baseCargo: 4, maxCargo: 7,  baseFuel: 5, maxFuel: 7,  baseShield: 7,  maxShield: 11, baseAI: 2, maxAI: 4),
    ShipTemplate(shipClass: "Miner", modelName: "Ore Hound",      price: 32000,  baseSpeed: 3, maxSpeed: 5, baseCargo: 5, maxCargo: 9,  baseFuel: 6, maxFuel: 8,  baseShield: 8,  maxShield: 13, baseAI: 3, maxAI: 5),
    ShipTemplate(shipClass: "Miner", modelName: "Asteroid Eater", price: 68000,  baseSpeed: 3, maxSpeed: 6, baseCargo: 6, maxCargo: 11, baseFuel: 7, maxFuel: 9,  baseShield: 10, maxShield: 15, baseAI: 4, maxAI: 6),
    ShipTemplate(shipClass: "Miner", modelName: "Core Driller",   price: 140000, baseSpeed: 4, maxSpeed: 6, baseCargo: 8, maxCargo: 12, baseFuel: 8, maxFuel: 10, baseShield: 12, maxShield: 18, baseAI: 5, maxAI: 8),

    // ======================
    // HARVESTER — crystal ship: small cargo, AI growth king
    // Speed is only +1 over Tankers at each tier
    // ======================
    ShipTemplate(shipClass: "Harvester", modelName: "Rift Skimmer", price: 22000,  baseSpeed: 4, maxSpeed: 6,  baseCargo: 1, maxCargo: 2, baseFuel: 5, maxFuel: 7,  baseShield: 4, maxShield: 6,  baseAI: 6,  maxAI: 10),
    ShipTemplate(shipClass: "Harvester", modelName: "Soul Beacon",  price: 52000,  baseSpeed: 5, maxSpeed: 7,  baseCargo: 2, maxCargo: 3, baseFuel: 6, maxFuel: 8,  baseShield: 5, maxShield: 7,  baseAI: 9,  maxAI: 13),
    ShipTemplate(shipClass: "Harvester", modelName: "Void Weaver",  price: 110000, baseSpeed: 6, maxSpeed: 8,  baseCargo: 3, maxCargo: 4, baseFuel: 7, maxFuel: 9,  baseShield: 6, maxShield: 8,  baseAI: 12, maxAI: 16),
    ShipTemplate(shipClass: "Harvester", modelName: "Eon Traveler", price: 210000, baseSpeed: 7, maxSpeed: 9,  baseCargo: 4, maxCargo: 5, baseFuel: 8, maxFuel: 11, baseShield: 7, maxShield: 9,  baseAI: 15, maxAI: 18),
    ShipTemplate(shipClass: "Harvester", modelName: "Singularity",  price: 420000, baseSpeed: 8, maxSpeed: 10, baseCargo: 5, maxCargo: 6, baseFuel: 9, maxFuel: 13, baseShield: 8, maxShield: 10, baseAI: 16, maxAI: 20),
  ];
}
