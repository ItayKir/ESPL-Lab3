#include "util.h"
#include "dirent.h"

#define SYS_WRITE 4
#define STDOUT 1
#define SYS_OPEN 5
#define O_RDWR 2
#define SYS_SEEK 19
#define SEEK_SET 0
#define SHIRA_OFFSET 0x291

// added by gemini
#define SYS_EXIT      1
#define SYS_READ      3
#define SYS_CLOSE     6
#define SYS_GETDENTS  141

#define O_RDONLY      0
#define BUF_SIZE      8192

extern int system_call();

/* Declare the assembly functions */
extern void infection();
extern void infector(char* filename);

int main(int argc, char *argv[], char *envp[]) {
  int fd, nread;
  char buf[BUF_SIZE];
  int bpos;
  struct linux_dirent *d;
  char *prefix = 0; /* Pointer to hold our -a prefix */
  int i;

  /* ---------------------------------------------------------
    * 1. Parse Command Line Arguments for "-a"
    * ---------------------------------------------------------*/
  for (i = 1; i < argc; i++) {
      /* Check if argument starts with "-a" */
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
  /* bpos tracks our current byte offset within the buffer */
  for (bpos = 0; bpos < nread;) {
      /* Cast the current buffer position to a linux_dirent struct pointer */
      d = (struct linux_dirent *) (buf + bpos);
      char *d_name = d->d_name;

      /* If a prefix was provided via -a */
      if (prefix != 0) {
          /* Check if the filename starts with the exact prefix */
          if (strncmp(d_name, prefix, strlen(prefix)) == 0) {
              system_call(SYS_WRITE, 1, d_name, strlen(d_name));
              system_call(SYS_WRITE, 1, "\n", 1);
          }
      } else {
          /* No prefix provided, print every file */
          system_call(SYS_WRITE, 1, d_name, strlen(d_name));
          system_call(SYS_WRITE, 1, "\n", 1);
      }

      /* Advance bpos by the length of the current record (d_reclen) 
        * to reach the next directory entry. */
      bpos += d->d_reclen;
  }

  /* ---------------------------------------------------------
    * 5. Cleanup and Exit
    * ---------------------------------------------------------*/
  system_call(SYS_CLOSE, fd, 0, 0);
  return 0;
}