%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_in_range, is_le
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_shl,
    uint256_lt,
    uint256_unsigned_div_rem,
)

namespace MapSeeder:
    @external
    func get_cabin(idx : felt) -> (land : felt):
        let (l) = get_label_location(cabin)
        let arr = cast(l, felt*)
        return (arr[idx])

        cabin:
        dw 300
    end

    @external
    func get_mines(idx : felt) -> (land : felt):
        let (l) = get_label_location(mines)
        let arr = cast(l, felt*)
        return (arr[idx])

        mines:
        dw 93
        dw 286
        dw 314
        dw 484
    end

    @external
    func get_bushes(idx : felt) -> (land : felt):
        let (l) = get_label_location(bushes)
        let arr = cast(l, felt*)
        return (arr[idx])

        bushes:
        dw 151
        dw 201
        dw 248
        dw 305
    end

    @external
    func get_rocks(idx : felt) -> (land : felt):
        let (l) = get_label_location(rocks)
        let arr = cast(l, felt*)
        return (arr[idx])

        rocks:
        dw 53
        dw 66
        dw 68
        dw 85
        dw 89
        dw 122
        dw 162
        dw 166
        dw 173
        dw 181
        dw 234
        dw 312
        dw 315
        dw 328
        dw 339
        dw 345
        dw 359
        dw 367
        dw 368
        dw 369
        dw 436
        dw 439
        dw 514
        dw 526
        dw 537
        dw 538
        dw 589
    end

    @external
    func get_tree(idx : felt) -> (land : felt):
        let (l) = get_label_location(tree)
        let arr = cast(l, felt*)
        return (arr[idx])

        tree:
        dw 48
        dw 64
        dw 84
        dw 87
        dw 91
        dw 92
        dw 95
        dw 99
        dw 103
        dw 106
        dw 111
        dw 113
        dw 126
        dw 128
        dw 129
        dw 130
        dw 133
        dw 134
        dw 143
        dw 144
        dw 145
        dw 147
        dw 148
        dw 149
        dw 150
        dw 152
        dw 154
        dw 163
        dw 164
        dw 165
        dw 168
        dw 169
        dw 171
        dw 184
        dw 185
        dw 187
        dw 189
        dw 190
        dw 191
        dw 196
        dw 200
        dw 204
        dw 205
        dw 207
        dw 210
        dw 211
        dw 216
        dw 218
        dw 223
        dw 225
        dw 226
        dw 227
        dw 228
        dw 229
        dw 230
        dw 231
        dw 232
        dw 236
        dw 243
        dw 244
        dw 246
        dw 249
        dw 250
        dw 253
        dw 256
        dw 257
        dw 258
        dw 265
        dw 266
        dw 267
        dw 268
        dw 271
        dw 272
        dw 274
        dw 277
        dw 284
        dw 287
        dw 288
        dw 291
        dw 293
        dw 294
        dw 301
        dw 308
        dw 309
        dw 311
        dw 313
        dw 316
        dw 323
        dw 325
        dw 327
        dw 329
        dw 330
        dw 331
        dw 348
        dw 350
        dw 352
        dw 353
        dw 354
        dw 357
        dw 364
        dw 366
        dw 371
        dw 373
        dw 376
        dw 382
        dw 391
        dw 392
        dw 394
        dw 395
        dw 403
        dw 404
        dw 407
        dw 408
        dw 409
        dw 410
        dw 411
        dw 412
        dw 414
        dw 421
        dw 424
        dw 426
        dw 427
        dw 429
        dw 432
        dw 434
        dw 444
        dw 446
        dw 448
        dw 449
        dw 450
        dw 451
        dw 452
        dw 456
        dw 459
        dw 469
        dw 471
        dw 473
        dw 475
        dw 477
        dw 482
        dw 485
        dw 488
        dw 489
        dw 492
        dw 494
        dw 495
        dw 502
        dw 507
        dw 510
        dw 525
        dw 528
        dw 533
        dw 536
        dw 540
        dw 545
        dw 550
        dw 552
        dw 557
        dw 562
        dw 566
        dw 571
        dw 577
        dw 584
        dw 591
        dw 595
        dw 628
    end
end
