all: task0

task0: start.o main.o
	ld -m elf_i386 start.o main.o -o task0

main.o: main.c
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector main.c -o main.o

start.o: start.s
	nasm -g -f elf32 start.s -o start.o

clean:
	rm -f *.o task0