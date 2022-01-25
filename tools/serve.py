#!/usr/bin/env python3

from http.server import HTTPServer, SimpleHTTPRequestHandler
import ssl
import os


dir_path = os.path.dirname(os.path.realpath(__file__))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(
            *args,
            **kwargs,
            directory=os.path.join(dir_path, "..", "docs")
        )


httpd = HTTPServer(('0.0.0.0', 4443), Handler)

httpd.socket = ssl.wrap_socket(
    httpd.socket,
    keyfile=os.path.join(dir_path, "key.pem"),
    certfile=os.path.join(dir_path, "cert.pem"),
    server_side=True
)

httpd.serve_forever()
