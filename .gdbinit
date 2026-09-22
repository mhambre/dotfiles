# ---------- auto-load ----------
add-auto-load-safe-path ~/.rustup
add-auto-load-safe-path ~/.cargo
set auto-load local-gdbinit off


# ---------- rust pretty printers ----------
# makes plain gdb behave like rust-gdb. guarded so a failure
# cannot abort the rest of this file
python
try:
    import subprocess, os, sys
    sysroot = subprocess.check_output(["rustc", "--print", "sysroot"]).decode().strip()
    etc = os.path.join(sysroot, "lib", "rustlib", "etc")
    if os.path.isdir(etc):
        sys.path.insert(0, etc)
        gdb.execute("add-auto-load-safe-path " + sysroot)
        gdb.execute("source " + os.path.join(etc, "gdb_load_rust_pretty_printers.py"))
except Exception as e:
    print("rust pretty printers not loaded: %s" % e)
end


# ---------- skip std and deps ----------
skip -rfu ^core::
skip -rfu ^alloc::
skip -rfu ^std::
skip -rfu ^<.*as\ core::
skip -rfu ^<.*as\ std::
skip -rfu ^<.*as\ alloc::

skip -gfi /rustc/*
skip -gfi */rustlib/src/rust/library/*/src/*.rs
skip -gfi */rustlib/src/rust/library/*/src/*/*.rs
skip -gfi */rustlib/src/rust/library/*/src/*/*/*.rs


# ---------- output ----------
set print pretty on
set print object on
set print static-members off
set print frame-arguments scalars
set print asm-demangle on
set disassembly-flavor intel


# ---------- behavior ----------
set confirm off
set breakpoint pending on
set backtrace past-main off
set history save on
set history size 10000
set history filename ~/.gdb_history
set debuginfod enabled off
