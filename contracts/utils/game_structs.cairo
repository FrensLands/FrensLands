%lang starknet

struct MapData:
    member blocks_x : felt
    member blocks_y : felt
    member time_start : felt  # à voir car déjà storage_var
end

namespace ModuleIds:
    const M01_Worlds = 1
    const M02_Resources = 2
    const M03_Buildings = 3
    const M04_Calculation = 4
end

namespace ExternalContractsIds:
    const Maps = 1
    const MinterMaps = 2
    const S_Maps = 3
    const Gold = 4
    const Resources = 5
end

namespace MapGroundType:
    const Grass = 1
    const Sand = 2
    const Rock = 3
end

namespace ResourcesType:
    const Wood = 1
    const Rock = 2
    const Meat = 3
    const Vegetables = 4
    const Cereal = 5
    const Metal = 6
    const Copper = 7
    const Coal = 8
    const Phosphore = 9

    const count = 9
end

namespace MapsPrice:
    const Map_1 = 100
    const Map_2 = 150
    const Map_3 = 200
    const Map_4 = 300
    const Map_5 = 500
    const count = 5
end

namespace BuildingIds:
    const Cabin = 1
    const Boulangerie = 2
    const Mall = 3
    const GroceryShop = 4
    const Restaurant = 5
    const CerealFarm = 6
    const VegetableFarm = 7
    const CowFarm = 8
    const TreeFarm = 9
    const Mine = 10
    const Market = 11
    const CoalPlant = 12
    const Cinema = 13
    const Bar = 14
    const Library = 15
    const SwimmingPool = 16
    const PoliceStation = 17
    const House = 18
    const Appartment = 19
    const Hotel = 20
    const Lab = 21
    const Hospital = 22
    const Rock = 23
    const Tree = 24
    const count = 24
end

struct DailyCost:
    member resources_id : felt
    member resources_qty : felt
    member gold_qty : felt
    member energy_qty : felt
end

struct UpgradeCost:
    member nb_resources : felt
    member resources_qty : felt
    member gold_qty : felt
    member energy_qty : felt
end

# Fixed data for each building by type
struct BuildingFixedData:
    # member type_id : felt pas besoin car utilisé dans storage_var
    member upgrade_cost : UpgradeCost
    member daily_cost : DailyCost
    member daily_harvest : DailyCost
    member pop_max : felt
    member pop_min : felt
end

struct BuildingData:
    # member id : felt -> idem dans storage_var
    member type_id : felt
    member level : felt
    member pop : felt
    member time_created : felt
    member last_repair : felt
end

# struct ResourcesData:
#     member gold : felt
#     member wood : felt
#     member rock : felt
#     member meat : felt
#     member vegetables : felt
#     member cereal : felt
#     member metal : felt
#     member copper : felt
#     member coal : felt
#     member phosphore : felt
# end

# struct Gabelous:
#     member gabelous_type : felt
#     member daily_cost : Cost
# end

# namespace GabelousTypes:
#     const Owner = 1
#     const Mayor = 2
# end

namespace EventsIds:
    const Event1 = 1
end
