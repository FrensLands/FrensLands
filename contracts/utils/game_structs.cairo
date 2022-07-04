%lang starknet

struct MapData:
    member size_x : felt
    member size_y : felt
end

namespace ModuleIds:
    const M01_Worlds = 1
end

namespace ExternalContractsIds:
    const Maps = 1
    const MinterMaps = 2
    const S_Maps = 3
    const Gold = 4
end

namespace MapGroundType:
    const Grass = 1
end

namespace MapsPrice:
    const Map_1 = 100
    const Map_2 = 150
    const Map_3 = 200
    const Map_4 = 300
    const Map_5 = 500
end

# Building : Cabane
# Events Id
