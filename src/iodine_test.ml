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

external iodine_job : string -> unit job = "lwt_unix_iodine_job"

let run_iodine ns t = 
  (t <?>
      run_job ~async_method:(Async_detach) (iodine_job ns))

type tcp_stats = {
  mutable send_data: int32;
  mutable bin_data: int32;
}

let snd_data stats fd = 
  let rand = open_in "/dev/urandom" in 
  let start = Unix.gettimeofday () in 
  let buf = String.create 4096 in 
    while_lwt (start +. duration >= (Unix.gettimeofday ())) do 
      let len = Pervasives.input rand buf 0 2046 in 
      lwt len = send fd buf 0 len [] in
      let _ = stats.send_data <- 
        Int32.add stats.send_data (Int32.of_int len) in 
      let _ = stats.bin_data <- 
        Int32.add stats.bin_data (Int32.of_int len) in 
      lwt _ = Lwt_unix.sleep 0.0 in 
        return ()
    done

let rcv_data stats fd = 
  let len = ref 4096 in
  let buf = String.create 4096 in 
    while_lwt (!len > 0) do
      lwt l = recv fd buf 0 4096 [] in
      let _ = len := l in 
      let _ = stats.send_data <-
        Int32.add stats.send_data (Int32.of_int !len) in
      let _ = stats.bin_data <-
        Int32.add stats.bin_data (Int32.of_int !len) in
      return ()
    done

let print_stats typ stats = 
  let start = Unix.gettimeofday () in 
    while_lwt (start +. duration +. 1.0 >= (Unix.gettimeofday ())) do 
      lwt _ = Lwt_unix.sleep 1.0 in 
      lwt _ = log ~level:Error 
      (sprintf "tcp_rate:%s:%ld" typ stats.bin_data) in 
      let _ = stats.bin_data <- 0l in 
        return ()
    done

let tcp_test test_id stats host = 
  try_lwt 
    let fd = socket PF_INET SOCK_STREAM 0 in 

    let addr = Unix.inet_addr_of_string host in  
(*    lwt host = 
      lwt host = Lwt_unix.gethostbyaddr host in
        return (host.h_addr_list.(0))
    in*)
    
    let dest = ADDR_INET(addr, measurement_port) in
    lwt _ = connect fd dest in 
    let buf = sprintf "%06ld" test_id in 
    lwt _ = send fd buf 0 6 [] in 
    lwt _ = snd_data stats fd <&> print_stats "snd" stats in

    let _ = stats.send_data <- 0l in 
    let _ = stats.bin_data <- 0l in
    let _ = printf "restart test...\n%!" in
    lwt _ = rcv_data stats fd <&> print_stats "rcv" stats in 
    lwt _ = Lwt_unix.close fd in 
      return ()
  with exn -> 
    lwt _ = log ~level:Error 
    (sprintf "iodine_test tcp to %s failed: %s" host 
    (Printexc.to_string exn)) in 
    return () 

let test id ns =
  try_lwt 
    let (t, u) = Lwt.wait () in 
    let stats = {send_data=0l; bin_data=0l;} in
    let dst_ip = "127.0.0.1" in (*"54.243.31.36" *) 
    lwt _ = tcp_test id stats dst_ip in 
(*    let _ = ignore_result (run_iodine ns t) in *)
    lwt _ = log ~level:Error "iodine_test running" in 
  
(*   lwt _ = Lwt_unix.sleep 20.0 in *)
   let _ = wakeup u () in 
     return ()
  with exn ->
    log ~exn ~level:Error "direct test failed"
