#!/usr/bin/env python3
"""Wireguard HealthCheck"""

from http.server import BaseHTTPRequestHandler, HTTPServer


class WebServer(BaseHTTPRequestHandler):
    """HTTP Server."""

    server_version = 'meow!'
    sys_version = 'You shall not pass!'

    def _set_headers(self):
        """Set HTTP headers."""
        self.send_header('Content-type', 'text/html')
        self.end_headers()

    def _content(self):
        """Set content."""
        self.send_response(return_status_code('wg0'))
        self._set_headers()
        content = '''
        <html><head><title>Wireguard Health Check</title></head>
        <body>
        <pre>
            meow!
        </pre>
        </body></html>
        '''
        return bytes(content, 'UTF-8')

    def do_GET(self):
        """GET method."""
        self.wfile.write(self._content())

    def do_HEAD(self):
        """HEAD method."""
        self.send_response(return_status_code('wg0'))
        self._set_headers()

def is_link_up(interface):
    """Define if network link is up."""
    try:
        open(f'/sys/class/net/{interface}/carrier').read().strip()

    except (FileNotFoundError, OSError):
        return False

    return True

def return_status_code(interface):
    """Create status code based on wireguard network interface status."""
    if not is_link_up(interface):
        return 503

    return 200


if __name__ == '__main__':
    with HTTPServer(('0.0.0.0', 8080), WebServer) as httpd:
        httpd.serve_forever()
        