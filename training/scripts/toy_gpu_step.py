"""One GPU matmul. Exit 0 only when CUDA sees a device."""
import sys

import torch


def main() -> int:
    print("torch", torch.__version__)
    print("torch.version.cuda", torch.version.cuda)
    if not torch.cuda.is_available():
        print("CUDA is not available to this PyTorch build.", file=sys.stderr)
        return 2
    name = torch.cuda.get_device_name(0)
    print("device", name)
    x = torch.randn(1024, 1024, device="cuda", dtype=torch.bfloat16)
    y = x @ x
    torch.cuda.synchronize()
    print("matmul", tuple(y.shape), y.dtype)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
