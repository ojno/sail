/*========================================================================*/
/*                                                                        */
/*  Copyright (c) 2015-2017 Robert M. Norton                              */
/*  Copyright (c) 2015-2017 Kathyrn Gray                                  */
/*  All rights reserved.                                                  */
/*                                                                        */
/*  This software was developed by the University of Cambridge Computer   */
/*  Laboratory as part of the Rigorous Engineering of Mainstream Systems  */
/*  (REMS) project, funded by EPSRC grant EP/K008528/1.                   */
/*                                                                        */
/*  Redistribution and use in source and binary forms, with or without    */
/*  modification, are permitted provided that the following conditions    */
/*  are met:                                                              */
/*  1. Redistributions of source code must retain the above copyright     */
/*     notice, this list of conditions and the following disclaimer.      */
/*  2. Redistributions in binary form must reproduce the above copyright  */
/*     notice, this list of conditions and the following disclaimer in    */
/*     the documentation and/or other materials provided with the         */
/*     distribution.                                                      */
/*                                                                        */
/*  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS''    */
/*  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED     */
/*  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A       */
/*  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR   */
/*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,          */
/*  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT      */
/*  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF      */
/*  USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND   */
/*  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,    */
/*  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT    */
/*  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF    */
/*  SUCH DAMAGE.                                                          */
/*========================================================================*/

/* 128 bit cap + tag */
type CapReg = bits(129)

val cast_bool_bit : cast extern bool -> bit effect pure
val cast_boolvec_bitvec : cast extern forall 'n, 'm. vector<'n,'m,dec,bool> -> vector<'n,'m,dec,bit> effect pure
val cast_range_bitvec : cast forall 'm. [|0:2**'m - 1|] -> vector<'m - 1,'m,dec,bit> effect pure
function vector<'m - 1,'m,dec,bit> cast_range_bitvec (v) = to_vec (v)
val not : extern bool -> bool effect pure

type uint64 = range<0, (2** 64) - 1>

type CapStruct = const struct {
  bool    tag;
  bits(4)  uperms;
  bool    access_system_regs;
  bool    perm_reserved9;
  bool    permit_ccall;
  bool    permit_seal;
  bool    permit_store_local_cap;
  bool    permit_store_cap;
  bool    permit_load_cap;
  bool    permit_store;
  bool    permit_load;
  bool    permit_execute;
  bool    global;
  bits(2)  reserved;
  bits(6)  E;
  bool    sealed;
  bits(20) B;
  bits(20) T;
  bits(24) otype;
  bits(64) address;
}

let null_cap : CapStruct = {
  tag                    = false;
  uperms                 = 0;
  access_system_regs     = false;
  perm_reserved9         = false;
  permit_ccall           = false;
  permit_seal            = false;
  permit_store_local_cap = false;
  permit_store_cap       = false;
  permit_load_cap        = false;
  permit_store           = false;
  permit_load            = false;
  permit_execute         = false;
  global                 = false;
  reserved               = 0;
  E                      = 48; /* encoded as 0 in memory due to xor */
  sealed                 = false;
  B                      = 0;
  T                      = 0x10000;
  otype                  = 0;
  address                = 0;
}

def Nat cap_size_t  = 16 /* cap size in bytes */
let cap_size : [:cap_size_t:] = 16

function CapStruct capRegToCapStruct((CapReg) c) =
  let s : bool  = c[104] in
  let Bc : bits(20) = if s then c[103..96] : 0x000 else c[103..84] in
  let Tc : bits(20) = if s then c[83..76] : 0x000 else c[83..64] in
  let otype : bits(24) = if s then c[95..84] : c[75..64] else 0 in
  {
    tag                    = c[128];
    uperms                 = c[127..124];
    access_system_regs     = c[123];
    perm_reserved9         = c[122];
    permit_ccall           = c[121];
    permit_seal            = c[120];
    permit_store_local_cap = c[119];
    permit_store_cap       = c[118];
    permit_load_cap        = c[117];
    permit_store           = c[116];
    permit_load            = c[115];
    permit_execute         = c[114];
    global                 = c[113];
    reserved               = c[112..111];
    E                      = c[110..105] ^ 0b110000;
    sealed                 = s;
    B                      = Bc;
    T                      = Tc;
    otype                  = otype;
    address                = c[63..0];
  }

function (bits(11)) getCapHardPerms((CapStruct) cap) =
   ([cap.access_system_regs]
  : [cap.perm_reserved9]
  : [cap.permit_ccall]
  : [cap.permit_seal]
  : [cap.permit_store_local_cap]
  : [cap.permit_store_cap]
  : [cap.permit_load_cap]
  : [cap.permit_store]
  : [cap.permit_load]
  : [cap.permit_execute]
  : [cap.global])

function (bits(128)) capStructToMemBits128((CapStruct) cap) =
    let b : bits(20) = if cap.sealed then (cap.B)[19..12] : (cap.otype)[23..12] else cap.B in
    let t : bits(20) = if cap.sealed then (cap.T)[19..12] : (cap.otype)[11..0]  else cap.T in
    ( cap.uperms
    : getCapHardPerms(cap)
    : cap.reserved
    : (cap.E ^ 0b110000) /* XXX brackets required otherwise sail interpreter error */
    : [cap.sealed]
    : b
    : t
    : cap.address
    )

function (CapReg) capStructToCapReg((CapStruct) cap) =
    ([cap.tag] : capStructToMemBits128(cap))

/* Reverse of above used when reading from memory */
function (CapReg) memBitsToCapBits128((bool) tag, (bits(128)) b) =
  ([tag] : b)

/* When saving/restoring capabilities xor them with bits of null_cap --
   this ensures that canonical null_cap is always all-zeros in memory
   even though it may have bits set logically (e.g. length or exponent */

let null_cap_bits : bits(128) = capStructToMemBits128(null_cap)

function (bits(128)) capStructToMemBits((CapStruct) cap) =
  capStructToMemBits128(cap) ^ null_cap_bits

function (bits(129)) memBitsToCapBits((bool) tag, (bits(128)) b) =
  memBitsToCapBits128(tag, b ^ null_cap_bits)

function (bits(31)) getCapPerms((CapStruct) cap) = 
    let perms : bits(15) = EXTS(getCapHardPerms(cap)) in /* NB access_system copied into 14-11 */
    (0x000 /* uperms 30-19 */
  : cap.uperms
  : perms)

function CapStruct setCapPerms((CapStruct) cap, (bits(31)) perms) =
    { cap with
      uperms                 = perms[18..15];
      /* 14..11 reserved -- ignore */
      access_system_regs     = perms[10];
      perm_reserved9         = perms[9];
      permit_ccall           = perms[8];
      permit_seal            = perms[7];
      permit_store_local_cap = perms[6];
      permit_store_cap       = perms[5];
      permit_load_cap        = perms[4];
      permit_store           = perms[3];
      permit_load            = perms[2];
      permit_execute         = perms[1];
      global                 = perms[0];
      }

function (bool, CapStruct) sealCap((CapStruct) cap, (bits(24)) otype) =
    if (((cap.T)[11..0] == 0) & ((cap.B)[11..0] == 0)) then
        (true, {cap with sealed=true; otype=otype})
    else
        (false, cap /* was undefined but ocaml shallow embedding can't handle it */ )

function [|-1:1|] a_top_correction((bits(20)) a_mid, (bits(20)) R, (bits(20)) bound) =
    match a_mid < R, bound < R {
      (false, false)  => 0
      (false, true)   => 1
      (true, false)   => -1
      (true, true)    => 0
    }

function uint64 getCapBase((CapStruct) c)  = 
    let E : [|48|] = min(unsigned(c.E), 48) in
    let Bc : bits(20) = c.B in
    let a : bits(65) = EXTZ(c.address) in
    let R : bits(20) = Bc - 0x01000 in /* wraps */
    let a_mid : bits(20) = mask(a >> E) in
    let correction = a_top_correction(a_mid, R, Bc) in
    let a_top = a >> (E+20) in
    let base : bits(64) = EXTZ((a_top + correction) : Bc) << E in
    unsigned(base)

function CapLen getCapTop ((CapStruct) c)  = 
    let E : [|45|] = min(unsigned(c.E), 48) in
    let Bc : bits(20) = c.B in
    let T : bits(20) = c.T in
    let a : bits(65) = EXTZ(c.address)  in
    let R : bits(20) = Bc - 0x01000 in /* wraps */
    let a_mid : bits(20) = mask(a >> E) in
    let correction = a_top_correction(a_mid, R, T) in
    let a_top = a >> (E+20) in
    let top1 : bits(65) = EXTZ((a_top + correction) : T) in
    (CapLen) (top1 << E)

function uint64 getCapOffset((CapStruct) c) = 
    let base = getCapBase(c) in
    unsigned(c.address) - base

function CapLen getCapLength((CapStruct) c)  = getCapTop(c) - getCapBase(c)

function uint64 getCapCursor((CapStruct) cap) = unsigned(cap.address)

function bool fastRepCheck((CapStruct) c, (bits(64)) i) =
    if ((c.E) >= 44) then
        true /* in this case representable region is whole address space */
    else
        let E        = min(unsigned(c.E), 43) in
        let i_top    = signed(i[63..E+20]) in
        let i_mid : bits(20) = i[E+19..E] in
        let a_mid : bits(20) = (c.address)[E+19..E] in
        let R : bits(20)     = (c.B) - 0x01000 in
        let diff : bits(20)  = R - a_mid in
        let diff1 : bits(20) = diff - 1 in
        /* i_top determines 1. whether the increment is inRange
           i.e. less than the size of the representable region
           (2**(E+20)) and 2. whether it is positive or negative. To
           satisfy 1. all top bits must be the same so we are
           interested in the cases i_top is 0 or -1 */
        if (i_top == 0) then
          i_mid <_u diff1
        else if (i_top == -1) then
          unsigned(i_mid) >= unsigned(diff) & (R != a_mid) /* XXX sail missing unsigned >= */
        else
          false

function (bool, CapStruct) setCapOffset((CapStruct) c, (bits(64)) offset) =
    let base : bits(64)       = (bits(64)) (getCapBase(c)) in
    let newAddress : bits(64) = base + offset in
    let newCap     = { c with address = newAddress } in
    let representable = fastRepCheck(c, (newAddress - c.address)) in
    (representable, newCap)

function (bool, CapStruct) incCapOffset((CapStruct) c, (bits(64)) delta) =
    let newAddress : bits(64) = c.address + delta in
    let newCap     = { c with address = newAddress } in
    let representable = fastRepCheck(c, delta) in
    (representable, newCap)

/** FUNCTION:integer HighestSetBit(bits(N) x) */

function forall Nat 'N. option([|0:('N + -1)|]) HighestSetBit((bits('N)) x) = {
  let N = (length(x)) in {
  ([|('N + -1)|]) result = 0;
  (bool) break = false;
  foreach (i from (N - 1) downto 0)
    if ~(break) & x[i] == 1 then {
      result = i;
      break = true;
    };

  if break then Some(result) else None;
}}

/* hw rounds up E to multiple of 4 */
function [|48|] roundUp(([|45|]) e) =
    let r = e mod 4 in
    if (r == 0)
    then e
    else (e - r + 4)


function [|48|] computeE ((bits(65)) rlength) =
    let msb = HighestSetBit((rlength + (rlength >> 6)) >> 19) in
    match msb {
      /* above will always return <= 45 because 19 bits of zero are shifted in from right */
      (Some(b))  => {assert(b <= 45, None); roundUp (min(b,45)) }
      None     => 0
      }

function (bool, CapStruct) setCapBounds((CapStruct) cap, (bits(64)) base, (bits(65)) top) =
    /* {cap with base=base; length=(bits(64)) length; offset=0} */
    let e : [|48|] = computeE(top - (0b0 : base)) in
    let Bc : bits(20) = base[19+e..e] in
    let T : bits(20) = top[19+e..e] in
    let T2 : bits(20) = T + if (top[(e - 1)..0] == 0) then 0 else 1 in
    let newCap  = {cap with E=(bits(6)) e; B=Bc; T=T2} in
    let newBase = getCapBase(newCap) in
    let newTop  = getCapTop(newCap) in
    let exact   = (base == newBase) & (top == newTop) in
    (exact, newCap)

function CapStruct int_to_cap ((bits(64)) offset) = 
    {null_cap with address = offset}
