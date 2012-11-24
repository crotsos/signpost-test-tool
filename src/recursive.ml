(*
 * Copyright (c) 2012 Charalampos Rotsos <cr409@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)


(*
 * In this test we test the ability of the dns server a fetch a number
 * of different records. This way we can see if the resolver is performing
 * some kind of rr type filtering. 
 * *)
open Printf
open Lwt

open Lwt_log 
open Lwt_unix 
open Lwt_io 

open Dns_resolver
open Dns.Packet

let domain = ".measure.signpo.st"

let names = [
  ("types.a",    Q_A);
  ("types.md",   Q_MD);   
  ("types.mf",   Q_MF);
  ("types.ns",   Q_NS);
  ("types.mb",   Q_MB);
  ("types.mg",   Q_MG);
  ("types.mr",   Q_MR);
  ("types.ns",   Q_NS);
  ("types.wks",  Q_WKS);
  ("types.ptr",  Q_PTR);
  ("types.hinf0",Q_HINFO);
  ("types.minfo",Q_MINFO);
  ("types.mx",   Q_MX);
  ("types.txt",  Q_TXT);
  ("types.txt",  Q_TXT);
  ("types.rp",   Q_RP);
  ("types.afsdb",Q_AFSDB);
  ("types.x25",  Q_X25);
  ("types.isdn", Q_ISDN);
  ("types.rt",   Q_RT);
  ("types.srv",  Q_SRV);
  ("types.aaaa", Q_AAAA);
  ("types.unk",  Q_UNKNOWN(666) ); 
]

let parse_answer typ rrset = 
  (* Should return two flags for record type and rrsign
   * and the ttl offered *)
  List.fold_right (
    fun rr (record, rrsig, ttl) -> 
      let reply_typ = q_type_to_int typ in
      let record_type = rdata_to_rr_type rr.rdata in 
      match record_type with
      | RR_RRSIG ->  (record, true, ttl)
      | RR_UNSPEC -> 
          let UNKNOWN(typ, _) = rr.rdata in 
          if ( typ = reply_typ) then 
            (true, rrsig, rr.ttl)
          else
            (record, rrsig, ttl) 
      | record_type when reply_typ = (rr_type_to_int record_type) ->
          (true, rrsig, rr.ttl)
      | _-> (record, rrsig, ttl)
  ) rrset (false, false, 0l) 

let test ns dnssec = 
  try_lwt
    let config = ( `Static([(ns, 53)], [""]) ) in
    lwt resolver = create ~config () in
    lwt _ = 
      Lwt_list.iter_s (
        fun (name, q_type) ->
          try_lwt 
            let _ = log ~level:Error 
                    (sprintf "recursive:fetching:%s" (name ^ domain))
            in  
            lwt pkt = resolve resolver ~dnssec Q_IN q_type 
                (Dns.Name.string_to_domain_name (name ^ domain)) in
            let (record, rrsig, ttl) = 
              parse_answer q_type pkt.answers in
            lwt _ = log ~level:Error 
              (sprintf "recursive:result:%s:%s:%s:%s:%ld" 
              name (string_of_bool dnssec) (string_of_bool record)
              (string_of_bool rrsig) ttl
              ) in
            lwt _ = log ~level:Error 
                  (sprintf "recursive:returned:%s:%s" 
                  name (Dns.Packet.to_string pkt))
            in
            lwt _ = Lwt_unix.sleep 0.5 in 
              return ()
          with exn -> 
            log ~exn ~level:Error 
            (sprintf "recursive:result:%s:%s:false:false:0:failed:" 
            (name ^ domain) (string_of_bool dnssec) )
      ) names in 
        return ()
  with exn ->
    log ~exn ~level:Error (sprintf "recursive:exception:%s:" (string_of_bool dnssec)) 
