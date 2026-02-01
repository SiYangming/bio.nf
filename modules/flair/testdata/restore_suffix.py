bed_file ="./modules/flair/testdata/test-collapse-annot.isoforms.bed"
suffix = "_ENSG00000133703.12"

lines = []
with open(bed_file, 'r') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) < 4: continue
        # Only append if not already there
        if '_' not in parts[3]:
            parts[3] = parts[3] + suffix
        lines.append('\t'.join(parts) + '\n')

with open(bed_file, 'w') as f:
    f.writelines(lines)
