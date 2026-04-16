from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import FileResponse
import shutil
import os

from forapp import run_matching  # your matching function

app = FastAPI()

# -------------------------------
# HOME ROUTE (TEST)
# -------------------------------
@app.get("/")
def home():
    return {"message": "API is working"}

# -------------------------------
# MATCH FILES ROUTE
# -------------------------------
@app.post("/match-files/")
async def match_files(
    original: UploadFile = File(...),
    target: UploadFile = File(...),
    original_id_col: str = Form(""),
    original_desc_col: str = Form(""),
    target_desc_col: str = Form("")
):
    # Create temporary file paths
    #original_path = f"temp_{original.filename}"
    #target_path = f"temp_{target.filename}"

    import tempfile

    temp_dir = tempfile.gettempdir()

    original_path = os.path.join(temp_dir, f"temp_{original.filename}")
    target_path = os.path.join(temp_dir, f"temp_{target.filename}")

    try:
        # Save uploaded files
        contents = await original.read()
        with open(original_path, "wb") as f:
            f.write(contents)

        contents = await target.read()
        with open(target_path, "wb") as f:
            f.write(contents)

        print("Files received and saved")

        # Run matching logic
        output_file = run_matching(
            original_path,
            target_path,
            original_id_col,
            original_desc_col,
            target_desc_col
        )

        print("Matching completed")

        # Return result file
        #return FileResponse(
         #   path=output_file,
          #  filename="Matched_Result.xlsx",
           # media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        #)
        from fastapi.responses import StreamingResponse

        return StreamingResponse(
            open(output_file, "rb"),
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": "attachment; filename=Matched_Result.xlsx"
            }
        )   
    except Exception as e:
        return {"error": str(e)}

    finally:
        # Optional: cleanup temp files
        if os.path.exists(original_path):
            os.remove(original_path)
        if os.path.exists(target_path):
            os.remove(target_path)

import uvicorn

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_config=None)