#!/usr/bin/env python3

import requests
import random
import time
import os
import threading
import logging
from flask import Flask

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class CrawlerPod:
    def __init__(self):
        self.proxies = self._parse_proxy_config()
        self.running = True
        
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
    
    def crawl_data(self):
        """Simulate crawling activity"""
        destinations = [
            'httpbin.org/json',
            'jsonplaceholder.typicode.com/posts/1',
            'httpstat.us/200'
        ]
        
        while self.running:
            try:
                proxy = random.choice(self.proxies)
                destination = random.choice(destinations)
                
                proxy_dict = {
                    'http': f"http://{proxy['ip']}:{proxy['port']}",
                    'https': f"http://{proxy['ip']}:{proxy['port']}"
                }
                
                headers = {
                    'X-Proxy-Vendor': proxy['vendor'],
                    'X-Proxy-IP': proxy['ip'],
                    'X-Forwarded-For': proxy['ip'],
                    'User-Agent': 'Crawler-Pod/1.0'
                }
                
                response = requests.get(
                    f"https://{destination}",
                    proxies=proxy_dict,
                    headers=headers,
                    timeout=10
                )
                
                logger.info(f"Crawled {destination} via {proxy['vendor']} - Status: {response.status_code}")
                
            except Exception as e:
                logger.error(f"Crawl failed: {e}")
            
            time.sleep(random.randint(5, 15))  # Random delay between requests

@app.route('/health')
def health():
    return {'status': 'healthy'}, 200

@app.route('/metrics')
def metrics():
    return {'crawler_status': 'running'}, 200

def main():
    crawler = CrawlerPod()
    
    # Start crawler in background thread
    crawler_thread = threading.Thread(target=crawler.crawl_data)
    crawler_thread.daemon = True
    crawler_thread.start()
    
    logger.info(f"Started crawler pod with {len(crawler.proxies)} proxies")
    
    # Start Flask server
    app.run(host='0.0.0.0', port=8080)

if __name__ == "__main__":
    main()