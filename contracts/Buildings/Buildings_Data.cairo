%lang starknet

const BUILDINGS_COUNTER = 23;
const BUILD_DATA_NB = 3;
const UPGRADE_DATA_NB = 3;
const REPAIR_DATA_NB = 3;

namespace BuildingIds {
    const Cabin = 1;
    const House = 2;
    const Appartment = 3;
    const Hotel = 4;
    const Boulangerie = 5;
    const GroceryShop = 6;
    const Restaurant = 7;
    const Mall = 8;
    const Bar = 9;
    const Library = 10;
    const SwimmingPool = 11;
    const Cinema = 12;
    const Market = 13;
    const CerealFarm = 14;
    const VegetableFarm = 15;
    const CowFarm = 16;
    const TreeFarm = 17;
    const CoalPlant = 18;
    const PoliceStation = 19;
    const Hospital = 20;
    const Lab = 21;
    const CoalMine = 22;
    const MetalMine = 23;
    const count = 23;
}

struct MultipleResources {
    comp : felt,
    popRequired : felt,
    popAdd : felt,
}
struct MultipleResourcesTime {
    nb : felt,
    comp : felt,
    popRequired : felt,
    timeRequired : felt,
}

// Fixed data for each building by type
struct BuildingFixedData {
    build : MultipleResourcesTime,
    maintenanceCost : MultipleResources,
    maintenanceGains : MultipleResources,
    repair : MultipleResourcesTime,
    newPop: felt,
}

// Build costs of buildings : 0 when not applicable to building
// [comp, popRequired, popAdd]
build_data_start:
// Cabin
dw 0;
dw 0;
dw 0;
// House
dw 103202;
dw 0;
dw 2;
// apartment
dw 110207304705;
dw 0;
dw 6;
// hotel
dw 222312624716612;
dw 12;
dw 28;
// bakery
dw 103207302;
dw 2;
dw 0;
// grocery shop
dw 110205302;
dw 2;
dw 0;
// restaurant
dw 111213306602;
dw 4;
dw 0;
// mall
dw 228335642732617;
dw 16;
dw 0;
// bar
dw 110211307602;
dw 4;
dw 0;
// library
dw 122213312608715608;
dw 8;
dw 0;
// swimming pool
dw 205308612718607;
dw 4;
dw 0;
// cinema
dw 107226621722;
dw 6;
dw 0;
// Market
dw 107209311612727;
dw 12;
dw 0;
// cereal farm
dw 110203301;
dw 5;
dw 0;
// vegetable farm
dw 110207305703;
dw 7;
dw 0;
// cow farm
dw 114205;
dw 5;
dw 0;
// tree farm
dw 112215314605708;
dw 9;
dw 0;
// coal plant
dw 210304804;
dw 3;
dw 0;
// police station
dw 210303611721;
dw 3;
dw 0;
// hospital
dw 109243336633732619;
dw 20;
dw 0;
// Lab
dw 230342656754625;
dw 15;
dw 0;
// Coal mine
dw 112203605;
dw 3;
dw 0;
// Metal mine
dw 112203605;
dw 3;
dw 0;
build_data_end:

repair_data_start:
dw 102;
dw 0;
dw 2;
repair_data_end:

// Cost for a building to produce
maintenance_cost_start:
dw 0; // Cabin
dw 0; // House
dw 0; // apartment
dw 307603703; // hotel
dw 101301; // bakery
dw 302601; // grocery shop
dw 303702; // restaurant
dw 325605707; // mall
dw 302701; // bar
dw 306603702; // library
dw 304603703; // swimming pool
dw 305605705; // cinema
dw 306603703; // Market
dw 101; // cereal farm
dw 201; // vegetable farm
dw 102; // cow farm
dw 305601701; // tree farm
dw 301502; // coal plant
dw 302602701; // police station
dw 313602704; // hospital
dw 303702; // Lab
dw 301701; // Coal mine
dw 301701; // Metal mine
maintenance_cost_end:

production_daily_start:
dw 0; // Cabin
dw 0; // House
dw 0; // apartment
dw 712; // hotel
dw 703; // bakery
dw 704; // grocery shop
dw 704; // restaurant
dw 755; // mall
dw 703; // bar
dw 710; // library
dw 718; // swimming pool
dw 725; // cinema
dw 104204; // Market
dw 303; // cereal farm
dw 304; // vegetable farm
dw 305; // cow farm
dw 107; // tree farm
dw 603; // coal plant
dw 702; // police station
dw 725; // hospital
dw 605; // Lab
dw 201502; // Coal mine
dw 201402; // Metal mine
production_daily_end:
