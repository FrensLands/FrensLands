%lang starknet

namespace ResourcesSpawnedArr {
    const Tree = 1;
    const Rock = 2;
    const Bush = 3;
    const Mine = 4;
    const count = 4;
}

const RS_COUNTER = 4;
const RS_DATA = 4;

struct ResourcesFixedData {
    harvestingCost_qty: felt,
    harvestingGain_qty: felt,
    popFreeRequired: felt,
    timeRequired: felt,
}

rs_data_start:
dw 301;
dw 102;
dw 1;
dw 1;
// Rocks
dw 301;
dw 202;
dw 1;
dw 1;
// Bush
dw 0;
dw 302;
dw 1;
dw 1;
// Mines
dw 303;
dw 402502;
dw 3;
dw 2;
rs_data_end: