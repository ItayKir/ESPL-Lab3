# Default target to build both programs
all: task1 task2

# Link Task 1: start.o (glue), task1.o (assembly encoder), util.o
task1: start.o task1.o util.o
	ld -m elf_i386 start.o task1.o util.o -o task1

# Link Task 2: start.o (glue + virus), main.o (C dir lister), util.o
task2: start.o main.o util.o
	ld -m elf_i386 start.o main.o util.o -o task2

# Compile the C main file for Task 2
main.o: main.c
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector main.c -o main.o

# Compile the C utility file (used by both tasks)
util.o: util.c
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector util.c -o util.o

# Assemble the NASM file for Task 1
task1.o: task1.s
	nasm -g -f elf32 task1.s -o task1.o

# Assemble the start.s file (used by both, contains _start, system_call, and infector)
start.o: start.s
	nasm -g -f elf32 start.s -o start.o

.PHONY: clean
clean:
	rm -f *.o task1 task2 test.txt