import os
import shutil
import ctypes
import subprocess

class MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong),
        ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("sullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]

mem = MEMORYSTATUSEX()
mem.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(mem))

du = shutil.disk_usage("C:\\")

print("=== MEMORY DIAGNOSTIC ===")
print(f"Total RAM:     {mem.ullTotalPhys / (1024**3):.2f} GB ({mem.ullTotalPhys} bytes)")
print(f"Available RAM: {mem.ullAvailPhys / (1024**3):.2f} GB ({mem.ullAvailPhys} bytes)")
print(f"Used RAM:      {(mem.ullTotalPhys - mem.ullAvailPhys) / (1024**3):.2f} GB ({mem.dwMemoryLoad}% load)")

print("\n=== DISK C: DIAGNOSTIC ===")
print(f"Total Disk:    {du.total / (1024**3):.2f} GB")
print(f"Used Disk:     {du.used / (1024**3):.2f} GB")
print(f"Free Disk:     {du.free / (1024**3):.2f} GB")

print("\n=== TOP 15 PROCESSES BY MEMORY ===")
out = subprocess.check_output(["tasklist", "/FO", "CSV", "/NH"], text=True)
procs = []
for line in out.strip().splitlines():
    parts = [p.strip(' "') for p in line.split('","')]
    if len(parts) >= 5:
        name = parts[0]
        pid = parts[1]
        mem_str = parts[4].replace(".", "").replace(",", "").replace(" K", "").replace("KB", "").strip()
        try:
            mem_kb = int(mem_str)
            procs.append((name, pid, mem_kb))
        except ValueError:
            pass

procs.sort(key=lambda x: x[2], reverse=True)
for name, pid, mem_kb in procs[:15]:
    print(f"{name:<30} (PID {pid:<6}): {mem_kb / 1024:>8.1f} MB")

