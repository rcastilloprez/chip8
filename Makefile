CC = gcc
CFLAGS = -g -I./include
LIBS = -L./lib -lSDL3
FLAGS = -g
INCLUDES = -I ./include

OBJECTS = ./build/chip8memory.o ./build/chip8stack.o ./build/chip8keyboard.o

all: ${OBJECTS}
	$(CC) $(CFLAGS) ./src/main.c ${OBJECTS} -o ./bin/main $(LIBS)


build/chip8memory.o:src/chip8memory.c
	gcc ${FLAGS} ${INCLUDES} ./src/chip8memory.c -c -o ./build/chip8memory.o

build/chip8stack.o:src/chip8stack.c
	gcc ${FLAGS} ${INCLUDES} ./src/chip8stack.c -c -o ./build/chip8stack.o

build/chip8keyboard.o:src/chip8keyboard.c
	gcc ${FLAGS} ${INCLUDES} ./src/chip8keyboard.c -c -o ./build/chip8keyboard.o

build/chip8.o:src/chip8.c
	gcc ${FLAGS} ${INCLUDES} ./src/chip8.c -c -o ./build/chip8.o


clean:
	rm -f ./build/*.o