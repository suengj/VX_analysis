#!/usr/bin/env python3
"""
Large file processing script for data folder.
Splits files larger than 25MB into smaller chunks or compresses them.
"""

import os
import pandas as pd
import zipfile
from pathlib import Path

def get_file_size_mb(filepath):
    """Get file size in MB"""
    size_bytes = os.path.getsize(filepath)
    size_mb = size_bytes / (1024 * 1024)
    return size_mb

def process_large_file(filepath, output_dir, max_size_mb=25):
    """
    Process large files:
    - Try zip compression first
    - If still too large, split into chunks
    """
    filepath = Path(filepath)
    output_dir = Path(output_dir)
    
    size_mb = get_file_size_mb(filepath)
    print(f"Processing {filepath.name}: {size_mb:.2f}MB")
    
    if size_mb <= max_size_mb:
        # File is small enough, just copy
        print(f"  -> File is already {size_mb:.2f}MB, copying to resized folder")
        output_path = output_dir / filepath.name
        import shutil
        shutil.copy2(filepath, output_path)
        return output_path
    
    # Try zip compression first
    zip_path = output_dir / f"{filepath.name}.zip"
    print(f"  -> Compressing to {zip_path.name}...")
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        zf.write(filepath, filepath.name)
    
    zip_size_mb = get_file_size_mb(zip_path)
    print(f"  -> Compressed size: {zip_size_mb:.2f}MB")
    
    if zip_size_mb <= max_size_mb:
        # Compression worked, use zip file
        print(f"  -> Compression successful! Using {zip_path.name}")
        return zip_path
    else:
        # Still too large, need to split
        print(f"  -> Still too large after compression, splitting into chunks...")
        return split_csv_file(filepath, output_dir, max_size_mb)

def split_csv_file(filepath, output_dir, max_size_mb=25):
    """
    Split CSV file into chunks based on row count estimation.
    """
    # Read CSV to get total rows
    print(f"  -> Reading CSV to count rows...")
    df = pd.read_csv(filepath, nrows=0)  # Just read header
    total_rows = sum(1 for _ in open(filepath)) - 1  # -1 for header
    
    # Estimate rows per file (assuming linear relationship)
    original_size_mb = get_file_size_mb(filepath)
    rows_per_mb = total_rows / original_size_mb
    target_rows_per_file = int(rows_per_mb * max_size_mb * 0.9)  # 90% to be safe
    
    # Calculate number of chunks needed
    num_chunks = (total_rows // target_rows_per_file) + 1
    
    print(f"  -> Total rows: {total_rows:,}")
    print(f"  -> Target rows per file: {target_rows_per_file:,}")
    print(f"  -> Splitting into {num_chunks} chunks...")
    
    # Split the file
    chunk_files = []
    chunk_size = target_rows_per_file
    
    with open(filepath, 'r', encoding='utf-8') as f:
        header = f.readline()  # Read header
        
        chunk_num = 1
        current_chunk_rows = 0
        current_chunk_path = output_dir / f"{filepath.stem}_part{chunk_num:03d}.csv"
        current_chunk_file = open(current_chunk_path, 'w', encoding='utf-8')
        current_chunk_file.write(header)  # Write header
        chunk_files.append(current_chunk_path)
        
        for line in f:
            current_chunk_file.write(line)
            current_chunk_rows += 1
            
            if current_chunk_rows >= chunk_size:
                current_chunk_file.close()
                chunk_size_mb = get_file_size_mb(current_chunk_path)
                print(f"    Created {current_chunk_path.name}: {chunk_size_mb:.2f}MB ({current_chunk_rows:,} rows)")
                
                chunk_num += 1
                current_chunk_rows = 0
                current_chunk_path = output_dir / f"{filepath.stem}_part{chunk_num:03d}.csv"
                current_chunk_file = open(current_chunk_path, 'w', encoding='utf-8')
                current_chunk_file.write(header)  # Write header
                chunk_files.append(current_chunk_path)
        
        # Close last chunk
        if current_chunk_file and not current_chunk_file.closed:
            current_chunk_file.close()
            chunk_size_mb = get_file_size_mb(current_chunk_path)
            print(f"    Created {current_chunk_path.name}: {chunk_size_mb:.2f}MB ({current_chunk_rows:,} rows)")
    
    print(f"  -> Split into {len(chunk_files)} files")
    return chunk_files

def main():
    data_dir = Path("/Users/suengj/Documents/Code/Python/Research/VC/data")
    output_dir = data_dir / "resized"
    output_dir.mkdir(exist_ok=True)
    
    max_size_mb = 25
    
    # Process all files in data directory
    csv_files = list(data_dir.glob("*.csv"))
    xlsx_files = list(data_dir.glob("*.xlsx"))
    all_files = csv_files + xlsx_files
    
    # Exclude zip files and .DS_Store
    files_to_process = [f for f in all_files if not f.name.endswith('.zip') and f.name != '.DS_Store']
    
    print(f"Processing {len(files_to_process)} files...")
    print(f"Output directory: {output_dir}")
    print(f"Max file size: {max_size_mb}MB")
    print("-" * 60)
    
    for filepath in files_to_process:
        try:
            result = process_large_file(filepath, output_dir, max_size_mb)
            if isinstance(result, list):
                print(f"  ✓ Split into {len(result)} files")
            else:
                print(f"  ✓ Processed: {result.name}")
        except Exception as e:
            print(f"  ✗ Error processing {filepath.name}: {e}")
        print()
    
    print("-" * 60)
    print("Processing complete!")

if __name__ == "__main__":
    main()





