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

let resolver_file = "/etc/resolv.conf" 

  let load_resolv_file file =
  try 
    lwt fd = openfile file [O_RDONLY] 0o640 in
    let fd = of_fd ~mode:(input) fd in 
    let rec read_file fd = 
      match_lwt (read_line_opt fd) with 
      | None -> return ([], "")
      | Some line when (Re_str.string_match (Re_str.regexp "^[\t\ ]*#") line 0) ->
            read_file fd
      | Some line  ->
          match Re_str.split (Re_str.regexp "[\ \t]+") line with 
            | "nameserver"::value::_ ->
                lwt (ns, domain) = read_file fd in 
                lwt _ = log ~level:Error (sprintf "domain:%s" value) in
                  return (ns@[value], domain)

            | "domain"::value::_ ->
                lwt (ns, domain) = read_file fd in
                lwt _ = log ~level:Error (sprintf "nameserver:%s" value) in
                  return (ns, value)
            | _ -> read_file fd
    in
    lwt (ns, domain) = read_file fd in 
      return (ns, domain)
  with exn -> 
    lwt _ = log ~exn ~level:Error "failed to load resolv.conf" in 
      return ([], "") 

lwt _ =
  (* setup loggers *)
  let std_log = !default in 
  let template = "$(date).$(milliseconds) $(loc-file):$(loc-line)[$(pid)]: $(message)" in 
  lwt file_log = file ~template ~mode:`Truncate ~file_name:"signpost-test-result.log"
                   () in 
  let _ = default := broadcast [file_log; std_log; ] in 
  let _ = printf "Starting test...\n%!" in
  lwt (nameservers, domain) = 
    load_resolv_file resolver_file 
  in
  lwt _ = 
    Lwt_list.iter_s (
      fun ns ->
        (* can I connect to remote ns *)
        lwt _ = Direct.test ns in

        (* can I request non dnssec rr types? *)
        lwt _ = Recursive.test ns false in 

        (* can I query for dnssec rr types? *)
        lwt _ = Recursive.test ns true in 

        (* check if sig0 can go throught the resolver *)

        (* check if iodine can get through, and 
         * what is the capacity ? *)
          return () 
    ) nameservers
  in
  lwt _ = Lwt_log.close file_log in 
    return ()

