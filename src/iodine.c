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

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/time.h>
#include <fcntl.h>
#include <time.h>

#ifdef WINDOWS32
#include "windows.h"
#include <winsock2.h>
#else
#include <grp.h>
#include <pwd.h>
#endif

#include "common.h"
#include "tun.h"
#include "client.h"
#include "util.h"

#ifdef WINDOWS32
WORD req_version = MAKEWORD(2, 2);
WSADATA wsa_data;
#endif

#if !defined(BSD) && !defined(__GLIBC__)
static char *__progname;
#endif

#define PASSWORD_ENV_VAR "IODINE_PASS"

static void
sighandler(int sig) 
{
	client_stop();
}

static void
usage() {
	extern char *__progname;

	fprintf(stderr, "Usage: %s [-v] [-h] [-f] [-r] [-u user] [-t chrootdir] [-d device] "
			"[-P password] [-m maxfragsize] [-M maxlen] [-T type] [-O enc] [-L 0|1] [-I sec] "
			"[-z context] [-F pidfile] [nameserver] topdomain\n", __progname);
	exit(2);
}

static void
help() {
	extern char *__progname;

	fprintf(stderr, "iodine IP over DNS tunneling client\n");
	fprintf(stderr, "Usage: %s [-v] [-h] [-f] [-r] [-u user] [-t chrootdir] [-d device] "
			"[-P password] [-m maxfragsize] [-M maxlen] [-T type] [-O enc] [-L 0|1] [-I sec] "
			"[-z context] [-F pidfile] [nameserver] topdomain\n", __progname);
	fprintf(stderr, "Options to try if connection doesn't work:\n");
	fprintf(stderr, "  -T force dns type: NULL, TXT, SRV, MX, CNAME, A (default: autodetect)\n");
	fprintf(stderr, "  -O force downstream encoding for -T other than NULL: Base32, Base64, Base64u,\n");
	fprintf(stderr, "     Base128, or (only for TXT:) Raw  (default: autodetect)\n");
	fprintf(stderr, "  -I max interval between requests (default 4 sec) to prevent DNS timeouts\n");
	fprintf(stderr, "  -L 1: use lazy mode for low-latency (default). 0: don't (implies -I1)\n");
	fprintf(stderr, "  -m max size of downstream fragments (default: autodetect)\n");
	fprintf(stderr, "  -M max size of upstream hostnames (~100-255, default: 255)\n");
	fprintf(stderr, "  -r to skip raw UDP mode attempt\n");
	fprintf(stderr, "  -P password used for authentication (max 32 chars will be used)\n");
	fprintf(stderr, "Other options:\n");
	fprintf(stderr, "  -v to print version info and exit\n");
	fprintf(stderr, "  -h to print this help and exit\n");
	fprintf(stderr, "  -f to keep running in foreground\n");
	fprintf(stderr, "  -u name to drop privileges and run as user 'name'\n");
	fprintf(stderr, "  -t dir to chroot to directory dir\n");
	fprintf(stderr, "  -d device to set tunnel device name\n");
	fprintf(stderr, "  -z context, to apply specified SELinux context after initialization\n");
	fprintf(stderr, "  -F pidfile to write pid to a file\n");
	fprintf(stderr, "nameserver is the IP number/hostname of the relaying nameserver. if absent, /etc/resolv.conf is used\n");
	fprintf(stderr, "topdomain is the FQDN that is delegated to the tunnel endpoint.\n");

	exit(0);
}

static void
version() {
	fprintf(stderr, "iodine IP over DNS tunneling client\n");
	fprintf(stderr, "version: 0.6.0-rc1 from 2010-02-13\n");

	exit(0);
}

int
iodine_main_method(struct iodine_conf *conf)
{
  int tun_fd;
  int dns_fd;
  int retval = 0;
  srand(time(NULL));

#ifdef WINDOWS32
  WSAStartup(req_version, &wsa_data);
#endif

  srand((unsigned) time(NULL));
  printf("iodine_main_method...\n");
  client_init();

  check_superuser(usage);

  if (conf->max_downstream_frag_size < 1 || conf->max_downstream_frag_size > 0xffff) {
    warnx("Use a max frag size between 1 and 65535 bytes.\n");
    usage();
    /* NOTREACHED */
  }

  if (conf->nameserv_addr) {
    client_set_nameserver(conf->nameserv_addr, DNS_PORT);
  } else {
    warnx("No nameserver found - not connected to any network?\n");
    usage();
    /* NOTREACHED */
  }	

  if (strlen(conf->topdomain) <= 128) {
    if(check_topdomain(conf->topdomain)) {
      warnx("Topdomain contains invalid characters.\n");
      usage();
      /* NOTREACHED */
    }
  } else {
    warnx("Use a topdomain max 128 chars long.\n");
    usage();
    /* NOTREACHED */
  }

  client_set_selecttimeout(conf->selecttimeout);
  client_set_lazymode(conf->lazymode);
  client_set_topdomain(conf->topdomain);
  client_set_hostname_maxlen(conf->hostname_maxlen);

  if (conf->username != NULL) {
#ifndef WINDOWS32
    if ((conf->pw = getpwnam(conf->username)) == NULL) {
      warnx("User %s does not exist!\n", conf->username);
      usage();
      /* NOTREACHED */
    }
#endif
  }

  if (strlen(conf->password) == 0) {
    if (NULL != getenv(PASSWORD_ENV_VAR))
      snprintf(conf->password, sizeof(conf->password), "%s", 
          getenv(PASSWORD_ENV_VAR));
    else
      read_password(conf->password, sizeof(conf->password));
  }

  client_set_password(conf->password);

  if ((tun_fd = open_tun(conf->device)) == -1) {
    retval = 1;
    goto cleanup1;
  }
  if ((dns_fd = open_dns(0, INADDR_ANY)) == -1) {
    retval = 1;
    goto cleanup2;
  }

/*  signal(SIGINT, sighandler);
  signal(SIGTERM, sighandler);*/

  fprintf(stderr, "Sending DNS queries for %s to %s\n",
      conf->topdomain, conf->nameserv_addr);

  if (client_handshake(dns_fd, conf->raw_mode, conf->autodetect_frag_size, 
        conf->max_downstream_frag_size)) {
    retval = 1;
    goto cleanup2;
  }

  if (client_get_conn() == CONN_RAW_UDP) {
    fprintf(stderr, "Sending raw traffic directly to %s\n", client_get_raw_addr());
  }

  fprintf(stderr, "Connection setup complete, transmitting data.\n");

  if (conf->username != NULL) {
#ifndef WINDOWS32
    gid_t gids[1];
    gids[0] = conf->pw->pw_gid;
    if (setgroups(1, gids) < 0 || setgid(conf->pw->pw_gid) < 0 || 
        setuid(conf->pw->pw_uid) < 0) {
      warnx("Could not switch to user %s!\n", conf->username);
      usage();
      /* NOTREACHED */
    }
#endif
  }
  
 client_tunnel(tun_fd, dns_fd);

cleanup2:
  close_dns(dns_fd);
  close_tun(tun_fd);
cleanup1:

  return retval;
}

