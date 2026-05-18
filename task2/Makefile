all: task2

# Notice we include main.o for Task 2
task2: start.o main.o util.o
	ld -m elf_i386 start.o main.o util.o -o task2

main.o: main.c
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector main.c -o main.o

util.o: util.c
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector util.c -o util.o

start.o: start.s
	nasm -g -f elf32 start.s -o start.o

clean:
	rm -f *.o task2