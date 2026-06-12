#ifndef WATCHCLI_PTY_H
#define WATCHCLI_PTY_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int master_fd;
    int pid;
} wcli_pty_t;

/**
 * Spawn `path` with `argv` and `envp` attached to a freshly-allocated PTY.
 *
 * - argv MUST be NULL-terminated; argv[0] is conventionally the program name.
 * - envp MUST be NULL-terminated. Pass NULL to inherit the parent's env.
 * - On success returns 0 and fills `*out` with the master fd and child pid.
 * - On failure returns -1 and sets errno.
 */
int wcli_pty_spawn(const char *path,
                   char *const argv[],
                   char *const envp[],
                   unsigned short cols,
                   unsigned short rows,
                   wcli_pty_t *out);

/** TIOCSWINSZ on master_fd. Returns 0 on success, -1 on failure. */
int wcli_pty_resize(int master_fd, unsigned short cols, unsigned short rows);

/** Non-blocking waitpid. Returns 1 if exited (out_status filled), 0 if still
 *  running, -1 on error. */
int wcli_pty_try_wait(int pid, int *out_status);

#ifdef __cplusplus
}
#endif

#endif
