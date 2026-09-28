/* SPDX-License-Identifier: MPL-2.0 */
/* stackcert fixture: generated with
   gcc -O0 -fcallgraph-info=su -fstack-usage -c probe.c
   Frames/callgraph below are real compiler output, committed as fixtures. */
static int helper(int x) { char pad[24]; pad[0]=(char)x; return pad[0]+1; }
int mid(int x) { return helper(x) + helper(x+1); }
int top(int x) { return mid(x); }
int main(void) { return top(0); }
void recur(int d) { if (d) recur(d-1); }
void (*fp)(int);
void indirect(void) { if (fp) fp(1); }
