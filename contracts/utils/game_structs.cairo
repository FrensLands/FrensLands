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
end
