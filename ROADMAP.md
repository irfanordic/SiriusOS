# SiriusOS Roadmap

A learning roadmap for building SiriusOS from a boot sector into a small but
real operating system. Its job is to teach CS and OS fundamentals, so every
phase lists **what you build**, **what you learn**, and **how you know you're
done**.

**Decisions made (Oct 2026):**

| Topic | Decision |
|---|---|
| Goal | A learning OS: interrupts, memory management, multitasking, user mode, a filesystem, a shell |
| Architecture | 32-bit x86 (i386) first. 64-bit comes later as its own phase |
| Bootloader | Write our own 2-stage loader, then optionally switch to Multiboot/GRUB |
| Language | NASM assembly + freestanding C |
| Background | Some C, pointers still shaky, so pointer practice is built into the early phases |

---

## How to use this roadmap

1. **Do the phases in order.** Each one depends on the one before it.
2. **One milestone = one commit (or a few).** Write commit messages that say
   what you learned, e.g. `idt: load IDT, handle divide-by-zero`.
3. **Keep a `notes/` folder.** After each milestone, write a few lines on what
   surprised you. Explaining something is the fastest way to find out you
   don't understand it yet.
4. **Don't copy and paste tutorial code.** Read it, close the tab, write it
   yourself. If you get stuck, reread it, then close it again.
5. **Learn the debugger early (Phase 0).** In OS development a bug often shows
   up as a reboot loop with no error message. GDB attached to QEMU is how you
   find it.

Time estimates assume a few hours a week. They're rough, and going slower is fine.

---

## Where you are now: review of `boot.asm`

What you built works: a 512-byte boot sector that sets up a GDT, switches
the CPU into 32-bit protected mode and writes straight to VGA memory at
`0xB8000`. That covers segmentation, the GDT, CR0 and memory-mapped I/O, a
lot of concepts for one file. Nice work.

A senior engineer reviewing it would point out these problems. Fixing them
is your first task:

| # | Issue | Why it matters |
|---|---|---|
| 1 | **`DS` is never set before `lgdt [gdt_descriptor]`.** | `lgdt` reads memory through `DS`. The BIOS doesn't promise `DS = 0`. With `[org 0x7c00]`, a non-zero `DS` means the CPU loads a garbage GDT on some machines. Add `xor ax, ax` / `mov ds, ax` / `mov es, ax` / `mov ss, ax` / `mov sp, 0x7c00` at the very top. |
| 2 | **The A20 line isn't enabled.** | Without A20, address bit 20 is forced to 0, so every odd megabyte wraps around. You don't notice it now, but you will once the kernel lives at 1 MiB. Try the "fast A20" method (port `0x92`) first. |
| 3 | **Everything fits in 512 bytes and nothing is loaded from disk.** | There's no room left for a kernel. The next step is to read more sectors with BIOS `int 0x13` *before* leaving real mode. That's Phase 1. |
| 4 | **`hlt` isn't in a loop.** | An NMI or other interrupt can wake the CPU, which then runs whatever bytes come next. Use `.hang: hlt` / `jmp .hang`. |
| 5 | **`boot.bin` is committed to git.** | Build outputs don't belong in version control. Add a `Makefile` and a `.gitignore`. |
| 6 | Small things | Typo in the message ("thsi"). Lots of stray `;` with no comment after them. Add a short comment for *why* each block exists (e.g. "far jump flushes the prefetch queue and loads CS"). |

---

## Phase 0: Tooling and hygiene (about 1 week)

**Goal:** Build and run with one command, and be able to debug.

- [ ] Install QEMU (`qemu-system-i386`) and boot the image: `qemu-system-i386 -drive format=raw,file=boot.bin`
- [ ] Write a `Makefile` with `make`, `make run`, `make debug` and `make clean`
- [ ] Add a `.gitignore` (`*.bin`, `*.o`, `*.elf`, `build/`) and `git rm --cached boot.bin`
- [ ] Fix review items 1, 4, 5 and 6 above
- [ ] Debug with GDB: run `qemu-system-i386 -s -S ...`, then `gdb` → `target remote :1234` → `set architecture i8086` → `break *0x7c00` → `continue` → step with `si`, watch registers with `info registers`
- [ ] Reorganize into folders: `boot/`, `kernel/`, `build/`

**You learn:** how build systems work (targets, dependencies), what an emulator
is, how to debug without `printf`.

**Done when:** `make run` boots your message and you can step through your
code one instruction at a time in GDB.

---

## Phase 1: Real mode and a 2-stage bootloader (2–3 weeks)

**Goal:** The boot sector loads more code from disk and jumps to it.

- [ ] Print text with BIOS `int 0x10` (teletype, `ah=0x0e`). Write a `print_string` routine and a `print_hex` routine. `print_hex` is good practice with bit shifting and masking.
- [ ] Read sectors from disk with `int 0x13` (`ah=0x02` first, then LBA extensions `ah=0x42`). Handle the carry flag on errors.
- [ ] Keep the boot drive number the BIOS hands you in `dl`.
- [ ] Split into **stage 1** (512 bytes: set up segments and stack, load stage 2, jump) and **stage 2** (A20, GDT, protected mode, load the kernel).
- [ ] Get the **memory map** with `int 0x15, eax=0xE820` in stage 2 and store it at a known address. Phase 4 needs it, and BIOS calls stop working after you leave real mode.
- [ ] Enable A20 (review item 2).

**You learn:** segment:offset addressing, the real-mode memory layout (IVT,
BDA, `0x7c00`, EBDA, video memory), BIOS calls as an early form of "system
call", disk geometry (CHS vs. LBA), calling conventions in assembly
(which registers you save, how the stack is used).

**Done when:** stage 1 loads a stage 2 that's several KB long, stage 2 prints
the E820 memory map in hex and then enters protected mode.

---

## Phase 2: A kernel in C (2–3 weeks)

**Goal:** Move from assembly to C. From here on most code is C.

- [ ] Build an **`i686-elf` cross-compiler** (binutils + GCC), see OSDev wiki "GCC Cross-Compiler". Your system GCC targets Linux, and its assumptions will cause subtle bugs.
- [ ] Write `kernel/entry.asm`: set up the stack, `call kmain`, then hang.
- [ ] Write a **linker script** that places the kernel at `0x100000` (1 MiB) with `.text`, `.rodata`, `.data` and `.bss` sections. Zero `.bss` at startup.
- [ ] Compile with `-ffreestanding -nostdlib -fno-builtin -Wall -Wextra -O2`. You have no libc, so you write the parts you need.
- [ ] Stage 2 loads the kernel binary into memory and jumps to it.
- [ ] **VGA text driver** in C: `putchar`, `print`, newlines, scrolling, colours, hardware cursor (ports `0x3D4`/`0x3D5`).
- [ ] **Serial port (COM1) driver** and `qemu ... -serial stdio`. Debug output goes to your terminal, which is very helpful later.
- [ ] Write your own `memset`, `memcpy`, `strlen`, `strcmp` and a small `kprintf` supporting `%s %d %x %c %p`.
- [ ] `panic()` and `assert()` macros.

**Pointer practice (do this alongside):** the VGA buffer is
`volatile uint16_t *vga = (uint16_t *)0xB8000;`. Before you write the driver,
work out on paper what `vga[80 * row + col]`, `*(vga + 1)` and `(uint8_t *)vga + 1`
point to. `memcpy` and `kprintf` are pointer exercises too. If any of it
feels fuzzy, work through K&R chapter 5 in parallel.

**You learn:** compiling vs. linking, ELF sections, what libc actually does,
`volatile` and memory-mapped I/O, port I/O (`inb`/`outb` with inline asm),
the C calling convention (cdecl) and how asm and C call each other.

**Done when:** `kmain()` prints a formatted line like `"Memory map has %d entries"`
to the screen and to serial.

---

## Phase 3: Interrupts (2–3 weeks)

**Goal:** The CPU can tell you when something happens, so you don't have to poll.

- [ ] Build the **IDT** (256 entries) and load it with `lidt`.
- [ ] Write ISR stubs in asm for CPU exceptions 0–31 that save registers, call a common C handler and print the exception name. Test with divide by zero and an invalid opcode (`ud2`).
- [ ] **Remap the 8259 PIC** so hardware IRQs land on vectors 32–47 instead of colliding with exceptions. Send EOI correctly.
- [ ] **PIT timer** (IRQ0): set it to 100 Hz and keep a `ticks` counter. Write `sleep(ms)`.
- [ ] **PS/2 keyboard** (IRQ1): turn scancodes into ASCII, handle Shift, and put keys into a ring buffer.
- [ ] A tiny "echo" loop: type something and it appears on screen.

**You learn:** interrupts vs. polling, exceptions vs. IRQs, interrupt
latency, what "saving context" means (the basis for multitasking later),
producer/consumer ring buffers, why you must not do slow work inside an interrupt handler.

**Done when:** you can type on screen, the timer ticks, and a bad instruction
prints a clean exception report with registers instead of rebooting.

---

## Phase 4: Memory management (3–4 weeks)

**Goal:** Know which RAM is free, hand it out, and give the kernel virtual memory.

- [ ] **Physical memory manager:** read the E820 map from Phase 1 and track free 4 KiB frames with a bitmap. `alloc_frame()` / `free_frame()`. Mark the kernel's own memory as used.
- [ ] **Paging:** build a page directory and page tables, identity-map the first few MiB, then set `CR3` and the `CR0.PG` bit.
- [ ] **Page fault handler** (exception 14): read `CR2` and print the faulting address and why it happened.
- [ ] `map_page(virt, phys, flags)` / `unmap_page(virt)`, and flush the TLB with `invlpg`.
- [ ] *(Stretch)* Higher-half kernel at `0xC0000000`.
- [ ] **Kernel heap:** `kmalloc` / `kfree`. Start with a bump allocator, then a free-list allocator with block splitting and merging.
- [ ] Test it: allocate and free in loops, check for leaks and overlaps.

**You learn:** physical vs. virtual memory, address translation, the TLB,
page faults, memory protection bits, fragmentation, how `malloc` really works
(this is the biggest pointer workout in the project).

**Done when:** writing to an unmapped address triggers your page-fault handler,
and `kmalloc` survives a stress test.

---

## Phase 5: Multitasking (3–4 weeks)

**Goal:** Run more than one thing "at once."

- [ ] Define a task struct (a PCB): ID, saved registers or stack pointer, state, kernel stack.
- [ ] Write a **context switch** in asm: save registers, swap stack pointers, restore registers.
- [ ] Cooperative multitasking first: `yield()` between two kernel threads printing `A` and `B`.
- [ ] Preemptive next: the PIT interrupt calls the scheduler (round-robin with a time slice).
- [ ] Task states: running, ready, blocked, dead. Add `sleep()` that blocks instead of busy-waiting.
- [ ] **Synchronization:** disabling interrupts, spinlocks, then a simple mutex or semaphore. Deliberately cause a race condition on a shared counter, then fix it.

**You learn:** processes vs. threads, context switching, scheduling policies,
race conditions, critical sections, deadlock. This is the core of most OS courses.

**Done when:** three threads print interleaved output under preemption and a
shared counter stays correct because it's protected by a lock.

---

## Phase 6: User mode and system calls (3–4 weeks)

**Goal:** Programs run in ring 3 and can't break the kernel.

- [ ] Add ring 3 code and data segments to the GDT, plus a **TSS** (so the CPU knows which kernel stack to use on interrupts).
- [ ] Jump into user mode with `iret`.
- [ ] **System calls** via `int 0x80`: start with `write`, `exit`, `getpid`, `sleep`, `read`.
- [ ] Give each process its own page directory (its own address space). The kernel is mapped into every address space; user pages have the U/S bit set.
- [ ] Check user pointers passed into syscalls.
- [ ] Kill a user process that faults, without crashing the kernel.

**You learn:** privilege levels and protection rings, the user/kernel boundary,
why syscalls exist, process isolation, why a bad pointer in user code
shouldn't take down the system.

**Done when:** a user program that writes to a kernel address gets killed
while the rest of the OS keeps running.

---

## Phase 7: Storage and a filesystem (3–5 weeks)

**Goal:** Keep files on disk.

- [ ] **ATA PIO driver:** read and write sectors on the QEMU disk.
- [ ] Start read-only: an **initrd** (a tar archive loaded by the bootloader) is the easiest first filesystem.
- [ ] **VFS layer:** `open`, `read`, `write`, `close`, `readdir`, plus a file descriptor table per process.
- [ ] A real on-disk filesystem: **FAT12/16** (a widely used, documented format) *or* your own simple design (superblock, inode table, data blocks). Designing your own teaches more.
- [ ] Optional: a block cache.

**You learn:** block devices, how file metadata is laid out on disk, inodes vs.
FAT, abstraction layers (the VFS is basically an interface), caching.

**Done when:** you can create a file, reboot, and read it back.

---

## Phase 8: Programs and a shell (2–4 weeks)

**Goal:** It starts to feel like an OS.

- [ ] **ELF loader:** parse the headers, map the segments into a new address space, jump to the entry point.
- [ ] `exec`, plus `fork` (copy the address space; later, copy-on-write) or a simpler `spawn`.
- [ ] `wait` / `exit` with exit codes.
- [ ] A tiny **user-space libc**: syscall wrappers, `printf`, `malloc` (on top of an `sbrk` syscall), string functions.
- [ ] A **shell**: read a line, split it into arguments, run the program. Built-ins: `cd`, `ls`, `cat`, `echo`, `help`, `clear`.
- [ ] Write a few user programs: `ls`, `cat`, `hello`, a small game.

**You learn:** executable formats, loaders, process creation, how a shell
works (one of the most common interview topics), how libc and the kernel fit together.

**Done when:** you boot SiriusOS, type `cat hello.txt` at your own shell
prompt, and it works. That's the Learning OS milestone. 🎉

---

## Phase 9: Beyond (pick what interests you)

- **Switch to Multiboot (GRUB) or Limine.** You'll know what a bootloader does by this point, so letting GRUB do it is a convenience, not a shortcut.
- **x86_64 long mode:** 4-level paging, the new syscall instructions, a different calling convention.
- **APIC / IOAPIC and SMP:** multiple CPU cores, real concurrency bugs.
- **Graphics:** VESA/VBE or GOP framebuffer, draw pixels, fonts, a window manager.
- **Networking:** RTL8139 or e1000 driver, Ethernet → ARP → IP → ICMP (`ping`!) → UDP → TCP.
- **Port software:** port newlib or a tiny libc, then run Lua or Doom.
- **Testing:** a kernel unit-test runner, run in CI with QEMU headless.

---

## Reading list (in order of usefulness)

| Resource | Use it for |
|---|---|
| **OSDev Wiki** (wiki.osdev.org) | The go-to reference. Read "Required Knowledge" and "Beginner Mistakes" first |
| **OSTEP**, *Operating Systems: Three Easy Pieces* (free online) | The theory behind each phase. Virtualization → Phases 4–6, Concurrency → Phase 5, Persistence → Phase 7 |
| **xv6 book + source** (MIT 6.1810) | A small, readable real OS. Compare its design with yours after each phase |
| **Nick Blundell, *Writing a Simple Operating System from Scratch*** | Phases 1–2, matches where you are right now |
| **K&R, *The C Programming Language*, chapter 5** | Pointers. Read it alongside Phase 2 |
| **Intel SDM Volume 3** | The official reference for GDT, IDT, paging and the TSS. Look things up, don't read it front to back |
| James Molloy's kernel tutorial | Useful, but has known bugs. Check OSDev's "James Molloy's Known Bugs" page |

## How phases map to OSTEP chapters

| Phase | OSTEP chapters |
|---|---|
| 3 Interrupts | 6 (Limited Direct Execution) |
| 4 Memory | 13–23 (Address Spaces → Paging → TLBs → Swapping) |
| 5 Multitasking | 4–10 (Processes, Scheduling), 26–32 (Concurrency) |
| 6 User mode | 5 (Process API), 6 |
| 7 Filesystem | 36–42 (I/O Devices → File System Implementation) |
| 8 Shell | 5 (Process API: fork/exec/wait) |
