import os

offset = 25205000
bed_file = "/Users/siyangming/nextflow_nf_core/bio.nf/modules/flair/testdata/test-collapse-annot.isoforms.bed"
gtf_file = "/Users/siyangming/nextflow_nf_core/bio.nf/modules/flair/testdata/basic.annotation.gtf"

# Fix BED
new_bed_lines = []
with open(bed_file, 'r') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) < 3: continue
        if parts[0] != 'chr12':
            continue
        
        # Shift coordinates
        parts[1] = str(int(parts[1]) - offset)
        parts[2] = str(int(parts[2]) - offset)
        parts[6] = str(int(parts[6]) - offset)
        parts[7] = str(int(parts[7]) - offset)
        
        # Fix name (remove _ENSG suffix if present)
        if '_ENSG' in parts[3]:
             parts[3] = parts[3].split('_ENSG')[0]
             
        new_bed_lines.append('\t'.join(parts) + '\n')

with open(bed_file, 'w') as f:
    f.writelines(new_bed_lines)

# Fix GTF
new_gtf_lines = []
with open(gtf_file, 'r') as f:
    for line in f:
        if line.startswith('#'):
            new_gtf_lines.append(line)
            continue
            
        parts = line.strip().split('\t')
        if len(parts) < 5: continue
        if parts[0] != 'chr12':
            continue
            
        # Shift coordinates
        parts[3] = str(int(parts[3]) - offset)
        parts[4] = str(int(parts[4]) - offset)
        
        new_gtf_lines.append('\t'.join(parts) + '\n')

with open(gtf_file, 'w') as f:
    f.writelines(new_gtf_lines)
