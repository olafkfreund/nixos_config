#!/usr/bin/env python3
"""
Temperature Dashboard for NixOS
Shows CPU, GPU, and NVMe temperatures in a GUI window
Designed for waybar integration
"""

import tkinter as tk
from tkinter import ttk
import subprocess
import json
import time
import threading
from pathlib import Path
import re

class TemperatureDashboard:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("System Temperature Dashboard")
        self.root.geometry("400x300")
        self.root.resizable(False, False)
        
        # Set dark theme colors
        self.bg_color = "#282828"
        self.fg_color = "#ebdbb2"
        self.accent_color = "#fabd2f"
        self.warning_color = "#fb4934"
        self.good_color = "#8ec07c"
        
        self.root.configure(bg=self.bg_color)
        
        # Configure style for dark theme
        self.style = ttk.Style()
        self.style.theme_use('clam')
        self.style.configure('Dark.TLabel', 
                           background=self.bg_color, 
                           foreground=self.fg_color,
                           font=('JetBrainsMono Nerd Font', 12))
        self.style.configure('Title.TLabel',
                           background=self.bg_color,
                           foreground=self.accent_color,
                           font=('JetBrainsMono Nerd Font', 14, 'bold'))
        self.style.configure('Temp.TLabel',
                           background=self.bg_color,
                           foreground=self.fg_color,
                           font=('JetBrainsMono Nerd Font', 16, 'bold'))
        
        self.setup_ui()
        self.update_temperatures()
        
        # Auto-update every 2 seconds
        self.update_thread()
        
    def setup_ui(self):
        # Title
        title_frame = tk.Frame(self.root, bg=self.bg_color)
        title_frame.pack(pady=10)
        
        title_label = ttk.Label(title_frame, text="🌡️ System Temperatures", style='Title.TLabel')
        title_label.pack()
        
        # Temperature sections
        self.temp_frame = tk.Frame(self.root, bg=self.bg_color)
        self.temp_frame.pack(pady=20, padx=20, fill='both', expand=True)
        
        # CPU Temperature
        self.cpu_frame = self.create_temp_section("🔥 CPU Temperature", 0)
        self.cpu_temp_label = ttk.Label(self.cpu_frame, text="--°C", style='Temp.TLabel')
        self.cpu_temp_label.pack()
        
        # GPU Temperature
        self.gpu_frame = self.create_temp_section("🎮 GPU Temperature", 1)
        self.gpu_temp_label = ttk.Label(self.gpu_frame, text="--°C", style='Temp.TLabel')
        self.gpu_temp_label.pack()
        
        # NVMe Temperature
        self.nvme_frame = self.create_temp_section("💾 NVMe Temperature", 2)
        self.nvme_temp_label = ttk.Label(self.nvme_frame, text="--°C", style='Temp.TLabel')
        self.nvme_temp_label.pack()
        
        # Close button
        close_frame = tk.Frame(self.root, bg=self.bg_color)
        close_frame.pack(pady=10)
        
        close_btn = tk.Button(close_frame, text="Close", 
                             command=self.root.destroy,
                             bg=self.accent_color, fg=self.bg_color,
                             font=('JetBrainsMono Nerd Font', 10, 'bold'),
                             relief='flat', padx=20)
        close_btn.pack()
        
    def create_temp_section(self, title, row):
        frame = tk.Frame(self.temp_frame, bg=self.bg_color, relief='solid', bd=1)
        frame.pack(fill='x', pady=5, padx=10)
        
        title_label = ttk.Label(frame, text=title, style='Dark.TLabel')
        title_label.pack(pady=5)
        
        return frame
        
    def get_cpu_temperature(self):
        """Get CPU temperature from hwmon"""
        try:
            # Look for k10temp (AMD) or coretemp (Intel)
            hwmon_paths = Path("/sys/class/hwmon").glob("hwmon*/")
            
            for path in hwmon_paths:
                name_file = path / "name"
                if name_file.exists():
                    name = name_file.read_text().strip()
                    if name in ["k10temp", "coretemp"]:
                        temp_file = path / "temp1_input"
                        if temp_file.exists():
                            temp_millicelsius = int(temp_file.read_text().strip())
                            return temp_millicelsius / 1000.0
            return None
        except Exception as e:
            print(f"Error reading CPU temperature: {e}")
            return None
            
    def get_gpu_temperature(self):
        """Get GPU temperature"""
        try:
            # Try AMD GPU first
            result = subprocess.run(['rocm-smi', '--showtemp'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                # Parse rocm-smi output
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'Temperature' in line and '°C' in line:
                        temp_match = re.search(r'(\d+)°C', line)
                        if temp_match:
                            return float(temp_match.group(1))
        except Exception:
            pass
            
        try:
            # Try NVIDIA GPU
            result = subprocess.run(['nvidia-smi', '--query-gpu=temperature.gpu', 
                                   '--format=csv,noheader,nounits'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                temp_str = result.stdout.strip()
                if temp_str and temp_str != 'N/A':
                    return float(temp_str)
        except Exception:
            pass
            
        try:
            # Try amdgpu hwmon
            hwmon_paths = Path("/sys/class/hwmon").glob("hwmon*/")
            
            for path in hwmon_paths:
                name_file = path / "name"
                if name_file.exists():
                    name = name_file.read_text().strip()
                    if name == "amdgpu":
                        temp_file = path / "temp1_input"
                        if temp_file.exists():
                            temp_millicelsius = int(temp_file.read_text().strip())
                            return temp_millicelsius / 1000.0
        except Exception:
            pass
            
        return None
        
    def get_nvme_temperature(self):
        """Get NVMe temperature"""
        try:
            # Try smartctl first
            result = subprocess.run(['smartctl', '-A', '/dev/nvme0'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'Temperature' in line:
                        temp_match = re.search(r'(\d+)\s+Celsius', line)
                        if temp_match:
                            return float(temp_match.group(1))
        except Exception:
            pass
            
        try:
            # Try hwmon for nvme
            hwmon_paths = Path("/sys/class/hwmon").glob("hwmon*/")
            
            for path in hwmon_paths:
                name_file = path / "name"
                if name_file.exists():
                    name = name_file.read_text().strip()
                    if name == "nvme":
                        temp_file = path / "temp1_input"
                        if temp_file.exists():
                            temp_millicelsius = int(temp_file.read_text().strip())
                            return temp_millicelsius / 1000.0
        except Exception:
            pass
            
        return None
        
    def get_temp_color(self, temp):
        """Get color based on temperature"""
        if temp is None:
            return self.fg_color
        elif temp < 50:
            return self.good_color
        elif temp < 70:
            return self.accent_color
        else:
            return self.warning_color
            
    def format_temperature(self, temp):
        """Format temperature with appropriate color"""
        if temp is None:
            return "N/A", self.fg_color
        else:
            color = self.get_temp_color(temp)
            return f"{temp:.1f}°C", color
            
    def update_temperatures(self):
        """Update all temperature displays"""
        # Get temperatures
        cpu_temp = self.get_cpu_temperature()
        gpu_temp = self.get_gpu_temperature()
        nvme_temp = self.get_nvme_temperature()
        
        # Update CPU
        cpu_text, cpu_color = self.format_temperature(cpu_temp)
        self.cpu_temp_label.configure(text=cpu_text, foreground=cpu_color)
        
        # Update GPU
        gpu_text, gpu_color = self.format_temperature(gpu_temp)
        self.gpu_temp_label.configure(text=gpu_text, foreground=gpu_color)
        
        # Update NVMe
        nvme_text, nvme_color = self.format_temperature(nvme_temp)
        self.nvme_temp_label.configure(text=nvme_text, foreground=nvme_color)
        
    def update_thread(self):
        """Background thread to update temperatures"""
        def update_loop():
            while True:
                try:
                    self.root.after(0, self.update_temperatures)
                    time.sleep(2)
                except:
                    break
                    
        thread = threading.Thread(target=update_loop, daemon=True)
        thread.start()
        
    def run(self):
        # Center the window
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - (self.root.winfo_width() // 2)
        y = (self.root.winfo_screenheight() // 2) - (self.root.winfo_height() // 2)
        self.root.geometry(f"+{x}+{y}")
        
        # Keep window on top
        self.root.attributes('-topmost', True)
        
        self.root.mainloop()

if __name__ == "__main__":
    app = TemperatureDashboard()
    app.run()