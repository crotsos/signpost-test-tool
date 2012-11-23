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

open Ssl
open Lwt_ssl

open Lwt_log 
open Lwt_unix 
open Lwt_io 

open Config

type 'a t

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

let control_t () =  
    let ctx = Ssl.create_context Ssl.SSLv3 Ssl.Client_context in
    let _ = Ssl.use_certificate ctx "client.crt" "client.key" in 
    let _ = Ssl.set_client_CA_list_from_file ctx "ca.crt" in
  
    let fd = socket PF_INET SOCK_STREAM 0 in
    (* connecting socket to control channel *)
    let addr = Unix.inet_addr_of_string "127.0.0.1" (* host *) in  
    let dest = ADDR_INET(addr, ctrl_port) in
    lwt _ = connect fd dest in 
    lwt client_fd = Lwt_ssl.ssl_connect fd ctx in
    let ch_in = Lwt_ssl.in_channel_of_descr client_fd in 
    let ch_out = Lwt_ssl.out_channel_of_descr client_fd in 
      return (fd, ch_in, ch_out) 

let test id nameservers =
  lwt _ = 
    Lwt_list.iter_s (
      fun ns ->
          (* can I connect to remote ns *)
(*          lwt _ = Direct.test ns in *)

          (* can I request non dnssec rr types? *)
(*          lwt _ = Recursive.test ns false in *)

          (* rerequesting the records to check if ttl is respected *)
(*          lwt _ = Recursive.test ns false in *)

          (* can I query for dnssec rr types? *)
(*          lwt _ = Recursive.test ns true in *)
  
          (* multiple queries and rr in queries *)
(*          lwt _ = Multi.test ns in *)

          (* check if sig0 can go throught the resolver *)
          lwt _ = Sig0.test ns in 

          (* check if iodine can get through, and 
           * what is the capacity ? *)
(*          lwt _ = Iodine_test.test id ns in *)
            return () 
    ) nameservers
  in
    return ()

lwt _ =
  let std_log = !default in 
  let template = "$(date).$(milliseconds) $(loc-file):$(loc-line)[$(pid)]: $(message)" in 
  lwt file_log = file ~template ~mode:`Truncate ~file_name:"signpost-test-result.log"
                   () in 
  let _ = default := broadcast [file_log; std_log; ] in 
   try_lwt 
    let _ = Ssl.init () in 
    (* setup loggers *)
    lwt _ = log ~level:Error 
            "--------- Starting signpost dns test ---------\n%!" in
    lwt (nameservers, domain) = load_resolv_file resolver_file in
    lwt (fd, ch_in, ch_out) = control_t () in 
    let _ = printf "sever connected....\n%!" in
    let hello = (Jsonrpc.string_of_call Rpc.({name="hello";params=[Rpc.Null];})) 
                  ^ "\n" in 
    lwt _ = Lwt_chan.output_string ch_out hello in 
    lwt _ = Lwt_chan.flush ch_out in

    lwt resp = Lwt_chan.input_line ch_in in 
    let resp = Jsonrpc.response_of_string resp in 
    let id = 
      match (resp.Rpc.success, resp.Rpc.contents) with
      | (true, Rpc.Int id) -> Int64.to_int32 id
      | (false, _) -> failwith "failed to manage results"
      | (true, _) -> failwith "invalid test id"
    in
    
    let rec run_test_inner () = 
      lwt req = Lwt_chan.input_line ch_in in 
      let req = Jsonrpc.call_of_string req in
        if(req.Rpc.name = "start_test") then
          test id nameservers
        else
          lwt _ = log ~level:Error 
          (sprintf "ignoring request %s\n%!" req.Rpc.name) in
          let reply = 
            (Jsonrpc.string_of_response 
              Rpc.({success=true;contents=Rpc.Null;})) 
                  ^ "\n" in 
          lwt _ = Lwt_chan.output_string ch_out reply in 
          lwt _ = Lwt_chan.flush ch_out in 
          lwt _ = run_test_inner () in 
          let fin = (Jsonrpc.string_of_call 
                       Rpc.({name="end_test";params=[Rpc.Null];})) 
                        ^ "\n" in 
          lwt _ = Lwt_chan.output_string ch_out fin in 
          lwt _ = Lwt_chan.flush ch_out in
            return ()

    in
    lwt _ = run_test_inner () in 
    lwt _ = log ~level:Error
              "--------- Finishing signpost dns test ---------" in
    lwt _ = Lwt_log.close file_log in 
      return () 
  with exn -> 
    lwt _ = log ~level:Error ~exn 
              (sprintf "client_error:%s\n%!" (Printexc.to_string exn)) in 
    lwt _ = Lwt_log.close file_log in 
      return ()


