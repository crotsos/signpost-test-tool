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

let tcp_server_port = 5354

external iodine_job : string -> unit job = "lwt_unix_iodine_job"

let run_iodine ns t = 
  (t <?>
      run_job ~async_method:(Async_detach) (iodine_job ns))

let tcp_test host = 
  try_lwt 
    let fd = socket PF_INET SOCK_STREAM 0 in 

    lwt host = 
      lwt host = Lwt_unix.gethostbyname host in
        return (host.h_addr_list.(0))
    in
    
    let dest = ADDR_INET(host, tcp_server_port) in
    lwt _ = connect fd dest in 
    let rand = open_in "/dev/urandom" in 
    let start = Unix.gettimeofday () in 
    let buf = String.create 2046 in 
    lwt _ = 
      while_lwt (start +. 120.0 <= (Unix.gettimeofday ())) do 
        let len = Pervasives.input rand buf 0 4096 in 
        lwt len = send fd buf 0 len [] in 
          return ()
      done
    in
      return true
  with Not_found -> 
    lwt _ = log ~level:Error 
    (sprintf "iodine_test tcp to %s failed" host) in 
    return false 

let test ns =
  try_lwt 
    let (t, u) = Lwt.wait () in 
    lwt _ = tcp_test "54.243.31.36" in 
    let _ = ignore_result (run_iodine ns t) in 
    lwt _ = log ~level:Error "iodine_test running" in 
  
   lwt _ = Lwt_unix.sleep 20.0 in 
   let _ = wakeup u () in 
     return ()
  with exn ->
    log ~exn ~level:Error "direct test failed"



