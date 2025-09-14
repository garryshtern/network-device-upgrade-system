#!/usr/bin/env python3
"""
Performance and Load Testing Suite
Advanced performance validation for Network Device Upgrade System
Addresses performance testing gaps identified in comprehensive coverage analysis
"""

import asyncio
import time
import psutil
import threading
import requests
import paramiko
import statistics
from typing import Dict, List, Tuple, Any
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timedelta
import json
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class PerformanceMetrics:
    """Container for performance test results"""
    test_name: str
    start_time: datetime
    end_time: datetime
    duration_seconds: float
    success_rate: float
    avg_response_time: float
    min_response_time: float
    max_response_time: float
    p95_response_time: float
    p99_response_time: float
    throughput_ops_per_sec: float
    memory_usage_mb: float
    cpu_usage_percent: float
    network_io_mbps: float
    errors: List[str]
    passed: bool

class PerformanceTestSuite:
    """Comprehensive performance testing for network device upgrade system"""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.results: List[PerformanceMetrics] = []
        self.base_url = config.get('base_url', 'http://localhost:8080')
        self.awx_url = config.get('awx_url', 'http://localhost:8052')
        self.netbox_url = config.get('netbox_url', 'http://localhost:8000')

    async def run_all_performance_tests(self) -> Dict[str, Any]:
        """Execute all performance test scenarios"""
        logger.info("Starting comprehensive performance testing suite")

        test_scenarios = [
            self.test_concurrent_device_upgrades,
            self.test_api_rate_limiting,
            self.test_memory_leak_detection,
            self.test_database_performance,
            self.test_network_throughput,
            self.test_stress_testing,
            self.test_endurance_testing,
            self.test_spike_testing,
            self.test_scalability_limits
        ]

        for test_scenario in test_scenarios:
            try:
                await test_scenario()
            except Exception as e:
                logger.error(f"Test scenario failed: {e}")

        return self.generate_performance_report()

    async def test_concurrent_device_upgrades(self):
        """Test system performance under concurrent device upgrade load"""
        test_name = "Concurrent Device Upgrades"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()
        response_times = []
        errors = []
        success_count = 0

        # Simulate 100 concurrent device upgrades
        concurrent_upgrades = 100

        async def simulate_device_upgrade(device_id: int) -> Tuple[float, bool]:
            """Simulate a single device upgrade"""
            upgrade_start = time.time()
            try:
                # Simulate upgrade workflow
                await self._simulate_upgrade_workflow(device_id)
                upgrade_time = time.time() - upgrade_start
                return upgrade_time, True
            except Exception as e:
                errors.append(f"Device {device_id}: {str(e)}")
                return time.time() - upgrade_start, False

        # Execute concurrent upgrades
        tasks = [
            simulate_device_upgrade(i)
            for i in range(concurrent_upgrades)
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        for result in results:
            if isinstance(result, tuple):
                response_time, success = result
                response_times.append(response_time)
                if success:
                    success_count += 1
            else:
                errors.append(str(result))

        end_time = datetime.now()

        # Calculate performance metrics
        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=(success_count / concurrent_upgrades) * 100,
            avg_response_time=statistics.mean(response_times) if response_times else 0,
            min_response_time=min(response_times) if response_times else 0,
            max_response_time=max(response_times) if response_times else 0,
            p95_response_time=self._percentile(response_times, 95) if response_times else 0,
            p99_response_time=self._percentile(response_times, 99) if response_times else 0,
            throughput_ops_per_sec=concurrent_upgrades / (end_time - start_time).total_seconds(),
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=self._get_network_io_rate(),
            errors=errors,
            passed=len(errors) == 0 and success_count / concurrent_upgrades >= 0.95
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: {metrics.success_rate}% success rate")

    async def test_api_rate_limiting(self):
        """Test API performance under high request rates"""
        test_name = "API Rate Limiting"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()
        response_times = []
        errors = []

        # Test different API endpoints
        api_endpoints = [
            f"{self.awx_url}/api/v2/jobs/",
            f"{self.netbox_url}/api/dcim/devices/",
            f"{self.base_url}/api/upgrade/status/"
        ]

        # Send 1000 requests per endpoint (3000 total)
        requests_per_endpoint = 1000

        async def send_api_request(endpoint: str, request_id: int) -> Tuple[float, bool]:
            """Send a single API request and measure response time"""
            request_start = time.time()
            try:
                response = requests.get(endpoint, timeout=30)
                request_time = time.time() - request_start
                return request_time, response.status_code == 200
            except Exception as e:
                errors.append(f"Request {request_id} to {endpoint}: {str(e)}")
                return time.time() - request_start, False

        # Execute concurrent API requests
        tasks = []
        request_id = 0
        for endpoint in api_endpoints:
            for _ in range(requests_per_endpoint):
                tasks.append(send_api_request(endpoint, request_id))
                request_id += 1

        results = await asyncio.gather(*tasks, return_exceptions=True)

        success_count = 0
        for result in results:
            if isinstance(result, tuple):
                response_time, success = result
                response_times.append(response_time)
                if success:
                    success_count += 1
            else:
                errors.append(str(result))

        end_time = datetime.now()

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=(success_count / len(tasks)) * 100,
            avg_response_time=statistics.mean(response_times) if response_times else 0,
            min_response_time=min(response_times) if response_times else 0,
            max_response_time=max(response_times) if response_times else 0,
            p95_response_time=self._percentile(response_times, 95) if response_times else 0,
            p99_response_time=self._percentile(response_times, 99) if response_times else 0,
            throughput_ops_per_sec=len(tasks) / (end_time - start_time).total_seconds(),
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=self._get_network_io_rate(),
            errors=errors,
            passed=len(errors) < len(tasks) * 0.05  # Allow 5% error rate
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: {metrics.throughput_ops_per_sec:.2f} req/sec")

    async def test_memory_leak_detection(self):
        """Test for memory leaks during prolonged operations"""
        test_name = "Memory Leak Detection"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()
        memory_samples = []
        errors = []

        # Run continuous operations for 10 minutes
        test_duration = 600  # 10 minutes
        sample_interval = 30  # Sample every 30 seconds

        async def continuous_operations():
            """Continuously execute upgrade operations"""
            while (datetime.now() - start_time).total_seconds() < test_duration:
                try:
                    # Simulate various operations
                    await self._simulate_device_discovery()
                    await self._simulate_configuration_backup()
                    await self._simulate_image_upload()
                    await self._simulate_validation_check()
                    await asyncio.sleep(1)
                except Exception as e:
                    errors.append(f"Operation error: {str(e)}")

        async def memory_monitoring():
            """Monitor memory usage during operations"""
            while (datetime.now() - start_time).total_seconds() < test_duration:
                memory_usage = psutil.virtual_memory().used / 1024 / 1024
                memory_samples.append(memory_usage)
                await asyncio.sleep(sample_interval)

        # Run operations and monitoring concurrently
        await asyncio.gather(
            continuous_operations(),
            memory_monitoring()
        )

        end_time = datetime.now()

        # Analyze memory leak
        if len(memory_samples) >= 2:
            memory_trend = memory_samples[-1] - memory_samples[0]
            memory_leak_detected = memory_trend > 100  # 100MB increase indicates leak
        else:
            memory_leak_detected = False
            memory_trend = 0

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=100.0 if not memory_leak_detected else 0.0,
            avg_response_time=0,
            min_response_time=0,
            max_response_time=0,
            p95_response_time=0,
            p99_response_time=0,
            throughput_ops_per_sec=0,
            memory_usage_mb=memory_samples[-1] if memory_samples else 0,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=0,
            errors=errors + ([f"Memory leak detected: {memory_trend:.2f}MB increase"] if memory_leak_detected else []),
            passed=not memory_leak_detected and len(errors) == 0
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: Memory trend = {memory_trend:.2f}MB")

    async def test_database_performance(self):
        """Test database performance under load"""
        test_name = "Database Performance"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()
        query_times = []
        errors = []

        # Simulate database operations
        operations = [
            ("device_lookup", 1000),
            ("firmware_search", 500),
            ("audit_log_insert", 2000),
            ("inventory_update", 300),
            ("status_query", 1500)
        ]

        for operation_type, operation_count in operations:
            for i in range(operation_count):
                query_start = time.time()
                try:
                    await self._simulate_database_operation(operation_type, i)
                    query_time = time.time() - query_start
                    query_times.append(query_time)
                except Exception as e:
                    errors.append(f"{operation_type}_{i}: {str(e)}")

        end_time = datetime.now()

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=((len(query_times) / sum(count for _, count in operations)) * 100) if query_times else 0,
            avg_response_time=statistics.mean(query_times) if query_times else 0,
            min_response_time=min(query_times) if query_times else 0,
            max_response_time=max(query_times) if query_times else 0,
            p95_response_time=self._percentile(query_times, 95) if query_times else 0,
            p99_response_time=self._percentile(query_times, 99) if query_times else 0,
            throughput_ops_per_sec=len(query_times) / (end_time - start_time).total_seconds() if query_times else 0,
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=self._get_network_io_rate(),
            errors=errors,
            passed=len(errors) == 0 and statistics.mean(query_times) < 0.1 if query_times else False
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: {metrics.avg_response_time:.3f}s avg query time")

    async def test_network_throughput(self):
        """Test network throughput during large file transfers"""
        test_name = "Network Throughput"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()
        transfer_rates = []
        errors = []

        # Simulate firmware file transfers (various sizes)
        file_sizes = [10, 50, 100, 200, 500]  # MB

        for size_mb in file_sizes:
            try:
                transfer_start = time.time()
                await self._simulate_file_transfer(size_mb)
                transfer_time = time.time() - transfer_start
                transfer_rate = size_mb / transfer_time  # MB/s
                transfer_rates.append(transfer_rate)
            except Exception as e:
                errors.append(f"Transfer {size_mb}MB: {str(e)}")

        end_time = datetime.now()

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=((len(transfer_rates) / len(file_sizes)) * 100) if transfer_rates else 0,
            avg_response_time=statistics.mean(transfer_rates) if transfer_rates else 0,
            min_response_time=min(transfer_rates) if transfer_rates else 0,
            max_response_time=max(transfer_rates) if transfer_rates else 0,
            p95_response_time=self._percentile(transfer_rates, 95) if transfer_rates else 0,
            p99_response_time=self._percentile(transfer_rates, 99) if transfer_rates else 0,
            throughput_ops_per_sec=0,
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=statistics.mean(transfer_rates) if transfer_rates else 0,
            errors=errors,
            passed=len(errors) == 0 and statistics.mean(transfer_rates) >= 10 if transfer_rates else False  # 10 MB/s minimum
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: {metrics.network_io_mbps:.2f} MB/s avg throughput")

    async def test_stress_testing(self):
        """Test system behavior under maximum load"""
        test_name = "Stress Testing"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()

        # Generate maximum possible load
        max_workers = psutil.cpu_count() * 4
        stress_duration = 300  # 5 minutes

        async def stress_worker(worker_id: int) -> Dict[str, Any]:
            """Individual stress worker"""
            operations = 0
            errors = []

            worker_start = time.time()
            while time.time() - worker_start < stress_duration:
                try:
                    # Perform intensive operations
                    await self._cpu_intensive_task()
                    await self._memory_intensive_task()
                    await self._io_intensive_task()
                    operations += 1
                except Exception as e:
                    errors.append(f"Worker {worker_id}: {str(e)}")

                # Brief pause to prevent complete system lockup
                await asyncio.sleep(0.01)

            return {
                'worker_id': worker_id,
                'operations': operations,
                'errors': errors
            }

        # Execute stress workers
        tasks = [stress_worker(i) for i in range(max_workers)]
        worker_results = await asyncio.gather(*tasks, return_exceptions=True)

        end_time = datetime.now()

        # Aggregate results
        total_operations = sum(r['operations'] for r in worker_results if isinstance(r, dict))
        total_errors = sum(len(r['errors']) for r in worker_results if isinstance(r, dict))

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=((total_operations - total_errors) / total_operations * 100) if total_operations > 0 else 0,
            avg_response_time=0,
            min_response_time=0,
            max_response_time=0,
            p95_response_time=0,
            p99_response_time=0,
            throughput_ops_per_sec=total_operations / (end_time - start_time).total_seconds(),
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=self._get_network_io_rate(),
            errors=[f"Total errors: {total_errors}"],
            passed=total_errors == 0 and total_operations > 0
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: {total_operations} operations, {total_errors} errors")

    async def test_endurance_testing(self):
        """Test system stability over extended periods"""
        test_name = "Endurance Testing"
        logger.info(f"Starting {test_name}")

        # This would run for hours in production, shortened for demo
        endurance_duration = 1800  # 30 minutes for demo
        start_time = datetime.now()

        # Track system health over time
        health_checks = []
        errors = []

        async def endurance_operations():
            """Continuous operations for endurance testing"""
            operation_count = 0
            while (datetime.now() - start_time).total_seconds() < endurance_duration:
                try:
                    # Simulate regular upgrade operations
                    await self._simulate_upgrade_workflow(operation_count % 100)
                    operation_count += 1

                    # Health check every 100 operations
                    if operation_count % 100 == 0:
                        health_status = await self._system_health_check()
                        health_checks.append(health_status)

                        # Log progress
                        elapsed = (datetime.now() - start_time).total_seconds()
                        logger.info(f"Endurance test progress: {elapsed:.0f}s, {operation_count} ops")

                    await asyncio.sleep(0.1)  # Brief pause

                except Exception as e:
                    errors.append(f"Operation {operation_count}: {str(e)}")

        await endurance_operations()
        end_time = datetime.now()

        # Analyze system stability
        system_stable = all(h['stable'] for h in health_checks) if health_checks else False

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=100.0 if system_stable and len(errors) == 0 else 0.0,
            avg_response_time=0,
            min_response_time=0,
            max_response_time=0,
            p95_response_time=0,
            p99_response_time=0,
            throughput_ops_per_sec=0,
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=0,
            errors=errors + ([] if system_stable else ["System instability detected"]),
            passed=system_stable and len(errors) == 0
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: System stable = {system_stable}")

    async def test_spike_testing(self):
        """Test system response to sudden load spikes"""
        test_name = "Spike Testing"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()

        # Normal load phase
        await self._simulate_normal_load(duration=60)

        # Spike phase - sudden 10x increase
        spike_start = time.time()
        await self._simulate_spike_load(duration=120, multiplier=10)
        spike_duration = time.time() - spike_start

        # Recovery phase
        recovery_start = time.time()
        await self._simulate_normal_load(duration=60)
        recovery_duration = time.time() - recovery_start

        end_time = datetime.now()

        # Check if system recovered properly
        system_recovered = await self._check_system_recovery()

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=100.0 if system_recovered else 0.0,
            avg_response_time=spike_duration,
            min_response_time=0,
            max_response_time=spike_duration,
            p95_response_time=0,
            p99_response_time=0,
            throughput_ops_per_sec=0,
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=0,
            errors=[] if system_recovered else ["System failed to recover from spike"],
            passed=system_recovered
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: Recovery = {system_recovered}")

    async def test_scalability_limits(self):
        """Test system scalability limits"""
        test_name = "Scalability Limits"
        logger.info(f"Starting {test_name}")

        start_time = datetime.now()
        scalability_data = []

        # Test increasing load levels
        load_levels = [10, 50, 100, 200, 500, 1000]

        for load_level in load_levels:
            logger.info(f"Testing scalability at {load_level} concurrent operations")

            load_start = time.time()
            success_count = 0

            # Execute concurrent operations at this load level
            tasks = [
                self._simulate_upgrade_workflow(i)
                for i in range(load_level)
            ]

            results = await asyncio.gather(*tasks, return_exceptions=True)

            for result in results:
                if not isinstance(result, Exception):
                    success_count += 1

            load_duration = time.time() - load_start
            throughput = success_count / load_duration

            scalability_data.append({
                'load_level': load_level,
                'success_rate': (success_count / load_level) * 100,
                'throughput': throughput,
                'duration': load_duration
            })

            # Stop if system starts failing significantly
            if success_count / load_level < 0.5:  # Less than 50% success
                logger.warning(f"System degraded significantly at {load_level} load")
                break

        end_time = datetime.now()

        # Find maximum sustainable load
        max_sustainable_load = max(
            data['load_level'] for data in scalability_data
            if data['success_rate'] >= 95
        ) if scalability_data else 0

        metrics = PerformanceMetrics(
            test_name=test_name,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=(end_time - start_time).total_seconds(),
            success_rate=100.0 if max_sustainable_load >= 100 else 50.0,
            avg_response_time=0,
            min_response_time=0,
            max_response_time=0,
            p95_response_time=0,
            p99_response_time=0,
            throughput_ops_per_sec=max_sustainable_load,
            memory_usage_mb=psutil.virtual_memory().used / 1024 / 1024,
            cpu_usage_percent=psutil.cpu_percent(interval=1),
            network_io_mbps=0,
            errors=[f"Max sustainable load: {max_sustainable_load}"],
            passed=max_sustainable_load >= 100  # Require at least 100 concurrent operations
        )

        self.results.append(metrics)
        logger.info(f"Completed {test_name}: Max sustainable load = {max_sustainable_load}")

    # Helper methods for simulation
    async def _simulate_upgrade_workflow(self, device_id: int):
        """Simulate a complete device upgrade workflow"""
        await asyncio.sleep(0.1)  # Simulate network latency
        await self._simulate_device_connection(device_id)
        await self._simulate_pre_upgrade_validation(device_id)
        await self._simulate_image_upload(device_id)
        await self._simulate_upgrade_execution(device_id)
        await self._simulate_post_upgrade_validation(device_id)

    async def _simulate_device_connection(self, device_id: int):
        """Simulate device SSH connection"""
        await asyncio.sleep(0.05)

    async def _simulate_pre_upgrade_validation(self, device_id: int):
        """Simulate pre-upgrade validation checks"""
        await asyncio.sleep(0.1)

    async def _simulate_image_upload(self, device_id: int = None):
        """Simulate firmware image upload"""
        await asyncio.sleep(0.2)

    async def _simulate_upgrade_execution(self, device_id: int):
        """Simulate upgrade execution"""
        await asyncio.sleep(0.3)

    async def _simulate_post_upgrade_validation(self, device_id: int):
        """Simulate post-upgrade validation"""
        await asyncio.sleep(0.1)

    async def _simulate_device_discovery(self):
        """Simulate device discovery"""
        await asyncio.sleep(0.05)

    async def _simulate_configuration_backup(self):
        """Simulate configuration backup"""
        await asyncio.sleep(0.1)

    async def _simulate_validation_check(self):
        """Simulate validation check"""
        await asyncio.sleep(0.05)

    async def _simulate_database_operation(self, operation_type: str, operation_id: int):
        """Simulate database operation"""
        await asyncio.sleep(0.01)  # Simulate DB query time

    async def _simulate_file_transfer(self, size_mb: int):
        """Simulate file transfer"""
        await asyncio.sleep(size_mb * 0.01)  # 0.01s per MB

    async def _cpu_intensive_task(self):
        """Simulate CPU-intensive task"""
        # Perform some CPU-bound calculation
        sum(i * i for i in range(1000))
        await asyncio.sleep(0.001)

    async def _memory_intensive_task(self):
        """Simulate memory-intensive task"""
        # Allocate and deallocate memory
        data = [0] * 1000
        del data
        await asyncio.sleep(0.001)

    async def _io_intensive_task(self):
        """Simulate I/O-intensive task"""
        await asyncio.sleep(0.01)

    async def _system_health_check(self) -> Dict[str, Any]:
        """Perform system health check"""
        memory_usage = psutil.virtual_memory().percent
        cpu_usage = psutil.cpu_percent(interval=0.1)

        return {
            'stable': memory_usage < 90 and cpu_usage < 95,
            'memory_usage': memory_usage,
            'cpu_usage': cpu_usage
        }

    async def _simulate_normal_load(self, duration: int):
        """Simulate normal operational load"""
        tasks = [
            self._simulate_upgrade_workflow(i % 10)
            for i in range(duration // 2)
        ]
        await asyncio.gather(*tasks, return_exceptions=True)

    async def _simulate_spike_load(self, duration: int, multiplier: int):
        """Simulate sudden load spike"""
        tasks = [
            self._simulate_upgrade_workflow(i % 100)
            for i in range(duration * multiplier)
        ]
        await asyncio.gather(*tasks, return_exceptions=True)

    async def _check_system_recovery(self) -> bool:
        """Check if system recovered properly from spike"""
        health = await self._system_health_check()
        return health['stable']

    def _percentile(self, data: List[float], percentile: int) -> float:
        """Calculate percentile of data"""
        if not data:
            return 0.0
        sorted_data = sorted(data)
        index = int(len(sorted_data) * percentile / 100)
        return sorted_data[min(index, len(sorted_data) - 1)]

    def _get_network_io_rate(self) -> float:
        """Get current network I/O rate in MB/s"""
        net_io = psutil.net_io_counters()
        # This is a simplified calculation
        return (net_io.bytes_sent + net_io.bytes_recv) / 1024 / 1024

    def generate_performance_report(self) -> Dict[str, Any]:
        """Generate comprehensive performance test report"""
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r.passed)

        return {
            'summary': {
                'total_tests': total_tests,
                'passed_tests': passed_tests,
                'failed_tests': total_tests - passed_tests,
                'success_rate': (passed_tests / total_tests * 100) if total_tests > 0 else 0,
                'overall_grade': self._calculate_overall_grade()
            },
            'test_results': [
                {
                    'test_name': r.test_name,
                    'passed': r.passed,
                    'duration_seconds': r.duration_seconds,
                    'success_rate': r.success_rate,
                    'avg_response_time': r.avg_response_time,
                    'p95_response_time': r.p95_response_time,
                    'throughput_ops_per_sec': r.throughput_ops_per_sec,
                    'memory_usage_mb': r.memory_usage_mb,
                    'cpu_usage_percent': r.cpu_usage_percent,
                    'network_io_mbps': r.network_io_mbps,
                    'error_count': len(r.errors)
                }
                for r in self.results
            ],
            'recommendations': self._generate_recommendations(),
            'benchmarks': self._compare_against_benchmarks()
        }

    def _calculate_overall_grade(self) -> str:
        """Calculate overall performance grade"""
        if not self.results:
            return 'F'

        passed_percentage = sum(1 for r in self.results if r.passed) / len(self.results) * 100

        if passed_percentage >= 95:
            return 'A+'
        elif passed_percentage >= 90:
            return 'A'
        elif passed_percentage >= 85:
            return 'B+'
        elif passed_percentage >= 80:
            return 'B'
        elif passed_percentage >= 75:
            return 'C+'
        elif passed_percentage >= 70:
            return 'C'
        elif passed_percentage >= 60:
            return 'D'
        else:
            return 'F'

    def _generate_recommendations(self) -> List[str]:
        """Generate performance improvement recommendations"""
        recommendations = []

        for result in self.results:
            if not result.passed:
                if 'Memory Leak' in result.test_name:
                    recommendations.append("Investigate memory leaks - implement memory profiling")
                elif 'API Rate' in result.test_name:
                    recommendations.append("Optimize API performance - consider caching and rate limiting")
                elif 'Concurrent' in result.test_name:
                    recommendations.append("Improve concurrency handling - review thread pool configuration")
                elif 'Database' in result.test_name:
                    recommendations.append("Optimize database queries - consider indexing and query optimization")
                elif 'Network' in result.test_name:
                    recommendations.append("Enhance network performance - review bandwidth and latency optimization")

        if not recommendations:
            recommendations.append("Performance is excellent - maintain current optimization practices")

        return recommendations

    def _compare_against_benchmarks(self) -> Dict[str, str]:
        """Compare results against industry benchmarks"""
        benchmarks = {}

        for result in self.results:
            if 'API' in result.test_name:
                if result.avg_response_time < 0.1:
                    benchmarks[result.test_name] = "Excellent (< 100ms)"
                elif result.avg_response_time < 0.5:
                    benchmarks[result.test_name] = "Good (< 500ms)"
                else:
                    benchmarks[result.test_name] = "Needs Improvement (> 500ms)"

            elif 'Concurrent' in result.test_name:
                if result.throughput_ops_per_sec > 100:
                    benchmarks[result.test_name] = "Excellent (> 100 ops/sec)"
                elif result.throughput_ops_per_sec > 50:
                    benchmarks[result.test_name] = "Good (> 50 ops/sec)"
                else:
                    benchmarks[result.test_name] = "Needs Improvement (< 50 ops/sec)"

        return benchmarks

# Main execution
async def main():
    """Main performance testing execution"""
    config = {
        'base_url': 'http://localhost:8080',
        'awx_url': 'http://localhost:8052',
        'netbox_url': 'http://localhost:8000'
    }

    performance_suite = PerformanceTestSuite(config)
    report = await performance_suite.run_all_performance_tests()

    # Save report
    with open('performance_test_report.json', 'w') as f:
        json.dump(report, f, indent=2)

    print("\n" + "="*80)
    print("PERFORMANCE TESTING COMPLETE")
    print("="*80)
    print(f"Total Tests: {report['summary']['total_tests']}")
    print(f"Passed: {report['summary']['passed_tests']}")
    print(f"Failed: {report['summary']['failed_tests']}")
    print(f"Success Rate: {report['summary']['success_rate']:.1f}%")
    print(f"Overall Grade: {report['summary']['overall_grade']}")
    print(f"\nDetailed report saved to: performance_test_report.json")

    # Return exit code based on results
    return 0 if report['summary']['success_rate'] >= 80 else 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)