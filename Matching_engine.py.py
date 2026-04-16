# ===============================
# INSTALL REQUIRED LIBRARIES
# ===============================
# python -m pip install pandas rapidfuzz openpyxl pdfplumber numpy

import pandas as pd
from rapidfuzz import process, fuzz
import numpy as np
import re
import os
import pdfplumber


def run_matching(original_file, desc_file,
                 original_id_col="", original_desc_col="", target_desc_col=""):
    print("Script started...")

    # ===============================
    # CLEAN TEXT FUNCTION
    # ===============================
    def clean_text(text):
        text = str(text).lower()
        text = re.sub(r'[^a-z0-9\s\-]', '', text)
        text = re.sub(r'\s+', ' ', text)
        return text.strip()

    # ===============================
    # LOAD FILE FUNCTION
    # ===============================
    def load_file(file_path, code_col=None, desc_col=None):
        ext = os.path.splitext(file_path)[1].lower()

        # -------- EXCEL --------
        if ext in [".xlsx", ".xls"]:
            df = pd.read_excel(file_path)

        # -------- CSV --------
        elif ext == ".csv":
            df = pd.read_csv(file_path)

        # -------- PDF --------
        elif ext == ".pdf":
            data = []
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    table = page.extract_table()

                    if table:
                        for row in table[1:]:
                            if row and len(row) >= 2:
                                data.append(row[:2])
                    else:
                        text = page.extract_text()
                        if text:
                            lines = text.split("\n")
                            for line in lines:
                                parts = line.split()
                                if len(parts) >= 2:
                                    data.append([parts[0], " ".join(parts[1:])])

            df = pd.DataFrame(data, columns=["StockCode", "Description"])

        else:
            raise ValueError("Unsupported file type")

        # -------- COLUMN HANDLING --------
        if code_col and desc_col:
            if code_col in df.columns and desc_col in df.columns:
                df = df[[code_col, desc_col]]
                df.columns = ["StockCode", "Description"]
            else:
                print("⚠️ Column names not found, using default columns")
            
            
            
            #df = df[[code_col, desc_col]]
            #df.columns = ["StockCode", "Description"]

        return df

    # ===============================
    # COLUMN NAMES (CAN BE MADE DYNAMIC LATER)
    # ===============================
    
    original_code_col = original_id_col if original_id_col else "StockCode"
    original_desc_column = original_desc_col if original_desc_col else "Description"
    target_desc_column = target_desc_col if target_desc_col else "Description"

    # ===============================
    # LOAD DATA
    # ===============================
    df_original = load_file(original_file, original_code_col, original_desc_column)
    df_desc = load_file(desc_file, None, target_desc_column)

    print("Files loaded")

    # ===============================
    # CLEAN DATA
    # ===============================
    df_original["Description"] = df_original["Description"].apply(clean_text)
    df_desc["Description"] = df_desc["Description"].apply(clean_text)

    print("Text cleaned")

    # ===============================
    # PREPARE MASTER DATA
    # ===============================
    sap_df = df_original[["StockCode", "Description"]].dropna().drop_duplicates()
    sap_df.columns = ["Product_ID", "Description"]

    # ===============================
    # EXACT MATCH
    # ===============================
    result = pd.merge(df_desc, sap_df, on="Description", how="left")

    result["Score"] = np.where(result["Product_ID"].notna(), 100, 0).astype(float)
    result["Confidence"] = np.where(result["Product_ID"].notna(), "EXACT", "PENDING")
    result["Product_ID"] = result["Product_ID"].astype(str)

    print("Exact matching done")

    # ===============================
    # FUZZY MATCH
    # ===============================
    sap_list = sap_df["Description"].tolist()
    missing_rows = result[result["Confidence"] == "PENDING"].copy()

    print(f"Fuzzy matching for {len(missing_rows)} rows...")

    if len(missing_rows) > 0:
        matches = process.cdist(
            missing_rows["Description"],
            sap_list,
            scorer=fuzz.token_sort_ratio,
            workers=-1
        )

        best_idx = np.argmax(matches, axis=1)
        best_scores = np.max(matches, axis=1)

        for i, idx in enumerate(missing_rows.index):
            matched_desc = sap_list[best_idx[i]]
            score = float(best_scores[i])

            product_id = sap_df.loc[
                sap_df["Description"] == matched_desc, "Product_ID"
            ].values[0]

            result.at[idx, "Product_ID"] = str(product_id)
            result.at[idx, "Score"] = score

            if score >= 85:
                result.at[idx, "Confidence"] = "HIGH"
            elif score >= 70:
                result.at[idx, "Confidence"] = "MEDIUM"
            elif fuzz.partial_ratio(missing_rows.loc[idx, "Description"], matched_desc) > 80:
                result.at[idx, "Confidence"] = "PARTIAL"
            else:
                result.at[idx, "Confidence"] = "LOW"

    print("Fuzzy matching done")

    # ===============================
    # FINAL OUTPUT
    # ===============================
    import tempfile
    result.sort_values(by="Score", ascending=False, inplace=True)
        
    temp_dir = tempfile.gettempdir()
    output_file = os.path.join(temp_dir, "Final_Output.xlsx")
    #output_file = "Final_Output.xlsx"

    result.loc[result["Score"] < 60, "Product_ID"] = "No Match"
    
    result.to_excel(output_file, index=False)
    import openpyxl

    wb = openpyxl.load_workbook(output_file)
    ws = wb.active

    for col in ws.columns:
        max_length = 0
        col_letter = col[0].column_letter if col[0].column_letter else col[1].column_letter
        for cell in col:
            if cell.value is not None:
                max_length = max(max_length, len(str(cell.value)))
        ws.column_dimensions[col_letter].width = max_length + 2

    wb.save(output_file)
    print(f"DONE! File saved as {output_file}")

    return output_file