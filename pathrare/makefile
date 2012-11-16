CC=gcc

CFLAGS=-g -O2 
CPPFLAGS=
LIBS=-lm   
LDFLAGS=

SRC=  pathrate_snd.c pathrate_snd_func.c pathrate_snd.h pathrate_rcv.c pathrate_rcv_func.c pathrate_rcv.h pathrate.h    

SOBJS=   pathrate_snd.o pathrate_snd_func.o
ROBJS=   pathrate_rcv.o pathrate_rcv_func.o
OBJS=    $(SOBJS) $(ROBJS)

TARGETS=pathrate_snd pathrate_rcv

all:${TARGETS}

pathrate_snd: $(SOBJS)
	 $(CC) $(SOBJS) -o pathrate_snd $(LIBS) $(LDFLAGS)
	 rm $(SOBJS)

pathrate_rcv: $(ROBJS)
	 $(CC) $(ROBJS) -o pathrate_rcv $(LIBS) $(LDFLAGS)
	 rm $(ROBJS)

clean: 
	 rm -f ${OBJS} ${TARGETS}

.c.o:
	$(CC) -c -Wall $(CPPFLAGS) $(DEFS) $(CFLAGS) $<

