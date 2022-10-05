%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from contracts.library.library_compute import Compute
from contracts.library.library_module import Module
from contracts.library.library_data import Data
from contracts.Resources.Resources_Data import ResourcesSpawnedArr

from contracts.utils.MapSeeder import MapSeeder
from contracts.utils.interfaces import IFrensLandsStorage, IModuleController
from contracts.utils.game_structs import ModuleIds, InfrastructureTypes
from contracts.utils.game_constants import NUMBER_OF_BLOCKS, MAP_X_SIZE

from contracts.FrensLands_Storage import map_info

namespace FrensLands {

    // ##################
    // # VIEW FUNCTIONS #
    // ##################

    // # @notice Get land block information
    // # @param account : token id of erc721 land
    // # @param index : land block number
    // # @return data : block data
    func _read_map_block{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        land_id: felt,
        pos_x: felt,
        pos_y: felt
    ) -> (data: felt) {
        let (data : felt) = map_info.read(land_id, pos_x, pos_y);
        return (data,);
    }

    func _decompose_block_comp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        land_id : felt,
        pos_x : felt,
        pos_y : felt
    ) -> (resource_type : felt, resource_type_id : felt, resource_uid : felt, level : felt) {
        alloc_locals;

        let (block) = _read_map_block(land_id, pos_x, pos_y);
        if (block == 0) {
            return (0, 0, 0, 0);
        }
        let (local decomp_array : felt*) = alloc();
        Data._decompose_all_block(block, decomp_array, 0);

        return (decomp_array[0], decomp_array[1], decomp_array[2], decomp_array[3]);
    }

    func _decompose_resources_comp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        comp : felt
    ) -> (resource_len : felt, resource : felt*) {
        alloc_locals;
        
        let (resource : felt*) = alloc();
        let (resource_len : felt) = Data._decompose_resources(comp, resource, 0);

        return (resource_len, resource);
    }

    // #####################
    // # PRIVATE FUNCTIONS #
    // #####################

    // # @notice Update map block
    // # @param land_id : player land_id
    // # @param index : land block number
    // # @param data : block data
    func _update_map_block{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        land_id: felt,
        pos_x: felt,
        pos_y: felt,
        data: felt
    ) {
        map_info.write(land_id, pos_x, pos_y, data);
        return ();
    }

    // # @notice Initialize map blocks
    // # @param _x : number of blocks axis X
    // # @param _y : number of blocks axis Y
    // # @param index : current block index 
    // # @param index_tree : current tree index 
    // # @param index_rock : current rock index 
    // # @param index_mine : current mine index 
    // # @param index_bush : current bush index 
    // # @param resource_uid : counter id of resources spawned
    func _initialize_maps{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        land_id: felt,
        _x: felt,
        _y: felt,
        index: felt,
        index_tree: felt,
        index_rock: felt,
        index_mine: felt,
        index_bush: felt,
        resource_uid: felt,
    ) -> (resource_uid: felt) {
        alloc_locals;
        if (index == NUMBER_OF_BLOCKS + 1) {
            return (resource_uid,);
        }

        if (index == 300) {
            local comp = (10000000000 * InfrastructureTypes.TBuilding) + (100000000 * 1) + (10000 * 1) + (1000 * 1) + (100 * 1) + 99;
            _update_map_block(land_id, _x, _y, comp);
            if (_x == MAP_X_SIZE) {
                return _initialize_maps(
                    land_id,
                    1,
                    _y + 1,
                    index + 1,
                    index_tree,
                    index_rock,
                    index_mine,
                    index_bush,
                    resource_uid,
                );
            } else {
                return _initialize_maps(
                    land_id,
                    _x + 1,
                    _y,
                    index + 1,
                    index_tree,
                    index_rock,
                    index_mine,
                    index_bush,
                    resource_uid,
                );
            }
        }

        let (is_tree) = MapSeeder.get_tree(index_tree);
        if (is_tree == index) {
            local comp = (10000000000 * InfrastructureTypes.TSpawned) + (100000000 * ResourcesSpawnedArr.Tree) + (10000 * resource_uid) + (1000 * 1) + (100 * 1) + 99;
            _update_map_block(land_id, _x, _y, comp);
            if (_x == MAP_X_SIZE) {
                return _initialize_maps(
                    land_id,
                    1,
                    _y + 1,
                    index + 1,
                    index_tree + 1,
                    index_rock,
                    index_mine,
                    index_bush,
                    resource_uid + 1,
                );
            } else {
                return _initialize_maps(
                    land_id,
                    _x + 1,
                    _y,
                    index + 1,
                    index_tree + 1,
                    index_rock,
                    index_mine,
                    index_bush,
                    resource_uid + 1,
                );
            }
        }

        let (is_rocks) = MapSeeder.get_rocks(index_rock);
        if (is_rocks == index) {
            local comp = (10000000000 * InfrastructureTypes.TSpawned) + (100000000 * ResourcesSpawnedArr.Rock) + (10000 * resource_uid) + (1000 * 1) + (100 * 1) + 99;
            _update_map_block(land_id, _x, _y, comp);
            if (_x == MAP_X_SIZE) {
                return _initialize_maps(
                    land_id,
                    1,
                    _y + 1,
                    index + 1,
                    index_tree,
                    index_rock + 1,
                    index_mine,
                    index_bush,
                    resource_uid + 1,
                );
            } else {
                return _initialize_maps(
                    land_id,
                    _x + 1,
                    _y,
                    index + 1,
                    index_tree,
                    index_rock + 1,
                    index_mine,
                    index_bush,
                    resource_uid + 1,
                );
            }
        }

        let (is_mine) = MapSeeder.get_mines(index_mine);
        if (is_mine == index) {
            local comp = (10000000000 * InfrastructureTypes.TSpawned) + (100000000 * ResourcesSpawnedArr.Mine) + (10000 * resource_uid) + (1000 * 1) + (100 * 1) + 99;
            _update_map_block(land_id, _x, _y, comp);
            if (_x == MAP_X_SIZE) {
                return _initialize_maps(
                    land_id,
                    1,
                    _y + 1,
                    index + 1,
                    index_tree,
                    index_rock,
                    index_mine + 1,
                    index_bush,
                    resource_uid + 1,
                );
            } else {
                return _initialize_maps(
                    land_id,
                    _x + 1,
                    _y,
                    index + 1,
                    index_tree,
                    index_rock,
                    index_mine + 1,
                    index_bush,
                    resource_uid + 1,
                );
            }
        }

        let (is_bush) = MapSeeder.get_bushes(index_bush);
        if (is_bush == index) {
            local comp = (10000000000 * InfrastructureTypes.TSpawned) + (100000000 * ResourcesSpawnedArr.Bush) + (10000 * resource_uid) + (1000 * 1) + (100 * 1) + 99;
            _update_map_block(land_id, _x, _y, comp);
            if (_x == MAP_X_SIZE) {
                return _initialize_maps(
                    land_id,
                    1,
                    _y + 1,
                    index + 1,
                    index_tree,
                    index_rock,
                    index_mine,
                    index_bush + 1,
                    resource_uid + 1,
                );
            } else {
                return _initialize_maps(
                    land_id,
                    _x + 1,
                    _y,
                    index + 1,
                    index_tree,
                    index_rock,
                    index_mine,
                    index_bush + 1,
                    resource_uid + 1,
                );
            }
        }

        if (_x == MAP_X_SIZE) {
            return _initialize_maps(
                land_id,
                1,
                _y + 1,
                index + 1,
                index_tree,
                index_rock,
                index_mine,
                index_bush,
                resource_uid,
            );
        } else {
            return _initialize_maps(
                land_id,
                _x + 1,
                _y,
                index + 1,
                index_tree,
                index_rock,
                index_mine,
                index_bush,
                resource_uid
            );
        }
    }
}