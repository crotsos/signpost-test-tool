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

open Lwt_unix 

let tcp_server_port = 5353

type tcp_stats = {
  mutable send_data: int32;
  mutable bin_data: int32;
}

let process_fd stats fd = 
  let buf = String.create 4096 in 
  let len = ref 4096 in 
  try_lwt
    lwt _ = 
      while_lwt (!len > 0) do
        lwt l = recv fd buf 0 4096 [] in
        let _ = len := l in 
        let _ = stats.send_data <-
          Int32.add stats.send_data (Int32.of_int !len) in
        let _ = stats.bin_data <-
          Int32.add stats.bin_data (Int32.of_int !len) in

        return ()
      done
    in
    lwt _ = Lwt_unix.close fd in  
      return (printf "test finished\n%!")
  with exn -> 
    let _ = printf "error %s\n%!" (Printexc.to_string exn) in
    lwt _ = Lwt_unix.close fd in  
      return ()


let print_stats stats =
    let start = Unix.gettimeofday () in
      while_lwt (start +. 20.0 >= (Unix.gettimeofday ())) do
        lwt _ = Lwt_unix.sleep 1.0 in
        lwt _ = log ~level:Error
          (sprintf "tcp rate %ld bytes/sec" stats.bin_data) in
        let _ = stats.bin_data <- 0l in
          return ()
      done

lwt _ =
  let fd = socket PF_INET SOCK_STREAM 0 in
  let _ = setsockopt fd SO_REUSEADDR true in 
  let _ = bind fd (ADDR_INET(Unix.inet_addr_any, tcp_server_port)) in 
  let _ = listen fd 10 in

  while_lwt true do 
    lwt (fd, dst) = accept fd in
    let _ = printf "server connected \n%!" in 
    let stats = {send_data=0l; bin_data=0l;} in
    let _ = ignore_result (process_fd stats fd <?> print_stats stats) in 
      return () 
  done
