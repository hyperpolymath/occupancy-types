/* SPDX-License-Identifier: MPL-2.0 */
/* negative-control fixture: non-self cycle ping -> pong -> ping */
void pong(int);
void ping(int x) { pong(x); }
void pong(int x) { ping(x); }
