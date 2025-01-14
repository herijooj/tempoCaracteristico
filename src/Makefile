CC=gcc
CFLAGS=-Wall -O2
LDFLAGS=-lm
BINDIR=../bin

$(BINDIR)/tempo_caracteristico: tempo_caracteristico.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(BINDIR)/tempo_caracteristico
