#!/usr/bin/env python
import http.server
import socketserver

class UTF8Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Force no-cache so browser always gets fresh file
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        super().end_headers()

    def guess_type(self, path):
        ctype = super().guess_type(path)
        if ctype == 'text/html':
            return 'text/html; charset=utf-8'
        return ctype

PORT = 8080
with socketserver.TCPServer(('', PORT), UTF8Handler) as httpd:
    print(f'Serving at http://localhost:{PORT}')
    httpd.serve_forever()
