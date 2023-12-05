module trap;

import core.lib;

import proc;

noreturn unhandled(Proc* p) {
    printf("%d: killed (unhandled)\n", p.pid);
    exit(1);
}
