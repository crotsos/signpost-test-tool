/*
 * =====================================================================================
 *
 *       Filename:  lwt_unix_job_iodine.c*
 *    Description:  
 *
 *        Version:  1.0
 *        Created:  18/11/2012 21:00:52
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  YOUR NAME (), 
 *   Organization:  
 *
 * =====================================================================================
 */
#include <stdlib.h>

/* Caml headers. */
#include "lwt_unix.h"
#include "common.h"
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/signals.h>

#if !defined(LWT_ON_WINDOWS)

/* Specific headers. */
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <stdio.h>

/* +-----------------------------------------------------------------+
   | Asynchronous job                                                |
   +-----------------------------------------------------------------+ */

/* Structure holding informations for calling [iodine]. */
struct job_iodine {
  /* Informations used by lwt. It must be the first field of the structure. */
  struct lwt_unix_job job;
  /* This field store the result of the call. */
  int result;
  /* This field store the value of [errno] after the call. */
  int errno_copy;

  char *ns; 
};

/* The function calling [iodine]. */
static void worker_iodine(struct job_iodine* job)
{
  /* Perform the blocking call. */
  // job->result = iodine(job->fd);
  printf("running main function...\n");
  struct iodine_conf *conf = create_iodine_conf(); 
  printf("running main function %p...\n", conf);
  conf->foreground = 1;
  conf->raw_mode = 0; 
  conf->nameserv_addr = job->ns;
  conf->topdomain = "i.measure.signpo.st";
  strcpy(conf->password, "signpost");
  iodine_main_method(conf);

  /* Save the value of errno. */
  job->errno_copy = 0;
}

/* The function building the caml result. */
static value result_iodine(struct job_iodine* job)
{
  /* Check for errors. */
  if (job->result < 0) {
    /* Save the value of errno so we can use it once the job has been freed. */
    int error = job->errno_copy;
    /* Free the job structure. */
    lwt_unix_free_job(&job->job);
    /* Raise the error. */
    unix_error(error, "iodine", Nothing);
  }
  /* Free the job structure. */
  lwt_unix_free_job(&job->job);
  /* Return the result. */
  return Val_unit;
}

/* The stub creating the job structure. */
CAMLprim value lwt_unix_iodine_job(value ns)
{
  /* Allocate a new job. */
  struct job_iodine* job = lwt_unix_new(struct job_iodine);

  job->ns = (char *)malloc(strlen(String_val(ns))+1);
  strcpy(job->ns, String_val(ns));
  /* Initializes function fields. */
  job->job.worker = (lwt_unix_job_worker)worker_iodine;
  job->job.result = (lwt_unix_job_result)result_iodine;
  /* Wrap the structure into a caml value. */
  return lwt_unix_alloc_job(&job->job);
}


#endif /* !defined(LWT_ON_WINDOWS) */


