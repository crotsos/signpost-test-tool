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

open Ssl
open Lwt_ssl

open Lwt
open Lwt_unix 
open Lwt_log
open Lwt_process


open Config

type server_state = {
  mutable test_count : int32;
  mutable in_progress : (int32 * Lwt_log.logger) list;
  lock : Lwt_mutex.t;
}

let init_state () = 
  try 
    let fd = open_in "test_count.conf" in
    let test_count = Int32.of_string (input_line fd) in 
    let _ = close_in fd in 
    {test_count;in_progress=[];lock=(Lwt_mutex.create ());}
  with exn ->
    let _ = printf "load error: %s\n%!" 
              (Printexc.to_string exn) in 
    {test_count=0l;in_progress=[];lock=(Lwt_mutex.create ());}

(* persist session ids in order to avoid record rewritting *)
let get_new_id st = 
  let test_id = st.test_count in 
  let _ = 
    st.test_count <- Int32.add st.test_count 1l in
  let fd = open_out "test_count.conf" in
  let _ = Pervasives.output_string fd (Int32.to_string st.test_count) in
  let _ = Pervasives.flush fd in 
  let _ = Pervasives.close_out fd in 
    test_id
 
(* A small struct to save results *)
type tcp_stats = {
  mutable send_data: int32;
  mutable bin_data: int32;
}

(* Measurement channel *)

(* download test function *)
let rcv_data_test_fd stats fd = 
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
      return (printf "test finished\n%!")
  with exn -> 
    let _ = printf "error %s\n%!" (Printexc.to_string exn) in
      return ()

(* upload test function *)
let snd_data_test_fd stats fd = 
  let rand = open_in "/dev/urandom" in 
  let start = Unix.gettimeofday () in 
  let buf = String.create 2046 in 
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

(* Output partial results *)
let print_stats dir logger stats =
    let start = Unix.gettimeofday () in
      while_lwt (start +. duration +. 1.0 >= (Unix.gettimeofday ())) do
        lwt _ = Lwt_unix.sleep 1.0 in
        lwt _ = log ~level:Error ~logger:logger
          (sprintf "tcp_rate:%s:%ld" dir stats.bin_data) in
        let _ = stats.bin_data <- 0l in
          return ()
      done

let sockaddr_to_string = function
  | ADDR_INET (ip, port) -> 
      sprintf "%s:%d" (Unix.string_of_inet_addr ip) port
  | ADDR_UNIX file -> file

let get_logger st id = 
        try
          let (_, logger) =
            List.find (
              fun (rec_id, _) -> id = rec_id) 
            st.in_progress 
          in
            Some logger
        with Not_found -> None
 
(* Listening measurement plane *)
let measure_t st = 
    let fd = socket PF_INET SOCK_STREAM 0 in
    (* reuse the socket port *)
    let _ = setsockopt fd SO_REUSEADDR true in 
    let _ = bind fd (ADDR_INET(Unix.inet_addr_any, measurement_port)) in 
    let _ = listen fd 10 in
    while_lwt true do 
      try_lwt 
        lwt (client_fd, dst) = accept fd in
        let buf = String.create 6 in 
        lwt _ = recv client_fd buf 0 6 [] in 
        let id = Int32.of_string buf in 
          match (get_logger st id) with
          | None -> 
            let _ = printf "invalid_connection:%s\n%!" 
                      (sockaddr_to_string dst) in 
            Lwt_unix.close client_fd
          | Some logger -> begin
            try_lwt
              lwt _ = log ~logger ~level:Error
                        (sprintf "client:%s" 
                        (sockaddr_to_string dst)) in 
              let stats = {send_data=0l; bin_data=0l;} in
              lwt _ = rcv_data_test_fd stats client_fd 
                        <?> print_stats "rcv" logger stats in
              lwt _ = log ~logger ~level:Error
                        "reverse_start" in 
              let stats = {send_data=0l; bin_data=0l;} in
              lwt _ = snd_data_test_fd stats client_fd 
                        <?> print_stats "snd" logger stats in 
              lwt _ = Lwt_unix.close client_fd in  
                return () 
            with exn -> 
              log ~logger ~exn ~level:Error "measurement_err" 
          end
    with exn ->
      return (printf "measurement error %s\n%!" (Printexc.to_string exn))

    done

let run_test st test_id src in_ch out_ch () = 
  let template = 
    "$(date).$(milliseconds) $(loc-file):$(loc-line)[$(pid)]: $(message)" in 
  (* create log directory and start the logger *) 
  let dest_dir = sprintf "%s/%05ld/" result_dir  test_id in
  let _ = mkdir dest_dir 0o777 in
  lwt _ = Lwt_unix.sleep 0.1 in 
  let pcap_eth_file = dest_dir ^ "eth0.pcap" in
  let pcap_eth_log = dest_dir ^ "tcpdump_eth0.log" in
  let pcap_eth_fd = Unix.openfile pcap_eth_log 
                      [Unix.O_WRONLY;Unix.O_CREAT;]
                      0o666 in

  let pcap_dns_file = dest_dir ^ "dns0.pcap" in
  let pcap_dns_log = dest_dir ^ "tcpdump_dns.log" in
  let pcap_dns_fd = Unix.openfile pcap_dns_log 
                      [Unix.O_WRONLY;Unix.O_CREAT;]
                      0o666 in

  lwt file_log = 
    file ~template ~mode:`Truncate 
      ~file_name:(sprintf "%s/%05ld/signpost-test-result.log" result_dir
      test_id) () in
  let tcpdump_eth = 
    Lwt_process.open_process_none 
      ~stdout:(Lwt_process.(`FD_copy pcap_eth_fd)) 
      ~stderr:(Lwt_process.(`FD_copy pcap_eth_fd))
      ("tcpdump", [|"tcpdump"; "-i";intf; "-w";pcap_eth_file;|]) in 
  let tcpdump_dns = 
    Lwt_process.open_process_none 
      ~stdout:(Lwt_process.(`FD_copy pcap_dns_fd)) 
      ~stderr:(Lwt_process.(`FD_copy pcap_dns_fd))
      ("tcpdump", [|"tcpdump"; "-i";intf; "-w";pcap_dns_file;|]) in 
     let addr =
      match src with
      | ADDR_INET (ip, _) -> ip
      | _ -> failwith "Unsupported socket type"
    in
   try_lwt
   let _ = st.in_progress <- st.in_progress @ [(test_id, file_log)] in 
    lwt _ = log ~logger:file_log ~level:Error (sockaddr_to_string src) in  

    (* tell client to start *)
    let hello = (Jsonrpc.string_of_call 
                  Rpc.({name="start_test";params=[Rpc.Null];})) 
                  ^ "\n" in 
    lwt _ = Lwt_chan.output_string out_ch hello in 
    lwt _ = Lwt_chan.flush out_ch in

  
    (* Wait for the client to terminate *)
    lwt req = Lwt_chan.input_line in_ch in
    let _ = printf "client %s connected ....\n%!" (sockaddr_to_string src) in 
    let req = Jsonrpc.call_of_string req in
    lwt _ = 
      if(req.Rpc.name == "end_test") then
        let reply = 
          (Jsonrpc.string_of_response 
            Rpc.({success=true;contents=Rpc.Null;})) 
                ^ "\n" in 
        lwt _ = Lwt_chan.output_string out_ch reply in 
          Lwt_chan.flush out_ch
      else
        lwt _ = log ~level:Error 
          (sprintf "ignoring_request:%s" req.Rpc.name) in
        let reply = 
          (Jsonrpc.string_of_response 
            Rpc.({success=false;contents=Rpc.Null;})) 
                ^ "\n" in 
        lwt _ = Lwt_chan.output_string out_ch reply in 
          Lwt_chan.flush out_ch
    in
    let _ = st.in_progress <- 
      List.filter (fun (id, _) -> 
        not (test_id = id) ) st.in_progress in
    let _ = tcpdump_eth#terminate in 
    let _ = tcpdump_dns#terminate in 
    let _ = Unix.close pcap_eth_fd in 
    let _ = Unix.close pcap_dns_fd in 
    lwt _ = Lwt_log.close file_log in 
      return () 
  with exn -> 
    lwt _ = log ~logger:file_log ~exn ~level:Error "test_error" in 
    let _ = st.in_progress <- 
      List.filter (fun (id, _) -> 
        not (test_id = id) ) st.in_progress in
    let _ = tcpdump_eth#terminate in 
    let _ = tcpdump_dns#terminate in 
    let _ = Unix.close pcap_eth_fd in 
    let _ = Unix.close pcap_dns_fd in 
    lwt _ = Lwt_log.close file_log in 
      return ()


(* rate control mechanism *)
let process_ctrl st test_id src in_ch out_ch = 
  try_lwt
    let _ = printf "client %s connected ....\n%!" (sockaddr_to_string src) in 
    lwt req = Lwt_chan.input_line in_ch in 
    let req = Jsonrpc.call_of_string req in
    lwt _ = 
      match req.Rpc.name with
      | "hello" -> 
          let reply = 
            (Jsonrpc.string_of_response 
              Rpc.({success=true;
                    contents=(Rpc.Int (Int64.of_int32 test_id));})) 
                  ^ "\n" in 
          lwt _ = Lwt_chan.output_string out_ch reply in 
          lwt _ = Lwt_chan.flush out_ch in 
          lwt _ = Lwt_mutex.with_lock st.lock  
                    (run_test st test_id src in_ch out_ch) in 
            return ()
 
      | _ -> 
          let reply = 
            (Jsonrpc.string_of_response 
              Rpc.({success=false;contents=Rpc.Null;})) 
                  ^ "\n" in 
          lwt _ = Lwt_chan.output_string out_ch reply in
          lwt _ = Lwt_chan.flush out_ch in
           return ()
    in
    lwt _ = Lwt_chan.close_in in_ch <&> 
              Lwt_chan.close_out out_ch in 
       return ()
  with exn ->
     lwt _ = Lwt_chan.close_in in_ch <&> 
              Lwt_chan.close_out out_ch in 
     let _ = printf "ctrl client error:%s\n%!" 
              (Printexc.to_string exn) in 
      return ()

(* open an ssl connection *)
let open_ssl_server () =
  (* open socket *)
  let fd = socket PF_INET SOCK_STREAM 0 in
  let _ = setsockopt fd SO_REUSEADDR true in 
  let _ = bind fd (ADDR_INET(Unix.inet_addr_any, ctrl_port)) in 
  let _ = listen fd 10 in

  (* add certificates in context *)
  let ctx = Ssl.create_context Ssl.SSLv3 Ssl.Server_context in 
  let _ = Ssl.use_certificate ctx "server.crt" "server.key" in 
  let _ = Ssl.set_client_CA_list_from_file ctx "ca.crt" in
    (fd, ctx)

(* control server *)
let control_t st = 
  try_lwt
    let (fd, ctx) = open_ssl_server () in 
      while_lwt true do
        let test_id = get_new_id st in
        
        (* setup the required socket state *)
        lwt (client_fd, src) = Lwt_unix.accept fd in 
        lwt client_fd = Lwt_ssl.ssl_accept client_fd ctx in 
        let in_ch = Lwt_ssl.in_channel_of_descr client_fd in 
        let out_ch = Lwt_ssl.out_channel_of_descr client_fd in 
 
       (* start processing the control channel *)
        let _ = ignore_result 
          (lwt _ = process_ctrl st test_id src in_ch out_ch in 
            Lwt_ssl.close client_fd 
          ) in 
          return () 
      done
  with exn ->
    let _ = printf "ctrl client error:%s\n%!" (Printexc.to_string exn) in 
      return ()

lwt _ =
  let _ = Ssl.init () in 
  let st = init_state () in 
    measure_t st <?> control_t st
