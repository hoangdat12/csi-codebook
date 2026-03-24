

import logging
logging.basicConfig(level=logging.INFO)
from nr_csi_pmi import rel16

# N1N2=(2,1) -> 4 ports
# v=4        -> 4 layers
# N3=16       -> 1 subband
# comb_inx=2 -> L=2 beams
gen_r16 = rel16.PmiGenerator(comb_inx=2, R=1, N3=16, v=4, N1N2=(2, 1))

params = {
    "q1q2": (0, 0),
    "n1n2": ([0, 1], [0, 0]),
    "n3l": [[0], [0], [0], [0]],
    "lifs_strongest": [(1, 0, 0), (2, 1, 0), (3, 2, 0), (4, 3, 0)],
    "lifs_other": [(1, 1, 0), (2, 2, 0)],
    "k1": [1, 1, 1, 1], # Thường tương ứng với số layer (v=4)
    "k2": [1, 2],       # Khớp với số lượng lifs_other
    "c": [1, 2]         # Khớp với số lượng lifs_other
}

try:
    pmi = gen_r16.beam_factory(**params)
    pmi.log_summary()

    print("\n>>> Ma trận Precoding (w) cho subband 0 (4 Ports, 4 Layers):")
    print(pmi.w.for_sb(0))
except Exception as e:
    import traceback
    traceback.print_exc()
    print("\nLỗi:", e)