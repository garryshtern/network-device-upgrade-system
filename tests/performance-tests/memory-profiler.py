#!/usr/bin/env python3
"""
Memory profiling script for Ansible playbook execution
Monitors memory usage patterns during playbook execution
"""

import os
import sys
import time
import psutil
import subprocess
import argparse
from datetime import datetime

class MemoryProfiler:
    def __init__(self, interval=1):
        self.interval = interval
        self.measurements = []
        self.start_time = None
        
    def start_monitoring(self):
        """Start memory monitoring"""
        self.start_time = time.time()
        print(f"Starting memory monitoring (interval: {self.interval}s)")
        
    def take_measurement(self):
        """Take a memory measurement"""
        try:
            memory_info = psutil.virtual_memory()
            timestamp = time.time() - self.start_time if self.start_time else 0
            
            measurement = {
                'timestamp': timestamp,
                'total_mb': memory_info.total / (1024 * 1024),
                'available_mb': memory_info.available / (1024 * 1024),
                'used_mb': memory_info.used / (1024 * 1024),
                'used_percent': memory_info.percent
            }
            
            self.measurements.append(measurement)
            return measurement
            
        except Exception as e:
            print(f"Error taking measurement: {e}")
            return None
            
    def monitor_process(self, command, timeout=300):
        """Monitor memory usage while running a command"""
        print(f"Executing command: {' '.join(command)}")
        
        self.start_monitoring()
        
        # Start the process
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Monitor while process is running
            while process.poll() is None:
                self.take_measurement()
                time.sleep(self.interval)
                
                # Check timeout
                if time.time() - self.start_time > timeout:
                    process.terminate()
                    print("Process terminated due to timeout")
                    break
                    
            # Final measurement
            self.take_measurement()
            
            # Get process output
            stdout, stderr = process.communicate()
            return_code = process.returncode
            
            return {
                'return_code': return_code,
                'stdout': stdout,
                'stderr': stderr,
                'duration': time.time() - self.start_time
            }
            
        except Exception as e:
            print(f"Error monitoring process: {e}")
            return None
            
    def get_statistics(self):
        """Calculate memory usage statistics"""
        if not self.measurements:
            return None
            
        used_mb_values = [m['used_mb'] for m in self.measurements]
        used_percent_values = [m['used_percent'] for m in self.measurements]
        
        return {
            'total_measurements': len(self.measurements),
            'duration': self.measurements[-1]['timestamp'] if self.measurements else 0,
            'peak_memory_mb': max(used_mb_values),
            'min_memory_mb': min(used_mb_values),
            'avg_memory_mb': sum(used_mb_values) / len(used_mb_values),
            'peak_memory_percent': max(used_percent_values),
            'avg_memory_percent': sum(used_percent_values) / len(used_percent_values),
            'memory_delta_mb': max(used_mb_values) - min(used_mb_values)
        }
        
    def save_results(self, output_file):
        """Save results to CSV file"""
        try:
            with open(output_file, 'w') as f:
                f.write("timestamp,total_mb,available_mb,used_mb,used_percent\n")
                for measurement in self.measurements:
                    f.write(f"{measurement['timestamp']:.2f},"
                           f"{measurement['total_mb']:.2f},"
                           f"{measurement['available_mb']:.2f},"
                           f"{measurement['used_mb']:.2f},"
                           f"{measurement['used_percent']:.2f}\n")
            print(f"Results saved to: {output_file}")
        except Exception as e:
            print(f"Error saving results: {e}")
            
    def generate_report(self):
        """Generate a memory usage report"""
        stats = self.get_statistics()
        if not stats:
            return "No measurements available"
            
        report = f"""
Memory Usage Report
==================
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Duration: {stats['duration']:.2f} seconds
Total measurements: {stats['total_measurements']}

Memory Usage:
- Peak: {stats['peak_memory_mb']:.2f} MB ({stats['peak_memory_percent']:.1f}%)
- Average: {stats['avg_memory_mb']:.2f} MB ({stats['avg_memory_percent']:.1f}%)
- Minimum: {stats['min_memory_mb']:.2f} MB
- Delta: {stats['memory_delta_mb']:.2f} MB

Performance Assessment:
"""
        
        # Add performance assessment
        if stats['peak_memory_percent'] > 80:
            report += "⚠️  HIGH: Memory usage exceeded 80%\n"
        elif stats['peak_memory_percent'] > 60:
            report += "⚠️  MEDIUM: Memory usage exceeded 60%\n"
        else:
            report += "✅ LOW: Memory usage stayed within normal limits\n"
            
        if stats['memory_delta_mb'] > 500:
            report += "⚠️  HIGH: Large memory delta detected (>500MB)\n"
        elif stats['memory_delta_mb'] > 200:
            report += "⚠️  MEDIUM: Moderate memory delta (>200MB)\n"
        else:
            report += "✅ LOW: Memory usage was stable\n"
            
        return report

def main():
    parser = argparse.ArgumentParser(description='Memory profiler for Ansible playbooks')
    parser.add_argument('command', nargs='+', help='Command to monitor')
    parser.add_argument('--interval', type=float, default=1.0, 
                       help='Monitoring interval in seconds (default: 1.0)')
    parser.add_argument('--output', help='Output CSV file for raw data')
    parser.add_argument('--timeout', type=int, default=300,
                       help='Command timeout in seconds (default: 300)')
    parser.add_argument('--report', help='Output file for summary report')
    
    args = parser.parse_args()
    
    profiler = MemoryProfiler(interval=args.interval)
    
    print("Starting memory profiling...")
    result = profiler.monitor_process(args.command, timeout=args.timeout)
    
    if result:
        print(f"\nCommand completed with return code: {result['return_code']}")
        print(f"Duration: {result['duration']:.2f} seconds")
        
        if result['return_code'] != 0 and result['stderr']:
            print(f"Error output: {result['stderr']}")
    
    # Generate and display report
    report = profiler.generate_report()
    print(report)
    
    # Save results if requested
    if args.output:
        profiler.save_results(args.output)
        
    if args.report:
        with open(args.report, 'w') as f:
            f.write(report)
        print(f"Report saved to: {args.report}")
        
    return 0 if result and result['return_code'] == 0 else 1

if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nProfiling interrupted by user")
        sys.exit(1)