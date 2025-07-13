from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import easyocr
from PIL import Image, ImageSequence
import numpy as np
import cv2
import io

app = FastAPI()
reader = easyocr.Reader(['en'])

def extract_first_frame_from_gif(gif_bytes):
    img = Image.open(io.BytesIO(gif_bytes))
    frame = next(ImageSequence.Iterator(img)).convert("RGB")
    return np.array(frame)

@app.post("/predict/")
async def predict(file: UploadFile = File(...)):
    contents = await file.read()
    
    try:
        # Convert GIF -> first frame as image
        img = extract_first_frame_from_gif(contents)

        # Convert to grayscale (if needed)
        gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)

        # OCR prediction
        result = reader.readtext(gray, detail=0)
        return {"success": True, "result": result}
    
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})
