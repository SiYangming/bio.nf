import os
import glob
import pandas as pd

def parse_gtf(file):
    ranges = []
    try:
        with open(file, 'r') as f:
            for line in f:
                if line.startswith('#'): continue
                parts = line.strip().split('\t')
                if len(parts) < 5: continue
                ranges.append({'chr': parts[0], 'start': int(parts[3]), 'end': int(parts[4])})
    except Exception as e:
        print(f"Error parsing {file}: {e}")
    return ranges

def parse_bed(file):
    ranges = []
    try:
        with open(file, 'r') as f:
            for line in f:
                if line.startswith('#') or line.startswith('track') or line.startswith('browser'): continue
                parts = line.strip().split('\t')
                if len(parts) < 3: continue
                try:
                    ranges.append({'chr': parts[0], 'start': int(parts[1]) + 1, 'end': int(parts[2])}) # BED is 0-based
                except ValueError:
                    continue
    except Exception as e:
        print(f"Error parsing {file}: {e}")
    return ranges

def parse_sam(file):
    ranges = []
    try:
        with open(file, 'r') as f:
            for line in f:
                if line.startswith('@'): continue
                parts = line.strip().split('\t')
                if len(parts) < 4: continue
                chrom = parts[2]
                if chrom == '*': continue
                start = int(parts[3])
                # Estimate end based on seq length if available, else just start+100
                seq = parts[9]
                length = len(seq) if seq != '*' else 100
                ranges.append({'chr': chrom, 'start': start, 'end': start + length})
    except Exception as e:
        print(f"Error parsing {file}: {e}")
    return ranges

def parse_tab(file):
    ranges = []
    try:
        with open(file, 'r') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) < 3: continue
                # Assuming chr, start, end
                try:
                    ranges.append({'chr': parts[0], 'start': int(parts[1]), 'end': int(parts[2])})
                except ValueError:
                    continue
    except Exception as e:
        print(f"Error parsing {file}: {e}")
    return ranges

input_dir = '/Users/siyangming/Desktop/flair/test/input'
all_ranges = []

# GTF
for f in glob.glob(os.path.join(input_dir, '*.gtf')):
    all_ranges.extend(parse_gtf(f))

# BED
for f in glob.glob(os.path.join(input_dir, '*.bed')):
    all_ranges.extend(parse_bed(f))

# SAM
for f in glob.glob(os.path.join(input_dir, '*.sam')):
    all_ranges.extend(parse_sam(f))

# TAB (junctions)
for f in glob.glob(os.path.join(input_dir, '*.tab')):
    all_ranges.extend(parse_tab(f))

df = pd.DataFrame(all_ranges)

if not df.empty:
    # Group by chromosome and merge overlapping intervals
    summary = []
    for chrom, group in df.groupby('chr'):
        group = group.sort_values('start')
        merged = []
        if group.empty: continue
        
        curr_start = group.iloc[0]['start']
        curr_end = group.iloc[0]['end']
        
        for _, row in group.iterrows():
            if row['start'] < curr_end + 5000: # Allow 5kb gap merging
                curr_end = max(curr_end, row['end'])
            else:
                merged.append((curr_start, curr_end))
                curr_start = row['start']
                curr_end = row['end']
        merged.append((curr_start, curr_end))
        
        for start, end in merged:
            summary.append({'chr': chrom, 'start': start, 'end': end, 'length': end - start})

    summary_df = pd.DataFrame(summary)
    print(summary_df)
else:
    print("No ranges found.")
