import os
import sys
import ctypes
import shutil
import subprocess

print("================================================================================")
print("1. DIAGNÓSTICO DE MEMÓRIA RAM")
print("================================================================================")
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

stat = MEMORYSTATUSEX()
stat.dwLength = ctypes.sizeof(stat)
ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))

total_gb = stat.ullTotalPhys / (1024**3)
avail_gb = stat.ullAvailPhys / (1024**3)
used_gb = total_gb - avail_gb

print(f"TotalVisibleMemory : {total_gb:.2f} GB")
print(f"FreePhysicalMemory  : {avail_gb:.2f} GB")
print(f"UsedPhysicalMemory  : {used_gb:.2f} GB")
print(f"MemoryLoad          : {stat.dwMemoryLoad}%")

print("\n================================================================================")
print("2. DIAGNÓSTICO DE DISCO C:")
print("================================================================================")
free_bytes = ctypes.c_ulonglong()
total_bytes = ctypes.c_ulonglong()
ctypes.windll.kernel32.GetDiskFreeSpaceExW("C:\\", None, ctypes.byref(total_bytes), ctypes.byref(free_bytes))
disk_total = total_bytes.value / (1024**3)
disk_free = free_bytes.value / (1024**3)
disk_used = disk_total - disk_free
print(f"Disk C Total : {disk_total:.2f} GB")
print(f"Disk C Used  : {disk_used:.2f} GB")
print(f"Disk C Free  : {disk_free:.2f} GB")

print("\n================================================================================")
print("3. TOP 15 PROCESSOS POR CONSUMO DE RAM")
print("================================================================================")
try:
    ps_cmd = 'Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Id, ProcessName, @{Name="WorkingSetMB";Expression={[math]::Round($_.WorkingSet64/1MB,2)}} | Format-Table -AutoSize | Out-String -Width 120'
    res = subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd], capture_output=True, text=True, timeout=10)
    print(res.stdout.strip())
except Exception as e:
    print(f"Erro ao listar processos: {e}")

print("\n================================================================================")
print("4. STATUS DO DOCKER")
print("================================================================================")
docker_bin = shutil.which("docker")
print(f"Docker binary path: {docker_bin}")
if docker_bin:
    try:
        ver = subprocess.run(["docker", "--version"], capture_output=True, text=True, timeout=5)
        print(f"docker --version: {ver.stdout.strip()}")
    except Exception as e:
        print(f"docker --version error: {e}")

    try:
        inf = subprocess.run(["docker", "info"], capture_output=True, text=True, timeout=5)
        print(f"docker info returncode: {inf.returncode}")
        if inf.returncode == 0:
            lines = [l for l in inf.stdout.splitlines()[:6]]
            for l in lines:
                print(f"  {l}")
        else:
            print(f"docker info stderr: {inf.stderr.strip()[:200]}")
    except Exception as e:
        print(f"docker info exception: {e}")
else:
    print("Docker não encontrado no PATH")

print("\n================================================================================")
print("5. VERIFICAÇÃO DE RESÍDUOS: TORCH E OUTRAS DEPENDÊNCIAS")
print("================================================================================")
try:
    import torch
    print(f"torch version: {torch.__version__}")
    print(f"torch file location: {torch.__file__}")
    print(f"torch cuda available: {torch.cuda.is_available()}")
except ImportError:
    print("torch is NOT installed in current venv")
