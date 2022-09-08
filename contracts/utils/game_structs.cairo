%lang starknet

struct MapData {
    blocks_x: felt,
    blocks_y: felt,
    type: felt,
}

namespace ModuleIds {
    const M01_Worlds = 1;
    const M02_Resources = 2;
    const M03_Buildings = 3;
    const M04_Calculation = 4;
}

namespace ExternalContractsIds {
    const Maps = 1;
    const MinterMaps = 2;
    const S_Maps = 3;
    const Gold = 4;
    const Resources = 5;
}

namespace MapGroundType {
    const Grass = 1;
    const Sand = 2;
    const Rock = 3;
}

namespace ResourcesType {
    const Wood = 1;
    const Rock = 2;
    const Meat = 3;
    const Vegetables = 4;
    const Cereal = 5;
    const Metal = 6;
    const Copper = 7;
    const Coal = 8;
    const Phosphore = 9;
    const count = 9;
}

namespace MapsPrice {
    const Map_1 = 100;
    const Map_2 = 150;
    const Map_3 = 200;
    const Map_4 = 300;
    const Map_5 = 500;
    const count = 5;
}

namespace BuildingIds {
    const Cabin = 1;
    const Rock = 2;
    const Tree = 3;
    const House = 4;
    const Appartment = 5;
    const Hotel = 6;
    const Boulangerie = 7;
    const GroceryShop = 8;
    const Restaurant = 9;
    const Mall = 10;
    const Bar = 11;
    const Library = 12;
    const SwimmingPool = 13;
    const Cinema = 14;
    const Market = 15;
    const CerealFarm = 16;
    const VegetableFarm = 17;
    const CowFarm = 18;
    const TreeFarm = 19;
    const NaturalMine = 20;
    const CoalPlant = 21;
    const PoliceStation = 22;
    const Hospital = 23;
    const Lab = 24;
    const CoalMine = 25;
    const MetalMine = 26;
    const Bush = 27;
    const count = 27;
}

struct SingleResource {
    resources_id: felt,
    resources_qty: felt,
    gold_qty: felt,
    energy_qty: felt,
}

struct MultipleResources {
    nb_resources: felt,
    resources_qty: felt,
    gold_qty: felt,
    energy_qty: felt,
}

// Fixed data for each building by type
struct BuildingFixedData {
    upgrade_cost: MultipleResources,
    daily_cost: MultipleResources,
    daily_harvest: MultipleResources,
    pop_min: felt,
    new_pop: felt,
}

struct BuildingData {
    type_id: felt,
    level: felt,
    pop: felt,
    time_created: felt,
    recharged: felt,
    last_claim: felt,
    pos: felt,
}
