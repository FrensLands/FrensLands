%lang starknet

from starkware.cairo.common.registers import get_label_location

func bArray(idx : felt) -> (res : felt):
    let (data_address) = get_label_location(data)
    let res = cast(data_address, felt*)
    return (res[idx])

    data:
    dw 1000000000000000
    dw 100000000000000
    dw 10000000000000
    dw 1000000000000
    dw 100000000000
    dw 10000000000
    dw 1000000000
    dw 100000000
    dw 10000000
    dw 1000000
    dw 100000
    dw 10000
    dw 1000
    dw 100
    dw 10
    dw 1
end
