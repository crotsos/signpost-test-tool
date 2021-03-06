/*
 * Copyright (c) 2006-2009 Bjorn Andersson <flex@kryo.se>, Erik Ekman <yarrick@kryo.se>
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
 */

#ifndef __CLIENT_H__
#define __CLIENT_H__

void client_init();
void client_stop();

enum connection client_get_conn();
const char *client_get_raw_addr();

void client_set_nameserver(const char *cp, int port);
void client_set_topdomain(const char *cp);
void client_set_password(const char *cp);
void set_qtype(char *qtype);
char *get_qtype();
void set_downenc(char *encoding);
void client_set_selecttimeout(int select_timeout);
void client_set_lazymode(int lazy_mode);
void client_set_hostname_maxlen(int i);

int client_handshake(int dns_fd, int raw_mode, int autodetect_frag_size, int fragsize);
int client_tunnel(int tun_fd, int dns_fd);

#endif
