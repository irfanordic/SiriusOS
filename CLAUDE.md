# CLAUDE.md

Guidance for AI assistants working in this repository.

## What this project is

SiriusOS is a **from-scratch hobby operating system built to learn** CS and OS
fundamentals. The owner has some C experience (pointers still shaky) and
is new to assembly. Learning matters more than shipping speed.

See `ROADMAP.md` for the phase-by-phase plan and the current review of `boot.asm`.

## How to help (important)

- **Mentor, don't ghostwrite.** Unless explicitly asked for code, explain the
  concept, point to the relevant OSDev wiki page or Intel SDM section, and let
  the owner write the implementation. Review code they write.
- When you do write code, keep it small, commented with *why*, and explain
  every non-obvious line (especially asm, bit layouts and pointer casts).
- Follow `ROADMAP.md` order. Don't introduce features from later phases
  (e.g. paging before interrupts work) without saying so.
- Prefer the simplest correct approach (PIO before DMA, bitmap before buddy allocator).

## Current state

- `boot.asm`: a single 512-byte boot sector. `[org 0x7c00]`, loads a flat GDT
  (code `0x08`, data `0x10`), enters 32-bit protected mode, sets the stack to
  `0x90000`, writes a string directly to VGA text memory at `0xB8000`, halts.
- `boot.bin`: the assembled output (currently committed; should be gitignored).
- Known issues (see ROADMAP "Where you are now"): `DS` not zeroed before `lgdt`,
  A20 not enabled, no disk loading, `hlt` not looped.
- No Makefile, kernel, C code, or tests yet.

## Build and run

```sh
nasm -f bin boot.asm -o boot.bin
qemu-system-i386 -drive format=raw,file=boot.bin
# debug: add -s -S, then in gdb: target remote :1234; set architecture i8086; break *0x7c00
```

## Toolchain and conventions

- Target: **32-bit x86 (i386)**, BIOS boot, own 2-stage bootloader (Multiboot later, optional).
- Assembler: **NASM**, Intel syntax.
- C kernel (Phase 2+): an **`i686-elf` cross-compiler**, never the host GCC. Flags:
  `-ffreestanding -nostdlib -fno-builtin -Wall -Wextra`. No host libc.
- Planned layout: `boot/` (stage 1 & 2 asm), `kernel/` (C + asm), `build/` (outputs, gitignored).
- Build artifacts (`*.bin`, `*.o`, `*.elf`) shouldn't be committed.
- Commit messages: short, prefixed by subsystem, e.g. `boot: enable A20`, `idt: add ISR stubs`.
