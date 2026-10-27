#!/usr/bin/env python3
import argparse
import time

from safetensors import safe_open

DTYPE_BITS = {
    "BOOL": 8,
    "U8": 8,
    "I8": 8,
    "F8_E4M3": 8,
    "F8_E5M2": 8,
    "F16": 16,
    "BF16": 16,
    "I16": 16,
    "U16": 16,
    "F32": 32,
    "I32": 32,
    "U32": 32,
    "F64": 64,
    "I64": 64,
    "U64": 64,
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", help="Path to .safetensors file")
    parser.add_argument(
        "--touch-pages",
        action="store_true",
        help="Read every 4 KiB page to force actual data access",
    )
    args = parser.parse_args()

    total_bytes = 0
    total_time = 0.0

    with safe_open(args.file, framework="pt", device="cpu") as f:
        for name in f.keys():
            slice_info = f.get_slice(name)
            shape = slice_info.get_shape()
            dtype = slice_info.get_dtype()

            elements = 1
            for dim in shape:
                elements *= dim

            size = (elements * DTYPE_BITS[dtype] + 7) // 8

            start = time.perf_counter()

            tensor = f.get_tensor(name)

            if args.touch_pages:
                # Force CPU to read tensor data.
                # This accesses approximately one byte per 4 KiB page.
                data = tensor.view(torch.uint8).flatten()
                _ = data[::4096].sum().item()

            elapsed = time.perf_counter() - start

            total_bytes += size
            total_time += elapsed

            speed = size / elapsed / (1024**2) if elapsed else 0

            print(
                f"{name}: "
                f"{size / 1024**2:.2f} MiB | "
                f"{elapsed:.4f}s | "
                f"{speed:.2f} MiB/s"
            )

    print(f"\nTotal: {total_bytes / 1024**3:.3f} GiB")
    print(f"Read time: {total_time:.3f}s")
    print(f"Average throughput: " f"{total_bytes / total_time / 1024**2:.2f} MiB/s")


if __name__ == "__main__":
    import torch

    main()
