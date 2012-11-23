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
open Printf
open Lwt

open Lwt_log 
open Lwt_unix 
open Lwt_io 

open Dns_resolver
open Dns.Packet

open Config

let hostname = "types.a.measure.signpo.st"
let hostname_b = "types.txt.measure.signpo.st"

let multi_additional resolver ns =
  try_lwt 
    let detail = { qr=Query; opcode=Standard;
                   aa=true; tc=false; rd=true; 
                   ra=false; rcode=NoError; }
    in
    let additionals = 
      [ ( 
        {name=[]; cls=RR_IN; ttl=0l; 
        rdata=TXT(["does this rr get's through a resolver?"])});  
        ({name=[]; cls=RR_IN; ttl=0l;
        rdata=(EDNS0(1500, 0, true, []));} ) ]
    in
    let question = { q_name=(Dns.Name.string_to_domain_name hostname); 
                     q_type=Q_A; q_class=Q_IN } in 
    let pkt = { id=(Random.int 0xffff); detail; questions=[question]; 
      answers=[]; authorities=[]; additionals; } in 

    lwt reply = send_pkt resolver pkt in  

    lwt _ = 
      if (List.length pkt.answers > 0) then 
        log ~level:Error 
          (sprintf "multi:%s:result:multi_additional:true" ns)
      else 
        log ~level:Error 
          (sprintf "multi:%s:result:multi_additional:false" ns)
    in 
    lwt _ = 
      log ~level:Error 
      (sprintf "multi:%s:return:multi_additional:%s" 
         ns (Dns.Packet.to_string pkt)) in  
      return ()
  with exn ->
    log ~exn ~level:Error 
      (sprintf "multi:%s:result:multi_additional:false:failed:" ns)

let multi_query resolver ns =
  try_lwt 
    let detail = { qr=Query; opcode=Standard;
                   aa=true; tc=false; rd=true; 
                   ra=false; rcode=NoError; }
    in
    let additionals = 
      [({name=[]; cls=RR_IN; ttl=0l; 
      rdata=(EDNS0(1500, 0, true, []));} ) ] in
    let questions = [
      {q_name=(Dns.Name.string_to_domain_name hostname); 
                     q_type=Q_A; q_class=Q_IN };
      {q_name=(Dns.Name.string_to_domain_name hostname_b); 
                     q_type=Q_TXT; q_class=Q_IN };] in 
    let pkt = { id=(Random.int 0xffff); detail; questions; 
      answers=[]; authorities=[]; additionals; } in 

    lwt reply = send_pkt resolver pkt in  

    lwt _ = 
      if (List.length pkt.answers >= 4) then 
        log ~level:Error 
          (sprintf "multi:%s:result:multi_query:true" ns)
      else 
        log ~level:Error 
          (sprintf "multi:%s:result:multi_query:false" ns)
    in 
    lwt _ = 
      log ~level:Error 
      (sprintf "multi:%s:return:multi_query:%s" 
        ns (Dns.Packet.to_string pkt)) in
      return ()
  with exn ->
    log ~exn ~level:Error 
      (sprintf "multi:%s:result:multi_query:false:failed:" ns)

let test ns =
  try_lwt 
    let config = ( `Static([(ns, 53)], [""]) ) in
    lwt resolver = create ~config () in
 
    let _ = Random.init (int_of_float (Unix.gettimeofday ())) in 

    lwt _ = multi_additional resolver ns in 
    lwt _ = multi_query resolver ns in 
      return ()
 with exn -> 
   log ~exn ~level:Error 
      (sprintf "multi:%s:result:any:false:failed:" ns)

