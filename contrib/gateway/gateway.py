import pathlib
import uvicorn
import subprocess
import json
import uuid

from typing import Any, Dict, AnyStr, List, Union

from fastapi import FastAPI, Request
from fastapi.responses import PlainTextResponse, Response, JSONResponse

app = FastAPI(
    title="Second Sight Gateway",
    version="1.0.0",
    contact={"name": "GitHub", "url": "https://github.com/f5Networks/Secondsight"}
)

JSONObject = Dict[AnyStr, Any]
JSONArray = List[Any]
JSONStructure = Union[JSONArray, JSONObject]

@app.post("/v1/collector", status_code=200, response_class=JSONResponse)
def post_collector(response: Response, request: JSONStructure = None):
    if request:
        try:
            sessionUUID = uuid.uuid4()
            jsonPayload = json.dumps(request)

            print(f"JSON Payload: {jsonPayload}")

            # Payload to upstream endpoint

            return JSONResponse (content={'status': 'success'}, status_code=200)
        except Exception as e:
            return JSONResponse (content={'status': str(e)}, status_code=400)
    else:
        return JSONResponse (content={'status': 'invalid body'}, status_code=400)

if __name__ == '__main__':
    uvicorn.run("gateway:app", host='0.0.0.0', port=5000)
