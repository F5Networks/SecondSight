import uvicorn
import json
import uuid
import requests

from typing import Any, Dict, AnyStr, List, Union

from fastapi import FastAPI, Request, File, UploadFile
from fastapi.responses import PlainTextResponse, Response, JSONResponse

app = FastAPI(
    title="Second Sight Gateway",
    version="1.0.0",
    contact={"name": "GitHub", "url": "https://github.com/f5Networks/Secondsight"}
)

JSONObject = Dict[AnyStr, Any]
JSONArray = List[Any]
JSONStructure = Union[JSONArray, JSONObject]


#
# Payload is the BIG-IQ tarball
# curl 127.0.0.1:5000/api/v1/archive -X POST -F "file=@/path/filename.ext"
#
@app.post("/api/v1/archive", status_code=200, response_class=JSONResponse)
async def v1_post_archive(file: UploadFile = File(...)):
    # Reset the file pointer to the beginning
    file.file.seek(0)

    # Endpoint
    endpoint = 'https://192.168.2.19:443/upload'

    # mTLS authentication
    #mTLS_cert = ('/path/client.crt', '/path/client.key')

    multipart_form_data = {
        'tarball': ('tarball.zip', file.file)
    }

    # Publish to F5 telemetry endpoint
    r = requests.post(url = endpoint,
                      files = multipart_form_data,
                      auth = ('admin','default'),
                      verify = False,
                      #cert = mTLS_cert
                      )

    print(f"Response HTTP status: {r.status_code}")
    print(f"Response Body       : {r.content.decode('utf-8')}")

    output = json.loads(r.content.decode('utf-8'))
    output['filename'] = file.filename

    return output

if __name__ == '__main__':
    uvicorn.run("gateway:app", host='0.0.0.0', port=5000)
