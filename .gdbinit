add-auto-load-safe-path ~/.rustup
add-auto-load-safe-path ~/.cargo
set auto-load local-gdbinit off

skip -gfi /rustc/*
skip -gfi */.cargo/registry/src/*
skip -rfu ^core::
skip -rfu ^allo::
skip -rfu ^std::
