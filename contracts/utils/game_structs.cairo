%lang starknet

namespace ModuleIds {
    const FrensLands = 1;
    const FrensLands_Storage = 2;
    const ResourcesSpawned = 3;
    const Buildings = 4;
}

namespace ExternalContractsIds {
    const Lands = 1;
    const MinterLands = 2;
}

namespace InfrastructureTypes {
    const TSpawned = 1;
    const TBuilding = 2;
    const TDecoration = 3;
    const TRoad = 4;
}

namespace ResourcesType {
    const Wood = 1;
    const Rock = 2;
    const Food = 3;
    const Metal = 4;
    const Coal = 5;
    const Energy = 6;
    const Coins = 7;
    const count = 7;
}

// comp fixe : typeId, timeCreated
// des données variables basées sur les actions du player  : pos_start 
// données variables en fonction des jours : frensWorking, degraded
struct BuildingData {
    typeId: felt,
    posStart: felt,
    frensWorking: felt,
    decay: felt,
    level: felt,
    recharges: felt,
    lastClaim: felt,
    // timeCreated: felt,
    // nextUid : felt,
    // Nb of unit times where the building was not used 
}

namespace BiomeIds {
    const Grass = 1;
    const Sand = 2;
    const Shadow = 3;
    const Blue = 4;
    const Mountain = 5;
    const count = 5;
}
