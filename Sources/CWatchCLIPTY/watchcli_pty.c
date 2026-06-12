#include "watchcli_pty.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>
#include <util.h>          // forkpty(3) on Darwin (libSystem)

int wcli_pty_spawn(const char *path,
                   char *const argv[],
                   char *const envp[],
                   unsigned short cols,
                   unsigned short rows,
                   wcli_pty_t *out) {
    if (path == NULL || argv == NULL || out == NULL) {
        errno = EINVAL;
        return -1;
    }

    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    ws.ws_col = cols ? cols : 80;
    ws.ws_row = rows ? rows : 24;

    int master_fd = -1;
    pid_t pid = forkpty(&master_fd, NULL, NULL, &ws);
    if (pid < 0) {
        return -1;
    }

    if (pid == 0) {
        // Child: reset signal handlers and exec.
        signal(SIGPIPE, SIG_DFL);
        if (envp != NULL) {
            execve(path, argv, envp);
        } else {
            execv(path, argv);
        }
        // exec failed
        _exit(127);
    }

    // Parent: switch master fd to non-blocking so async readers don't stall.
    int flags = fcntl(master_fd, F_GETFL, 0);
    if (flags >= 0) {
        fcntl(master_fd, F_SETFL, flags | O_NONBLOCK);
    }
    out->master_fd = master_fd;
    out->pid = (int)pid;
    return 0;
}

int wcli_pty_resize(int master_fd, unsigned short cols, unsigned short rows) {
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    ws.ws_col = cols ? cols : 80;
    ws.ws_row = rows ? rows : 24;
    return ioctl(master_fd, TIOCSWINSZ, &ws);
}

int wcli_pty_try_wait(int pid, int *out_status) {
    int status = 0;
    pid_t r = waitpid((pid_t)pid, &status, WNOHANG);
    if (r == 0) return 0;
    if (r < 0)  return -1;
    if (out_status) {
        if (WIFEXITED(status))         *out_status = WEXITSTATUS(status);
        else if (WIFSIGNALED(status))  *out_status = 128 + WTERMSIG(status);
        else                           *out_status = -1;
    }
    return 1;
}
