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

let sp_ns_addr = "ns.measure.signpo.st"

let hostname = "types.a.measure.signpo.st"
let test ns =
  try_lwt 
(*    lwt host = Lwt_unix.gethostbyname sp_ns_addr in 
    let ip = Unix.string_of_inet_addr 
              (Array.get host.Unix.h_addr_list 0) in *)
    let ip = "54.243.31.36" in 
    let config = ( `Static([(ip, 53)], [""]) ) in
    lwt resolver = create ~config () in 
    lwt pkt = resolve resolver Q_IN Q_A 
              (Dns.Name.string_to_domain_name hostname) in 
    let _ = log ~level:Error "direct success" in  
    lwt _ = 
      log ~level:Error 
      (sprintf "direct returned %s" (Dns.Packet.to_string pkt)) in  
      return ()
  with exn ->
    log ~exn ~level:Error "direct test failed"


