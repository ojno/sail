val not_implemented : forall ('a : Type). string -> 'a effect {escape}

function not_implemented message = throw(Error_not_implemented(message))

val internal_error : forall ('a : Type). string -> 'a effect {escape}
function internal_error(s) = {
    assert (false, s);
    throw (Error_internal_error)
}

let xlen = 64
type xlenbits = bits(64)
let xlen_max_unsigned = 2 ^ xlen - 1
let xlen_max_signed = 2 ^ (xlen - 1) - 1
let xlen_min_signed = 0 - 2 ^ (xlen - 1)

type regno ('n : Int), 0 <= 'n < 32 = atom('n)
type regbits = bits(5)
type cregbits = bits(3)

val cast regbits_to_regno : bits(5) -> {'n, 0 <= 'n < 32. regno('n)}
function regbits_to_regno b = let 'r = unsigned(b) in r

val creg2reg_bits : cregbits -> regbits
function creg2reg_bits(creg) = 0b01 @ creg

/* some arch and ABI relevant registers */
let zreg : regbits = 0b00000
let ra : regbits = 0b00001  /* x1 */
let sp : regbits = 0b00010  /* x2 */

register PC : xlenbits
register nextPC : xlenbits

register Xs : vector(32, dec, xlenbits)

/* Getters and setters for X registers (special case for zeros register, x0) */
val rX : forall 'n, 0 <= 'n < 32. regno('n) -> xlenbits effect {rreg}

function rX 0 = 0x0000000000000000
and rX (r if r > 0) = Xs[r]

val wX : forall 'n, 0 <= 'n < 32. (regno('n), xlenbits) -> unit effect {wreg}

function wX (r, v) =
  if (r != 0) then {
     Xs[r] = v;
     print_string("x", concat_str(string_of_int(r), concat_str(" <- ", BitStr(v))));
  }

overload X = {rX, wX}

function check_alignment (addr : xlenbits, width : atom('n)) -> forall 'n. unit =
  if unsigned(addr) % width != 0 then throw(Error_misaligned_access) else ()

val MEMr                         : forall 'n. (xlenbits, atom('n)) -> bits(8 * 'n) effect {rmem}
val MEMr_acquire                 : forall 'n. (xlenbits, atom('n)) -> bits(8 * 'n) effect {rmem}
val MEMr_strong_acquire          : forall 'n. (xlenbits, atom('n)) -> bits(8 * 'n) effect {rmem}
val MEMr_reserved                : forall 'n. (xlenbits, atom('n)) -> bits(8 * 'n) effect {rmem}
val MEMr_reserved_acquire        : forall 'n. (xlenbits, atom('n)) -> bits(8 * 'n) effect {rmem}
val MEMr_reserved_strong_acquire : forall 'n. (xlenbits, atom('n)) -> bits(8 * 'n) effect {rmem}

function MEMr                         (addr, width) = __RISCV_read(addr, width)
function MEMr_acquire                 (addr, width) = __RISCV_read(addr, width)
function MEMr_strong_acquire          (addr, width) = __RISCV_read(addr, width)
function MEMr_reserved                (addr, width) = __RISCV_read(addr, width)
function MEMr_reserved_acquire        (addr, width) = __RISCV_read(addr, width)
function MEMr_reserved_strong_acquire (addr, width) = __RISCV_read(addr, width)

val mem_read : forall 'n. (xlenbits, atom('n), bool, bool, bool) -> bits(8 * 'n) effect {rmem, escape}

function mem_read (addr, width, aq, rl, res) = {
  if aq | res then check_alignment(addr, width);

  match (aq, rl, res) {
    (false, false, false) => MEMr(addr, width),
    (true,  false, false) => MEMr_acquire(addr, width),
    (false, false, true)  => MEMr_reserved(addr, width),
    (true,  false, true)  => MEMr_reserved_acquire(addr, width),
    (false, true,  false) => throw(Error_not_implemented("load.rl")),
    (true,  true,  false) => MEMr_strong_acquire(addr, width),
    (false, true,  true)  => throw(Error_not_implemented("lr.rl")),
    (true,  true,  true)  => MEMr_reserved_strong_acquire(addr, width)
  }
}

val MEMea = {ocaml: "memea", lem: "MEMea"} : forall 'n.
  (xlenbits, atom('n)) -> unit effect {eamem}
val MEMea_release = {ocaml: "memea", lem: "MEMea_release"} : forall 'n.
  (xlenbits, atom('n)) -> unit effect {eamem}
val MEMea_strong_release = {ocaml: "memea", lem: "MEMea_strong_release"} : forall 'n.
  (xlenbits, atom('n)) -> unit effect {eamem}
val MEMea_conditional = {ocaml: "memea", lem: "MEMea_conditional"} : forall 'n.
  (xlenbits, atom('n)) -> unit effect {eamem}
val MEMea_conditional_release = {ocaml: "memea", lem: "MEMea_conditional_release"} : forall 'n.
  (xlenbits, atom('n)) -> unit effect {eamem}
val MEMea_conditional_strong_release = {ocaml: "memea", lem: "MEMea_conditional_strong_release"} : forall 'n.
  (xlenbits, atom('n)) -> unit effect {eamem}

val mem_write_ea : forall 'n. (xlenbits, atom('n), bool, bool, bool) -> unit effect {eamem, escape}

function mem_write_ea (addr, width, aq, rl, con) = {
  if rl | con then check_alignment(addr, width);

  match (aq, rl, con) {
    (false, false, false) => MEMea(addr, width),
    (false, true,  false) => MEMea_release(addr, width),
    (false, false, true)  => MEMea_conditional(addr, width),
    (false, true , true)  => MEMea_conditional_release(addr, width),
    (true,  false, false) => throw(Error_not_implemented("store.aq")),
    (true,  true,  false) => MEMea_strong_release(addr, width),
    (true,  false, true)  => throw(Error_not_implemented("sc.aq")),
    (true,  true , true)  => MEMea_conditional_strong_release(addr, width)
  }
}

val MEMval                            : forall 'n. (xlenbits, atom('n), bits(8 * 'n)) -> unit effect {wmv}
val MEMval_release                    : forall 'n. (xlenbits, atom('n), bits(8 * 'n)) -> unit effect {wmv}
val MEMval_strong_release             : forall 'n. (xlenbits, atom('n), bits(8 * 'n)) -> unit effect {wmv}
val MEMval_conditional                : forall 'n. (xlenbits, atom('n), bits(8 * 'n)) -> unit effect {wmv}
val MEMval_conditional_release        : forall 'n. (xlenbits, atom('n), bits(8 * 'n)) -> unit effect {wmv}
val MEMval_conditional_strong_release : forall 'n. (xlenbits, atom('n), bits(8 * 'n)) -> unit effect {wmv}

function MEMval                            (addr, width, data) = __RISCV_write(addr, width, data)
function MEMval_release                    (addr, width, data) = __RISCV_write(addr, width, data)
function MEMval_strong_release             (addr, width, data) = __RISCV_write(addr, width, data)
function MEMval_conditional                (addr, width, data) = __RISCV_write(addr, width, data)
function MEMval_conditional_release        (addr, width, data) = __RISCV_write(addr, width, data)
function MEMval_conditional_strong_release (addr, width, data) = __RISCV_write(addr, width, data)

val mem_write_value : forall 'n. (xlenbits, atom('n), bits(8 * 'n), bool, bool, bool) -> unit effect {wmv, escape}

function mem_write_value (addr, width, value, aq, rl, con) = {
  if rl | con then check_alignment(addr, width);

  match (aq, rl, con) {
    (false, false, false) => MEMval(addr, width, value),
    (false, true,  false) => MEMval_release(addr, width, value),
    (false, false, true)  => MEMval_conditional(addr, width, value),
    (false, true,  true)  => MEMval_conditional_release(addr, width, value),
    (true,  false, false) => throw(Error_not_implemented("store.aq")),
    (true,  true,  false) => MEMval_strong_release(addr, width, value),
    (true,  false, true)  => throw(Error_not_implemented("sc.aq")),
    (true,  true,  true)  => MEMval_conditional_strong_release(addr, width, value)
  }
}

val "speculate_conditional_success" : unit -> bool effect {exmem}

val MEM_fence_rw_rw = {ocaml: "skip", lem: "MEM_fence_rw_rw"} : unit -> unit effect {barr}
val MEM_fence_r_rw  = {ocaml: "skip", lem: "MEM_fence_r_rw"}  : unit -> unit effect {barr}
val MEM_fence_r_r   = {ocaml: "skip", lem: "MEM_fence_r_r"}   : unit -> unit effect {barr}
val MEM_fence_rw_w  = {ocaml: "skip", lem: "MEM_fence_rw_w"}  : unit -> unit effect {barr}
val MEM_fence_w_w   = {ocaml: "skip", lem: "MEM_fence_w_w"}   : unit -> unit effect {barr}
val MEM_fence_i     = {ocaml: "skip", lem: "MEM_fence_i"}     : unit -> unit effect {barr}

enum uop = {RISCV_LUI, RISCV_AUIPC} /* upper immediate ops */
enum bop = {RISCV_BEQ, RISCV_BNE, RISCV_BLT, RISCV_BGE, RISCV_BLTU, RISCV_BGEU} /* branch ops */
enum iop = {RISCV_ADDI, RISCV_SLTI, RISCV_SLTIU, RISCV_XORI, RISCV_ORI, RISCV_ANDI} /* immediate ops */
enum sop = {RISCV_SLLI, RISCV_SRLI, RISCV_SRAI} /* shift ops */
enum rop = {RISCV_ADD, RISCV_SUB, RISCV_SLL, RISCV_SLT, RISCV_SLTU, RISCV_XOR, RISCV_SRL, RISCV_SRA, RISCV_OR, RISCV_AND} /* reg-reg ops */
enum ropw = {RISCV_ADDW, RISCV_SUBW, RISCV_SLLW, RISCV_SRLW, RISCV_SRAW} /* reg-reg 32-bit ops */
enum amoop = {AMOSWAP, AMOADD, AMOXOR, AMOAND, AMOOR, AMOMIN, AMOMAX, AMOMINU, AMOMAXU} /* AMO ops */
enum csrop = {CSRRW, CSRRS, CSRRC}
enum word_width = {BYTE, HALF, WORD, DOUBLE}

/* Ideally these would be sail builtin */

function shift_right_arith64 (v : xlenbits, shift : bits(6)) -> xlenbits =
    let v128 : bits(128) = EXTS(v) in
    (v128 >> shift)[63..0]

function shift_right_arith32 (v : bits(32), shift : bits(5)) -> bits(32) =
    let v64 : xlenbits = EXTS(v) in
    (v64 >> shift)[31..0]
