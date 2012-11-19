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

let tcp_server_port = 5354

let process_fd fd = 
  let buf = String.create 4096 in 
  try_lwt 
    while_lwt true do
      lwt len = 
        recv fd buf 0 4096 [] in 
      let _ = printf "received %d\n%!" len in 
        return ()
    done
  
  with exn -> 
    let _ = printf "error %s\n%!" (Printexc.to_string exn) in 
      return ()

lwt _ =
  let fd = socket PF_INET SOCK_STREAM 0 in 
  let _ = listen fd tcp_server_port in

  while_lwt true do 
    lwt (fd, dst) = accept fd in
    let _ = printf "server connected \n%!" in 
    let _ = ignore_result (process_fd fd) in 
      return () 
  done
