import urllib.request
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
url = 'https://services.gradle.org/distributions/gradle-8.14-all.zip'
dest = r'C:\Users\gianvito.bleve\.gradle\wrapper\dists\gradle-8.14-all\c2qonpi39x1mddn7hk5gh9iqj\gradle-8.14-all.zip'

with urllib.request.urlopen(url, context=ctx) as r:
    with open(dest, 'wb') as f:
        f.write(r.read())
