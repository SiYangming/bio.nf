import os
import glob

# Configuration
genome_path = '/Users/siyangming/Desktop/flair/test/tmp-input/genome.fa'
input_dir = '/Users/siyangming/Desktop/flair/test/input'
output_dir = 'optimized_test_data'
output_input_dir = os.path.join(output_dir, 'input')

# Regions to keep (1-based inclusive)
# Padding added: 1000bp
regions = {
    'chr12': [(25205246, 25250936)],
    'chr17': [(64498254, 64508199)],
    'chr20': [(32186477, 32190809), (35542021, 35557634)]
}
padding = 1000

# Ensure output directories exist
os.makedirs(output_input_dir, exist_ok=True)

# Helper to read FASTA
def read_fasta(path):
    seqs = {}
    curr_id = None
    curr_seq = []
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                if curr_id:
                    seqs[curr_id] = ''.join(curr_seq)
                curr_id = line[1:].split()[0]
                curr_seq = []
            else:
                curr_seq.append(line)
        if curr_id:
            seqs[curr_id] = ''.join(curr_seq)
    return seqs

print(f"Reading genome from {genome_path}...")
genome = read_fasta(genome_path)

# Prepare mapping for coordinate shifts
# chrom -> interval_idx -> (original_start, original_end, new_start, shift_amount)
coord_map = {} 
new_genome_seqs = {}

for chrom, intervals in regions.items():
    if chrom not in genome:
        print(f"Warning: {chrom} not found in genome.")
        continue
    
    full_seq = genome[chrom]
    new_seq_parts = []
    current_offset = 1
    chrom_map = []
    
    # Sort intervals
    intervals.sort()
    
    for i, (start, end) in enumerate(intervals):
        # Apply padding
        p_start = max(1, start - padding)
        p_end = min(len(full_seq), end + padding)
        
        # Extract sequence (0-based)
        seq_chunk = full_seq[p_start-1 : p_end]
        
        # Gap if not first
        if i > 0:
            new_seq_parts.append('N' * 1000)
            current_offset += 1000
            
        new_seq_parts.append(seq_chunk)
        
        # Record mapping
        # Original: p_start to p_end
        # New: current_offset to current_offset + len(seq_chunk) - 1
        # Shift: new_pos = old_pos - p_start + current_offset
        shift = current_offset - p_start
        chrom_map.append({
            'orig_start': p_start,
            'orig_end': p_end,
            'new_start': current_offset,
            'new_end': current_offset + len(seq_chunk) - 1,
            'shift': shift
        })
        
        current_offset += len(seq_chunk)
    
    new_genome_seqs[chrom] = ''.join(new_seq_parts)
    coord_map[chrom] = chrom_map

# Write new genome
new_genome_path = os.path.join(output_dir, 'genome.fa')
print(f"Writing new genome to {new_genome_path}...")
with open(new_genome_path, 'w') as f:
    for chrom, seq in new_genome_seqs.items():
        f.write(f">{chrom}\n")
        # Write in chunks of 80 chars
        for i in range(0, len(seq), 80):
            f.write(seq[i:i+80] + "\n")

# Function to transform coordinates
def transform_coord(chrom, pos):
    if chrom not in coord_map:
        return None
    for mapping in coord_map[chrom]:
        if mapping['orig_start'] <= pos <= mapping['orig_end']:
            return pos + mapping['shift']
    return None

# Process GTF files
gtf_files = ['basic.annotation.gtf', 'basic.annotation.incomplete.gtf', 'basic.annotation.incomplete.scrambled.gtf', 'parY.annotation.gtf', 'seg1.gencodeV47.gtf']
for fname in gtf_files:
    in_path = os.path.join(input_dir, fname)
    out_path = os.path.join(output_input_dir, fname)
    if not os.path.exists(in_path): continue
    
    print(f"Processing {fname}...")
    with open(in_path, 'r') as fin, open(out_path, 'w') as fout:
        for line in fin:
            if line.startswith('#'):
                fout.write(line)
                continue
            parts = line.strip().split('\t')
            if len(parts) < 9:
                fout.write(line)
                continue
            
            chrom = parts[0]
            start = int(parts[3])
            end = int(parts[4])
            
            new_start = transform_coord(chrom, start)
            new_end = transform_coord(chrom, end)
            
            if new_start is not None and new_end is not None:
                parts[3] = str(new_start)
                parts[4] = str(new_end)
                fout.write('\t'.join(parts) + '\n')
            else:
                # Region removed
                pass

# Process BED files
bed_files = ['basic.promoter_regions.bed', 'seg1.promoter-regions.bed']
for fname in bed_files:
    in_path = os.path.join(input_dir, fname)
    out_path = os.path.join(output_input_dir, fname)
    if not os.path.exists(in_path): continue
    
    print(f"Processing {fname}...")
    with open(in_path, 'r') as fin, open(out_path, 'w') as fout:
        for line in fin:
            if line.startswith('#') or line.startswith('track'):
                fout.write(line)
                continue
            parts = line.strip().split('\t')
            if len(parts) < 3:
                fout.write(line)
                continue
            
            chrom = parts[0]
            start = int(parts[1]) # 0-based
            end = int(parts[2])   # 0-based
            
            # BED is 0-based, GTF logic was 1-based.
            # transform_coord expects 1-based logic? 
            # My mapping logic: p_start (1-based) <= pos (1-based)
            # So for BED start (0-based), I should use start+1 to check, then result -1.
            
            new_start_1 = transform_coord(chrom, start + 1)
            new_end_1 = transform_coord(chrom, end) # end is exclusive in BED? No, end is exclusive, but in 1-based it matches the last base. 
            # Actually, BED start=0, end=100 means bases 0..99. 1-based: 1..100.
            # So transform(start+1) -> new_start_1. new_bed_start = new_start_1 - 1.
            # transform(end) -> new_end_1. new_bed_end = new_end_1. (Since end corresponds to base index end, which is 1-based end).
            
            if new_start_1 is not None:
                # For end, if it's outside, clamp it?
                # If end is exactly at the boundary, transform might fail if logic is inclusive.
                # Let's simple check:
                # new_start = start + shift
                shift = new_start_1 - (start + 1)
                new_start = start + shift
                new_end = end + shift
                
                parts[0] = chrom
                parts[1] = str(new_start)
                parts[2] = str(new_end)
                fout.write('\t'.join(parts) + '\n')

# Process TAB file (basic.shortread_junctions.tab)
fname = 'basic.shortread_junctions.tab'
in_path = os.path.join(input_dir, fname)
out_path = os.path.join(output_input_dir, fname)
if os.path.exists(in_path):
    print(f"Processing {fname}...")
    with open(in_path, 'r') as fin, open(out_path, 'w') as fout:
        for line in fin:
            parts = line.strip().split('\t')
            if len(parts) < 3:
                fout.write(line)
                continue
            
            chrom = parts[0]
            try:
                start = int(parts[1])
                end = int(parts[2])
                
                # TAB seems 0-based or 1-based?
                # Looking at data: 25209912.
                # Assuming 1-based for now (like GTF).
                new_start = transform_coord(chrom, start)
                new_end = transform_coord(chrom, end)
                
                if new_start is not None and new_end is not None:
                    parts[1] = str(new_start)
                    parts[2] = str(new_end)
                    fout.write('\t'.join(parts) + '\n')
            except ValueError:
                fout.write(line)

print("Done. Files created in optimized_test_data/")
