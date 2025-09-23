#!/usr/bin/env python3

import asyncio
import aiohttp
import random
import os
import time
import logging
from prometheus_client import Counter, Histogram, start_http_server

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNTER = Counter('load_gen_requests_total', 'Total requests sent', ['proxy_vendor', 'destination', 'status'])
REQUEST_DURATION = Histogram('load_gen_request_duration_seconds', 'Request duration', ['proxy_vendor', 'destination'])

class ProxyLoadGenerator:
    def __init__(self):
        self.request_rate = int(os.getenv('REQUEST_RATE', '10'))
        self.proxies = self._parse_proxy_config()
        self.destinations = os.getenv('DESTINATIONS', 'httpbin.org').split(',')
        
    def _parse_proxy_config(self):
        """Parse proxy configuration from environment"""
        config = os.getenv('PROXY_CONFIG', '')
        proxies = []
        
        for line in config.strip().split('\n'):
            if ':' in line:
                parts = line.split(':')
                vendor = parts[0]
                ips = parts[1].split(',')
                port = parts[2] if len(parts) > 2 else '8080'
                
                for ip in ips:
                    proxies.append({
                        'vendor': vendor,
                        'ip': ip.strip(),
                        'port': port
                    })
        
        return proxies if proxies else [{'vendor': 'default', 'ip': '127.0.0.1', 'port': '8080'}]
    
    async def make_request(self, session, proxy, destination):
        """Make HTTP request through proxy"""
        proxy_url = f"http://{proxy['ip']}:{proxy['port']}"
        url = f"https://{destination}/get" if destination != 'httpbin.org' else f"https://{destination}/json"
        
        headers = {
            'X-Proxy-Vendor': proxy['vendor'],
            'X-Proxy-IP': proxy['ip'],
            'User-Agent': 'Crawler-Bot/1.0'
        }
        
        start_time = time.time()
        status = 'success'
        
        try:
            async with session.get(url, proxy=proxy_url, headers=headers, timeout=30) as response:
                await response.text()
                logger.info(f"Request to {destination} via {proxy['vendor']} ({proxy['ip']}) - Status: {response.status}")
                
        except Exception as e:
            status = 'error'
            logger.error(f"Request failed: {e}")
        
        duration = time.time() - start_time
        
        # Update metrics
        REQUEST_COUNTER.labels(proxy_vendor=proxy['vendor'], destination=destination, status=status).inc()
        REQUEST_DURATION.labels(proxy_vendor=proxy['vendor'], destination=destination).observe(duration)
    
    async def generate_load(self):
        """Generate continuous load"""
        connector = aiohttp.TCPConnector(limit=100)
        timeout = aiohttp.ClientTimeout(total=30)
        
        async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
            while True:
                tasks = []
                
                for _ in range(self.request_rate):
                    proxy = random.choice(self.proxies)
                    destination = random.choice(self.destinations)
                    task = self.make_request(session, proxy, destination)
                    tasks.append(task)
                
                await asyncio.gather(*tasks, return_exceptions=True)
                await asyncio.sleep(1)  # Wait 1 second between batches

async def main():
    # Start Prometheus metrics server
    start_http_server(8080)
    logger.info("Started Prometheus metrics server on port 8080")
    
    # Start load generator
    generator = ProxyLoadGenerator()
    logger.info(f"Starting load generator with {len(generator.proxies)} proxies and {len(generator.destinations)} destinations")
    
    await generator.generate_load()

if __name__ == "__main__":
    asyncio.run(main())