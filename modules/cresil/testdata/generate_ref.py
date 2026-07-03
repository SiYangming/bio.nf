import random
import os

random.seed(42)

output_dir = "/Users/siyangming/nextflow_nf_core/bio.nf/modules/cresil/testdata"
os.makedirs(output_dir, exist_ok=True)

def generate_random_sequence(length, gc_content=0.4):
    bases = ['A', 'T', 'G', 'C']
    weights = [
        (1 - gc_content) / 2,
        (1 - gc_content) / 2,
        gc_content / 2,
        gc_content / 2
    ]
    return ''.join(random.choices(bases, weights=weights, k=length))

def generate_repeat_sequence(unit, copies):
    return unit * copies

chr1_parts = []

chr1_parts.append(generate_random_sequence(5000))

repeat_unit_1 = "ATCGATCG"
chr1_parts.append(generate_repeat_sequence(repeat_unit_1, 250))

chr1_parts.append(generate_random_sequence(10000))

repeat_unit_2 = "CGGCGGCGG"
chr1_parts.append(generate_repeat_sequence(repeat_unit_2, 300))

chr1_parts.append(generate_random_sequence(8000))

tandem_repeat = "TTAGGG"
chr1_parts.append(generate_repeat_sequence(tandem_repeat, 400))

chr1_parts.append(generate_random_sequence(7000))

alu_like = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAAATTAGCCGGGCGTGGTGGCGGGCGCCTGTAGTCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATGGCGTGAACCCGGGAGGCGGAGCTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCAACAGAGCGAGACTCCGTCTCAAAAAAAAAAAAAAAAAAAAA"
for _ in range(5):
    chr1_parts.append(alu_like)
    chr1_parts.append(generate_random_sequence(1000))

chr1_parts.append(generate_random_sequence(5000))

chr1_seq = ''.join(chr1_parts)

total_length = len(chr1_seq)
print(f"Chromosome 1 length: {total_length} bp")

with open(os.path.join(output_dir, "ref.fa"), "w") as f:
    f.write(f">chr1\n")
    for i in range(0, len(chr1_seq), 80):
        f.write(chr1_seq[i:i+80] + "\n")

print(f"ref.fa written to {output_dir}")
print(f"Total genome size: {total_length} bp ({total_length/1000:.1f} kb)")
