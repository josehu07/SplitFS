# Build microbenchmark for splitfs

CC=gcc
CFLAGS=-Wall -O3

.PHONY: all clean

all: rw_expt

rw_expt: rw_experiment.c
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -f rw_expt
