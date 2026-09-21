# in /srv/mcore-pysandbox-template/scripts/, add:
cat > state-server.py <<'PY'
from http.server import HTTPServer, SimpleHTTPRequestHandler
import json, pathlib
TPL = pathlib.Path('/srv/mcore-pysandbox-template')

class H(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/state':
            data = {
                'ports':   json.loads((TPL/'ports.json').read_text()),
                'bridges': json.loads((TPL/'bridges.json').read_text()),
                'version': (TPL/'VERSION').read_text()
            }
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
            return
        super().do_GET()

HTTPServer(('127.0.0.1', 8090), H).serve_forever()
PY