//! A minimal WASI preview1 host, purpose-built for running CPython.
//!
//! This is a port of `web/python/wasi.js`, function for function and errno for
//! errno. That is the point: one `python.wasm` ships to every platform, so a
//! program must behave identically whether the browser executes it or wasmi
//! does. Where the two disagree, this file is the one that is wrong — the JS
//! shim is the reference, because it is the one a class has already been using.
//!
//! CPython's `wasm32-wasi` build imports exactly 42 functions from
//! `wasi_snapshot_preview1` (verified against the shipped binary). All 42 are
//! defined here, because wasmi refuses to instantiate a module with an
//! unresolved import. The ones CPython only probes with are refused honestly
//! with ENOTSUP or EROFS rather than pretended.
//!
//! The filesystem is a read-only map held in memory containing exactly what the
//! caller puts there — the standard library zip and the program being run. There
//! is no host filesystem behind it, no network, and no way to add one: a wasm
//! module can only reach what its imports allow, so the sandbox is a property of
//! this file being small rather than of any permission check.
//!
//! Not a general WASI implementation. Do not reuse it as one.

use std::collections::BTreeMap;
use std::fmt;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use wasmi::{Caller, Error, Extern, Linker, Memory};

// Errno values, matching wasi.js exactly.
const ERRNO_SUCCESS: i32 = 0;
const ERRNO_BADF: i32 = 8;
const ERRNO_INVAL: i32 = 28;
const ERRNO_NOENT: i32 = 44;
const ERRNO_NOTSUP: i32 = 58;
const ERRNO_ROFS: i32 = 69;

const FILETYPE_CHARACTER_DEVICE: u8 = 2;
const FILETYPE_DIRECTORY: u8 = 3;
const FILETYPE_REGULAR_FILE: u8 = 4;

const PREOPENTYPE_DIR: u8 = 0;

/// The single preopened directory, `/`. Everything CPython opens resolves
/// against it.
const PREOPEN_FD: i32 = 3;

/// `O_CREAT` — the one open flag worth refusing outright.
const OFLAGS_CREAT: i32 = 1;

const NS: &str = "wasi_snapshot_preview1";

/// Raised by `proc_exit` to unwind out of `_start`, which never returns
/// normally. The caller recognises it and turns it back into an exit code: a
/// trap carrying this is the *successful* path, not a crash.
#[derive(Debug)]
pub struct ProcExit(pub i32);

impl fmt::Display for ProcExit {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "exit {}", self.0)
    }
}

impl wasmi::errors::HostError for ProcExit {}

#[derive(Clone, Copy)]
enum FdKind {
    Stream,
    Directory,
    File,
}

impl FdKind {
    fn filetype(self) -> u8 {
        match self {
            FdKind::Stream => FILETYPE_CHARACTER_DEVICE,
            FdKind::Directory => FILETYPE_DIRECTORY,
            FdKind::File => FILETYPE_REGULAR_FILE,
        }
    }
}

struct Fd {
    kind: FdKind,
    /// `None` for streams and directories, which have nothing to read.
    data: Option<Arc<Vec<u8>>>,
    offset: usize,
}

impl Fd {
    fn stream() -> Self {
        Fd {
            kind: FdKind::Stream,
            data: None,
            offset: 0,
        }
    }

    fn directory() -> Self {
        Fd {
            kind: FdKind::Directory,
            data: None,
            offset: 0,
        }
    }

    fn file(data: Arc<Vec<u8>>) -> Self {
        Fd {
            kind: FdKind::File,
            data: Some(data),
            offset: 0,
        }
    }

    fn size(&self) -> usize {
        self.data.as_ref().map_or(0, |data| data.len())
    }
}

/// Captured output, with the same per-stream cap the web worker applies.
///
/// Output is mirrored to other screens and saved with the board, so a runaway
/// `while True: print(x)` must not be allowed to grow the board file without
/// bound. Dropping the tail silently would make the program look like it stopped
/// early, so the cap is recorded rather than hidden.
#[derive(Default)]
pub struct Output {
    pub bytes: Vec<u8>,
    pub truncated: bool,
}

impl Output {
    fn write(&mut self, chunk: &[u8], cap: usize) {
        if chunk.is_empty() {
            return;
        }
        let room = cap.saturating_sub(self.bytes.len());
        if chunk.len() > room {
            self.bytes.extend_from_slice(&chunk[..room]);
            self.truncated = true;
        } else {
            self.bytes.extend_from_slice(chunk);
        }
    }
}

/// Everything the host needs while a program runs. Lives in the wasmi `Store`,
/// so host functions reach it through `Caller::data_mut`.
pub struct WasiCtx {
    /// argv, each NUL-terminated, e.g. `["python", "/main.py"]`.
    args: Vec<Vec<u8>>,
    /// `KEY=VALUE`, each NUL-terminated.
    env: Vec<Vec<u8>>,
    /// Absolute path -> contents, read-only for the guest's whole lifetime.
    files: BTreeMap<String, Arc<Vec<u8>>>,
    stdin: Vec<u8>,
    stdin_offset: usize,
    fds: BTreeMap<i32, Fd>,
    next_fd: i32,
    max_output: usize,
    pub stdout: Output,
    pub stderr: Output,
    /// Caps how far the guest may grow its linear memory. Held here because
    /// `Store::limiter` hands the limiter out of the store's data.
    pub limits: wasmi::StoreLimits,
}

impl WasiCtx {
    pub fn new(
        args: &[&str],
        env: &[(&str, &str)],
        files: BTreeMap<String, Arc<Vec<u8>>>,
        stdin: Vec<u8>,
        max_output: usize,
        max_memory: usize,
    ) -> Self {
        // 0/1/2 are the standard streams; 3 is the single preopened directory
        // that everything else is resolved against.
        let mut fds = BTreeMap::new();
        fds.insert(0, Fd::stream());
        fds.insert(1, Fd::stream());
        fds.insert(2, Fd::stream());
        fds.insert(PREOPEN_FD, Fd::directory());

        WasiCtx {
            args: args.iter().map(|arg| nul_terminated(arg)).collect(),
            env: env
                .iter()
                .map(|(k, v)| nul_terminated(&format!("{k}={v}")))
                .collect(),
            files,
            stdin,
            stdin_offset: 0,
            fds,
            next_fd: PREOPEN_FD + 1,
            max_output,
            stdout: Output::default(),
            stderr: Output::default(),
            // Not `trap_on_grow_failure`: a refused grow returns -1 to the
            // guest, which CPython's allocator turns into a normal
            // `MemoryError` the pupil can catch — a trap would just kill the
            // run with a host message instead.
            limits: wasmi::StoreLimitsBuilder::new()
                .memory_size(max_memory)
                .build(),
        }
    }

    /// Collapses `.` and `..` so a path can never climb out of the virtual root.
    fn normalise(path: &str) -> String {
        let mut parts: Vec<&str> = Vec::new();
        for part in path.split('/') {
            match part {
                "" | "." => {}
                ".." => {
                    parts.pop();
                }
                other => parts.push(other),
            }
        }
        format!("/{}", parts.join("/"))
    }

    /// A path is a directory if anything in the file map lives under it. There
    /// are no directory entries to consult — the map holds files only.
    fn is_directory(&self, path: &str) -> bool {
        if path == "/" {
            return true;
        }
        let prefix = format!("{path}/");
        self.files.keys().any(|key| key.starts_with(&prefix))
    }

    fn open(&mut self, fd: Fd) -> i32 {
        let handle = self.next_fd;
        self.next_fd += 1;
        self.fds.insert(handle, fd);
        handle
    }

    /// Whether a read on `fd` can still produce anything. Only stdin runs dry;
    /// a file at EOF reads zero bytes, which is not the same as having no input.
    fn has_input(&self, fd: i32) -> bool {
        fd != 0 || self.stdin_offset < self.stdin.len()
    }

    /// Copies up to `len` bytes out of `fd` into guest memory at `ptr`.
    fn read_into(&mut self, mem: &mut [u8], fd: i32, ptr: i32, len: i32) -> Result<usize, i32> {
        let len = usize::try_from(len).map_err(|_| ERRNO_INVAL)?;
        if fd == 0 {
            let end = (self.stdin_offset + len).min(self.stdin.len());
            let slice = self.stdin[self.stdin_offset..end].to_vec();
            write_bytes(mem, ptr, &slice)?;
            self.stdin_offset = end;
            return Ok(slice.len());
        }
        let Some(entry) = self.fds.get_mut(&fd) else {
            return Ok(0);
        };
        let Some(data) = entry.data.as_ref() else {
            return Ok(0);
        };
        let end = (entry.offset + len).min(data.len());
        let slice = data[entry.offset.min(data.len())..end].to_vec();
        write_bytes(mem, ptr, &slice)?;
        entry.offset += slice.len();
        Ok(slice.len())
    }

    fn write_output(&mut self, fd: i32, chunk: &[u8]) {
        let cap = self.max_output;
        if fd == 1 {
            self.stdout.write(chunk, cap);
        } else {
            self.stderr.write(chunk, cap);
        }
    }
}

fn nul_terminated(value: &str) -> Vec<u8> {
    let mut bytes = value.as_bytes().to_vec();
    bytes.push(0);
    bytes
}

// ------------------------------------------------------------- memory accessors
//
// Every accessor is bounds-checked and yields EINVAL rather than panicking. A
// guest is free to pass nonsense, and a panic would unwind through wasmi's
// trampoline and out through the FFI boundary, which is undefined behaviour.

fn write_u8(mem: &mut [u8], ptr: i32, value: u8) -> Result<(), i32> {
    let at = offset(ptr)?;
    *mem.get_mut(at).ok_or(ERRNO_INVAL)? = value;
    Ok(())
}

fn write_u16(mem: &mut [u8], ptr: i32, value: u16) -> Result<(), i32> {
    let at = offset(ptr)?;
    mem.get_mut(at..at + 2)
        .ok_or(ERRNO_INVAL)?
        .copy_from_slice(&value.to_le_bytes());
    Ok(())
}

fn write_u32(mem: &mut [u8], ptr: i32, value: u32) -> Result<(), i32> {
    let at = offset(ptr)?;
    mem.get_mut(at..at + 4)
        .ok_or(ERRNO_INVAL)?
        .copy_from_slice(&value.to_le_bytes());
    Ok(())
}

fn write_u64(mem: &mut [u8], ptr: i32, value: u64) -> Result<(), i32> {
    let at = offset(ptr)?;
    mem.get_mut(at..at + 8)
        .ok_or(ERRNO_INVAL)?
        .copy_from_slice(&value.to_le_bytes());
    Ok(())
}

fn read_u8(mem: &[u8], ptr: i32) -> Result<u8, i32> {
    Ok(*mem.get(offset(ptr)?).ok_or(ERRNO_INVAL)?)
}

fn read_u16(mem: &[u8], ptr: i32) -> Result<u16, i32> {
    let at = offset(ptr)?;
    let slot = mem.get(at..at + 2).ok_or(ERRNO_INVAL)?;
    Ok(u16::from_le_bytes(slot.try_into().expect("a 2-byte slice")))
}

fn read_u32(mem: &[u8], ptr: i32) -> Result<u32, i32> {
    let at = offset(ptr)?;
    let slot = mem.get(at..at + 4).ok_or(ERRNO_INVAL)?;
    Ok(u32::from_le_bytes(slot.try_into().expect("a 4-byte slice")))
}

fn read_u64(mem: &[u8], ptr: i32) -> Result<u64, i32> {
    let at = offset(ptr)?;
    let slot = mem.get(at..at + 8).ok_or(ERRNO_INVAL)?;
    Ok(u64::from_le_bytes(
        slot.try_into().expect("an 8-byte slice"),
    ))
}

fn write_bytes(mem: &mut [u8], ptr: i32, bytes: &[u8]) -> Result<(), i32> {
    let at = offset(ptr)?;
    mem.get_mut(at..at + bytes.len())
        .ok_or(ERRNO_INVAL)?
        .copy_from_slice(bytes);
    Ok(())
}

fn read_string(mem: &[u8], ptr: i32, len: i32) -> Result<String, i32> {
    let at = offset(ptr)?;
    let len = offset(len)?;
    let slot = mem.get(at..at + len).ok_or(ERRNO_INVAL)?;
    Ok(String::from_utf8_lossy(slot).into_owned())
}

fn offset(value: i32) -> Result<usize, i32> {
    usize::try_from(value).map_err(|_| ERRNO_INVAL)
}

/// One `(ptr, len)` pair out of an iovec array. Each entry is two little-endian
/// u32s: the buffer pointer, then its length.
fn iovec(mem: &[u8], iovs: i32, index: i32) -> Result<(i32, i32), i32> {
    let base = iovs + index * 8;
    Ok((read_u32(mem, base)? as i32, read_u32(mem, base + 4)? as i32))
}

/// Writes a NUL-terminated string table: pointers at `index_ptr`, contents
/// packed from `buf_ptr`. Serves both `args_get` and `environ_get`.
fn write_string_table(
    mem: &mut [u8],
    entries: &[Vec<u8>],
    index_ptr: i32,
    buf_ptr: i32,
) -> Result<(), i32> {
    let mut at = buf_ptr;
    for (i, entry) in entries.iter().enumerate() {
        write_u32(mem, index_ptr + (i as i32) * 4, at as u32)?;
        write_bytes(mem, at, entry)?;
        at += entry.len() as i32;
    }
    Ok(())
}

/// The `filestat` struct, exactly as wasi.js lays it out.
fn write_filestat(mem: &mut [u8], ptr: i32, filetype: u8, size: usize) -> Result<i32, i32> {
    write_u64(mem, ptr, 0)?; // dev
    write_u64(mem, ptr + 8, 0)?; // ino
    write_u8(mem, ptr + 16, filetype)?;
    write_u64(mem, ptr + 24, 1)?; // nlink
    write_u64(mem, ptr + 32, size as u64)?;
    write_u64(mem, ptr + 40, 0)?; // atim
    write_u64(mem, ptr + 48, 0)?; // mtim
    write_u64(mem, ptr + 56, 0)?; // ctim
    Ok(ERRNO_SUCCESS)
}

/// Milliseconds since the epoch, as nanoseconds — the same precision the JS shim
/// reports, since it only has `Date.now()`.
fn now_nanos() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |since| {
            (since.as_millis() as u64).saturating_mul(1_000_000)
        })
}

/// The guest's `memory` export. CPython exports it under that name; a module
/// that does not is not something this host can run.
fn memory_of(caller: &Caller<'_, WasiCtx>) -> Result<Memory, i32> {
    match caller.get_export("memory") {
        Some(Extern::Memory(memory)) => Ok(memory),
        _ => Err(ERRNO_INVAL),
    }
}

/// Runs `body` with the guest's linear memory and the host state borrowed
/// together, collapsing both `Ok` and `Err` to the errno the guest sees.
fn with_memory(
    caller: &mut Caller<'_, WasiCtx>,
    body: impl FnOnce(&mut [u8], &mut WasiCtx) -> Result<i32, i32>,
) -> i32 {
    let memory = match memory_of(caller) {
        Ok(memory) => memory,
        Err(errno) => return errno,
    };
    let (mem, ctx) = memory.data_and_store_mut(caller);
    match body(mem, ctx) {
        Ok(errno) => errno,
        Err(errno) => errno,
    }
}

/// Like [`with_memory`], but yields a value instead of an errno — for the rare
/// host function that has to do something between two looks at guest memory.
fn from_memory<R>(
    caller: &mut Caller<'_, WasiCtx>,
    body: impl FnOnce(&[u8]) -> Result<R, i32>,
) -> Result<R, i32> {
    let memory = memory_of(caller)?;
    body(memory.data(&*caller))
}

pub fn add_to_linker(linker: &mut Linker<WasiCtx>) -> Result<(), Error> {
    process(linker)?;
    clocks(linker)?;
    streams(linker)?;
    files(linker)?;
    poll(linker)?;
    refused(linker)?;
    Ok(())
}

// ---------------------------------------------------------------------- process

fn process(linker: &mut Linker<WasiCtx>) -> Result<(), Error> {
    linker.func_wrap(
        NS,
        "proc_exit",
        |_: Caller<'_, WasiCtx>, code: i32| -> Result<(), Error> {
            Err(Error::host(ProcExit(code)))
        },
    )?;

    linker.func_wrap(NS, "sched_yield", |_: Caller<'_, WasiCtx>| ERRNO_SUCCESS)?;

    linker.func_wrap(
        NS,
        "args_sizes_get",
        |mut caller: Caller<'_, WasiCtx>, count: i32, size: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let total: usize = ctx.args.iter().map(Vec::len).sum();
                write_u32(mem, count, ctx.args.len() as u32)?;
                write_u32(mem, size, total as u32)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "args_get",
        |mut caller: Caller<'_, WasiCtx>, argv: i32, buf: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let args = std::mem::take(&mut ctx.args);
                let result = write_string_table(mem, &args, argv, buf);
                ctx.args = args;
                result?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "environ_sizes_get",
        |mut caller: Caller<'_, WasiCtx>, count: i32, size: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let total: usize = ctx.env.iter().map(Vec::len).sum();
                write_u32(mem, count, ctx.env.len() as u32)?;
                write_u32(mem, size, total as u32)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "environ_get",
        |mut caller: Caller<'_, WasiCtx>, environ: i32, buf: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let env = std::mem::take(&mut ctx.env);
                let result = write_string_table(mem, &env, environ, buf);
                ctx.env = env;
                result?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    Ok(())
}

// ----------------------------------------------------------------------- clocks

fn clocks(linker: &mut Linker<WasiCtx>) -> Result<(), Error> {
    linker.func_wrap(
        NS,
        "clock_res_get",
        |mut caller: Caller<'_, WasiCtx>, _id: i32, res: i32| {
            with_memory(&mut caller, |mem, _| {
                write_u64(mem, res, 1_000_000)?; // 1ms
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "clock_time_get",
        |mut caller: Caller<'_, WasiCtx>, _id: i32, _precision: i64, time: i32| {
            with_memory(&mut caller, |mem, _| {
                write_u64(mem, time, now_nanos())?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "random_get",
        |mut caller: Caller<'_, WasiCtx>, ptr: i32, len: i32| {
            with_memory(&mut caller, |mem, _| {
                let at = offset(ptr)?;
                let len = offset(len)?;
                let slot = mem.get_mut(at..at + len).ok_or(ERRNO_INVAL)?;
                // CPython seeds its hash randomisation and the `random` module from
                // this, so it wants real entropy rather than a counter.
                getrandom::fill(slot).map_err(|_| ERRNO_INVAL)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    Ok(())
}

// -------------------------------------------------------------------- I/O

fn streams(linker: &mut Linker<WasiCtx>) -> Result<(), Error> {
    linker.func_wrap(
        NS,
        "fd_write",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, iovs: i32, iovs_len: i32, written: i32| {
            with_memory(&mut caller, |mem, ctx| {
                if fd != 1 && fd != 2 {
                    return Ok(ERRNO_BADF);
                }
                let mut total = 0usize;
                let mut merged = Vec::new();
                for i in 0..iovs_len {
                    let (ptr, len) = iovec(mem, iovs, i)?;
                    let at = offset(ptr)?;
                    let len = offset(len)?;
                    merged.extend_from_slice(mem.get(at..at + len).ok_or(ERRNO_INVAL)?);
                    total += len;
                }
                ctx.write_output(fd, &merged);
                write_u32(mem, written, total as u32)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_read",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, iovs: i32, iovs_len: i32, read: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let mut total = 0usize;
                for i in 0..iovs_len {
                    if !ctx.has_input(fd) {
                        break;
                    }
                    let (ptr, len) = iovec(mem, iovs, i)?;
                    total += ctx.read_into(mem, fd, ptr, len)?;
                }
                write_u32(mem, read, total as u32)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_pread",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, iovs: i32, iovs_len: i32, at: i64, read: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let Some(data) = ctx.fds.get(&fd).and_then(|entry| entry.data.clone()) else {
                    return Ok(ERRNO_BADF);
                };
                let mut cursor = usize::try_from(at).map_err(|_| ERRNO_INVAL)?;
                let mut total = 0usize;
                for i in 0..iovs_len {
                    let (ptr, len) = iovec(mem, iovs, i)?;
                    let len = offset(len)?;
                    let start = cursor.min(data.len());
                    let end = (start + len).min(data.len());
                    write_bytes(mem, ptr, &data[start..end])?;
                    let taken = end - start;
                    total += taken;
                    cursor += taken;
                }
                write_u32(mem, read, total as u32)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_seek",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, delta: i64, whence: i32, out: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let Some(entry) = ctx.fds.get_mut(&fd) else {
                    return Ok(ERRNO_BADF);
                };
                if entry.data.is_none() {
                    return Ok(ERRNO_INVAL);
                }
                let size = entry.size() as i64;
                let base = match whence {
                    0 => 0,
                    1 => entry.offset as i64,
                    2 => size,
                    _ => return Ok(ERRNO_INVAL),
                };
                entry.offset = base.saturating_add(delta).clamp(0, size) as usize;
                let offset = entry.offset as u64;
                write_u64(mem, out, offset)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_tell",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, out: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let Some(entry) = ctx.fds.get(&fd) else {
                    return Ok(ERRNO_BADF);
                };
                let offset = entry.offset as u64;
                write_u64(mem, out, offset)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_close",
        |mut caller: Caller<'_, WasiCtx>, fd: i32| {
            // The standard streams and the preopen stay open for the whole run;
            // closing them is a no-op rather than an error, as in the JS shim.
            if fd > PREOPEN_FD {
                caller.data_mut().fds.remove(&fd);
            }
            ERRNO_SUCCESS
        },
    )?;

    Ok(())
}

// ------------------------------------------------------------------ file system

fn files(linker: &mut Linker<WasiCtx>) -> Result<(), Error> {
    linker.func_wrap(
        NS,
        "fd_fdstat_get",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, out: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let Some(entry) = ctx.fds.get(&fd) else {
                    return Ok(ERRNO_BADF);
                };
                write_u8(mem, out, entry.kind.filetype())?;
                write_u16(mem, out + 2, 0)?; // fs_flags
                                             // Grant every right. The filesystem is read-only by construction, so
                                             // there is nothing a generous rights mask can actually reach.
                write_u64(mem, out + 8, u64::MAX)?;
                write_u64(mem, out + 16, u64::MAX)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_fdstat_set_flags",
        |_: Caller<'_, WasiCtx>, _fd: i32, _flags: i32| ERRNO_SUCCESS,
    )?;

    linker.func_wrap(
        NS,
        "fd_filestat_get",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, out: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let Some(entry) = ctx.fds.get(&fd) else {
                    return Ok(ERRNO_BADF);
                };
                let (filetype, size) = (entry.kind.filetype(), entry.size());
                write_filestat(mem, out, filetype, size)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_prestat_get",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, out: i32| {
            with_memory(&mut caller, |mem, _| {
                if fd != PREOPEN_FD {
                    return Ok(ERRNO_BADF);
                }
                write_u8(mem, out, PREOPENTYPE_DIR)?;
                write_u32(mem, out + 4, 1)?; // strlen("/")
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_prestat_dir_name",
        |mut caller: Caller<'_, WasiCtx>, fd: i32, ptr: i32, len: i32| {
            with_memory(&mut caller, |mem, _| {
                if fd != PREOPEN_FD {
                    return Ok(ERRNO_BADF);
                }
                let name = b"/";
                let take = name.len().min(offset(len)?);
                write_bytes(mem, ptr, &name[..take])?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "fd_readdir",
        |mut caller: Caller<'_, WasiCtx>,
         _fd: i32,
         _buf: i32,
         _buf_len: i32,
         _cookie: i64,
         size: i32| {
            with_memory(&mut caller, |mem, _| {
                // CPython probes directories while working out sys.path. An empty
                // listing is honest and enough, because imports resolve through
                // the stdlib zip rather than by scanning.
                write_u32(mem, size, 0)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    #[allow(clippy::too_many_arguments)]
    linker.func_wrap(
        NS,
        "path_open",
        |mut caller: Caller<'_, WasiCtx>,
         _dir_fd: i32,
         _dir_flags: i32,
         path_ptr: i32,
         path_len: i32,
         oflags: i32,
         _base: i64,
         _inheriting: i64,
         _fd_flags: i32,
         out: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let path = WasiCtx::normalise(&read_string(mem, path_ptr, path_len)?);
                if oflags & OFLAGS_CREAT != 0 {
                    return Ok(ERRNO_ROFS);
                }
                let fd = match ctx.files.get(&path).cloned() {
                    Some(data) => ctx.open(Fd::file(data)),
                    None if ctx.is_directory(&path) => ctx.open(Fd::directory()),
                    None => return Ok(ERRNO_NOENT),
                };
                write_u32(mem, out, fd as u32)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    linker.func_wrap(
        NS,
        "path_filestat_get",
        |mut caller: Caller<'_, WasiCtx>,
         _dir_fd: i32,
         _flags: i32,
         path_ptr: i32,
         path_len: i32,
         out: i32| {
            with_memory(&mut caller, |mem, ctx| {
                let path = WasiCtx::normalise(&read_string(mem, path_ptr, path_len)?);
                if let Some(data) = ctx.files.get(&path) {
                    let size = data.len();
                    return write_filestat(mem, out, FILETYPE_REGULAR_FILE, size);
                }
                if ctx.is_directory(&path) {
                    return write_filestat(mem, out, FILETYPE_DIRECTORY, 0);
                }
                Ok(ERRNO_NOENT)
            })
        },
    )?;

    Ok(())
}

// ------------------------------------------------------------------------ poll
//
// `time.sleep()` is the whole reason this exists. wasi-libc implements
// `nanosleep` on top of `poll_oneoff` with a single clock subscription, so a
// host that refuses it turns every sleeping program into
// `OSError: [Errno 58] Not supported` — which is exactly what happened until
// this was written.

/// `subscription`, `event`: both fixed-size records in the preview1 ABI.
const SUBSCRIPTION_SIZE: i32 = 48;
const EVENT_SIZE: i32 = 32;

const EVENTTYPE_CLOCK: u8 = 0;

/// `SUBSCRIPTION_CLOCK_ABSTIME` — the timeout is a point in time rather than a
/// duration.
const SUBCLOCKFLAGS_ABSTIME: u16 = 1;

fn poll(linker: &mut Linker<WasiCtx>) -> Result<(), Error> {
    linker.func_wrap(
        NS,
        "poll_oneoff",
        |mut caller: Caller<'_, WasiCtx>, subs: i32, out: i32, count: i32, nevents: i32| {
            // Two passes, because the wait happens between them: the first reads
            // the subscriptions out of guest memory, the second writes the events
            // back. Nothing may hold a borrow of memory across the sleep.
            let plan = match from_memory(&mut caller, |mem| plan_poll(mem, subs, count)) {
                Ok(plan) => plan,
                Err(errno) => return errno,
            };

            if let Some(deadline) = plan.sleep_until {
                let now = now_nanos();
                if deadline > now {
                    std::thread::sleep(std::time::Duration::from_nanos(deadline - now));
                }
            }

            with_memory(&mut caller, |mem, _| {
                for (i, event) in plan.events.iter().enumerate() {
                    let at = out + (i as i32) * EVENT_SIZE;
                    write_u64(mem, at, event.userdata)?;
                    write_u16(mem, at + 8, ERRNO_SUCCESS as u16)?;
                    write_u8(mem, at + 10, event.kind)?;
                    write_u64(mem, at + 16, 0)?; // nbytes
                    write_u16(mem, at + 24, 0)?; // flags
                }
                write_u32(mem, nevents, plan.events.len() as u32)?;
                Ok(ERRNO_SUCCESS)
            })
        },
    )?;

    Ok(())
}

struct PollEvent {
    userdata: u64,
    kind: u8,
}

struct PollPlan {
    /// Absolute nanoseconds to wait until, or `None` when something is already
    /// ready and there is nothing to wait for.
    sleep_until: Option<u64>,
    events: Vec<PollEvent>,
}

/// Reads the subscription array and works out what to report.
///
/// A poll returns as soon as *any* subscription is ready. Our streams never
/// block — stdin is a fixed buffer and stdout cannot fill — so an fd
/// subscription is ready immediately and cancels the wait entirely. Only when
/// every subscription is a clock does anything actually sleep, and then until
/// the earliest deadline.
fn plan_poll(mem: &[u8], subs: i32, count: i32) -> Result<PollPlan, i32> {
    if count <= 0 {
        return Err(ERRNO_INVAL);
    }

    let mut events = Vec::new();
    let mut earliest: Option<u64> = None;
    let mut ready_now = false;

    for i in 0..count {
        let base = subs + i * SUBSCRIPTION_SIZE;
        let userdata = read_u64(mem, base)?;
        let kind = read_u8(mem, base + 8)?;

        if kind == EVENTTYPE_CLOCK {
            let timeout = read_u64(mem, base + 24)?;
            let flags = read_u16(mem, base + 40)?;
            let deadline = if flags & SUBCLOCKFLAGS_ABSTIME != 0 {
                timeout
            } else {
                now_nanos().saturating_add(timeout)
            };
            earliest = Some(earliest.map_or(deadline, |current: u64| current.min(deadline)));
        } else {
            ready_now = true;
        }

        events.push(PollEvent { userdata, kind });
    }

    // Report only what is actually ready. When an fd is ready the clocks have
    // not fired, and saying they had would make a `select` with a timeout claim
    // it timed out every single time.
    if ready_now {
        events.retain(|event| event.kind != EVENTTYPE_CLOCK);
        return Ok(PollPlan {
            sleep_until: None,
            events,
        });
    }
    events.retain(|event| event.kind == EVENTTYPE_CLOCK);
    Ok(PollPlan {
        sleep_until: earliest,
        events,
    })
}

// --------------------------------------------------- refused, rather than faked
//
// A read-only virtual filesystem with no network. CPython probes for these while
// starting up and copes fine with being told no.

fn refused(linker: &mut Linker<WasiCtx>) -> Result<(), Error> {
    linker.func_wrap(
        NS,
        "fd_advise",
        |_: Caller<'_, WasiCtx>, _: i32, _: i64, _: i64, _: i32| ERRNO_SUCCESS,
    )?;
    linker.func_wrap(NS, "fd_datasync", |_: Caller<'_, WasiCtx>, _: i32| {
        ERRNO_SUCCESS
    })?;
    linker.func_wrap(NS, "fd_sync", |_: Caller<'_, WasiCtx>, _: i32| {
        ERRNO_SUCCESS
    })?;

    linker.func_wrap(
        NS,
        "fd_filestat_set_size",
        |_: Caller<'_, WasiCtx>, _: i32, _: i64| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "fd_filestat_set_times",
        |_: Caller<'_, WasiCtx>, _: i32, _: i64, _: i64, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "fd_pwrite",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i64, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "path_create_directory",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "path_filestat_set_times",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i32, _: i64, _: i64, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "path_link",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "path_readlink",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32| ERRNO_INVAL,
    )?;
    linker.func_wrap(
        NS,
        "path_remove_directory",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "path_rename",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "path_symlink",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i32, _: i32| ERRNO_ROFS,
    )?;
    linker.func_wrap(
        NS,
        "path_unlink_file",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32| ERRNO_ROFS,
    )?;

    linker.func_wrap(
        NS,
        "sock_accept",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32| ERRNO_NOTSUP,
    )?;
    linker.func_wrap(
        NS,
        "sock_recv",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32| ERRNO_NOTSUP,
    )?;
    linker.func_wrap(
        NS,
        "sock_send",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32, _: i32, _: i32, _: i32| ERRNO_NOTSUP,
    )?;
    linker.func_wrap(
        NS,
        "sock_shutdown",
        |_: Caller<'_, WasiCtx>, _: i32, _: i32| ERRNO_NOTSUP,
    )?;

    Ok(())
}
