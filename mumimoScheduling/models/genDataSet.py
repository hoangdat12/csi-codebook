import numpy as np
import pandas as pd
import os
import signal
from datetime import datetime

# =========================================================================
# CẤU HÌNH
# =========================================================================
CONFIG = {
    'codebook_files': {
        1: 'Layer1_Port32_N1_4_N2-4_c1.txt',
        2: 'Layer2_Port32_N1_4_N2-4_c1.txt',
        3: 'Layer3_Port32_N1_4_N2-4_c1.txt',
        4: 'Layer4_Port32_N1_4_N2-4_c1.txt',
    },
    'n_port'        : 32,
    'max_total_rank': 8,            # RI_1 + RI_2 <= 7
    'cqi_min'       : 1,
    'cqi_max'       : 15,
    'cqi_max_delta' : 4,            # |CQI_1 - CQI_2| <= 4
    'max_samples'   : 10_000_000,   # giới hạn tổng số dòng
    'output_csv'    : 'mu_mimo_dataset.csv',
    'save_interval' : 1000,         # ghi file mỗi N samples hợp lệ
    'log_interval'  : 200,          # in log mỗi N samples hợp lệ
}

# =========================================================================
# CQI TABLE 2 — 3GPP TS 38.214 Table 5.2.2.1-3
# Spectral efficiency (bits/s/Hz per layer)
# SINR nominal = 2^efficiency - 1  (Shannon inverse)
# =========================================================================
CQI_EFFICIENCY = {
     1:  0.1523,
     2:  0.3770,
     3:  0.8770,
     4:  1.4766,
     5:  1.9141,
     6:  2.4063,
     7:  2.7305,
     8:  3.3223,
     9:  3.9023,
    10:  4.5234,
    11:  5.1152,
    12:  5.5547,
    13:  6.2266,
    14:  6.9141,
    15:  7.4063,
}

# Precompute SINR linear: SINR = 2^eff - 1
CQI_TO_SINR_LINEAR = {
    cqi: (2.0 ** eff - 1.0)
    for cqi, eff in CQI_EFFICIENCY.items()
}

# =========================================================================
# GIAI ĐOẠN 1: NẠP CODEBOOK
# =========================================================================
def load_codebook(filename, n_port, n_layers):
    print(f'  Loading: {filename} ...')
    pool = []
    with open(filename, 'r') as f:
        while True:
            info_line = f.readline()
            if not info_line:
                break
            if not info_line.strip():
                continue
            W = np.zeros((n_port, n_layers), dtype=np.complex128)
            for r in range(n_port):
                row = f.readline().strip().replace('i', 'j')
                W[r, :] = [complex(x) for x in row.split()]
            pool.append(W)
    print(f'    → Loaded {len(pool)} matrices (shape {n_port}x{n_layers})')
    return pool


def load_all_codebooks(config):
    print('\n[Giai đoạn 1] Nạp codebook vào bộ nhớ...')
    codebook_dict = {}
    for n_layers, filepath in config['codebook_files'].items():
        if not os.path.exists(filepath):
            raise FileNotFoundError(f'Không tìm thấy file: {filepath}')
        codebook_dict[n_layers] = load_codebook(filepath, config['n_port'], n_layers)
    print(f'  Hoàn thành. Các ngăn kéo: { {k: len(v) for k, v in codebook_dict.items()} }')
    return codebook_dict


# =========================================================================
# GIAI ĐOẠN 3: TÍNH LABEL
# =========================================================================
def chordal_distance(W1, W2):
    """Grassmannian chordal distance chuẩn, dùng QR + SVD."""
    Q1, _ = np.linalg.qr(W1)
    Q2, _ = np.linalg.qr(W2)
    L  = min(W1.shape[1], W2.shape[1])
    R  = Q1.conj().T @ Q2
    sv = np.linalg.svd(R, compute_uv=False)
    sv = np.clip(sv.real, 0.0, 1.0)
    dist = np.sqrt(max(L - np.sum(sv ** 2), 0.0))
    return float(dist / np.sqrt(L))


def compute_sumrate(W1, ri1, cqi1, W2, ri2, cqi2):
    """
    Tính SumRate_MU và SumRate_SU dựa trên CQI Table 2.

    SINR_nominal_k = 2^eff_k - 1  (Shannon inverse từ spectral efficiency)

    Sau khi có chordal distance cd:
      interference_factor = 1 - cd
        → 0  khi trực giao hoàn toàn (cd=1): không IUI
        → 1  khi cùng hướng hoàn toàn (cd=0): IUI tối đa

      IUI trên UE1 từ UE2: iui_on_ue1 = interference_factor * ri2 * sinr_nom2
      SINR_MU_1 = (ri1 * sinr_nom1) / (iui_on_ue1 + 1)

    SumRate_MU = ri1*log2(1+SINR_MU_1) + ri2*log2(1+SINR_MU_2)
    SumRate_SU = ri1*log2(1+ri1*sinr_nom1) + ri2*log2(1+ri2*sinr_nom2)
    Gain       = SumRate_MU / SumRate_SU
    """
    sinr_nom1 = CQI_TO_SINR_LINEAR[cqi1]
    sinr_nom2 = CQI_TO_SINR_LINEAR[cqi2]

    cd = chordal_distance(W1, W2)

    interference_factor = 1.0 - cd
    iui_on_ue1 = interference_factor * ri2 * sinr_nom2
    iui_on_ue2 = interference_factor * ri1 * sinr_nom1

    sinr_mu1 = (ri1 * sinr_nom1) / (iui_on_ue1 + 1.0)
    sinr_mu2 = (ri2 * sinr_nom2) / (iui_on_ue2 + 1.0)

    sumrate_mu = ri1 * np.log2(1.0 + sinr_mu1) + ri2 * np.log2(1.0 + sinr_mu2)
    sumrate_su = ri1 * np.log2(1.0 + ri1 * sinr_nom1) + ri2 * np.log2(1.0 + ri2 * sinr_nom2)

    gain = sumrate_mu / sumrate_su if sumrate_su > 0.0 else 0.0

    return cd, sinr_mu1, sinr_mu2, sumrate_mu, sumrate_su, gain


# =========================================================================
# VÒNG LẶP CHÍNH
# =========================================================================
def generate_dataset(config):
    codebook_dict    = load_all_codebooks(config)
    available_layers = sorted(codebook_dict.keys())
    max_rank         = config['max_total_rank']
    max_samples      = config['max_samples']
    cqi_max_delta    = config['cqi_max_delta']
    cqi_range        = list(range(config['cqi_min'], config['cqi_max'] + 1))

    # Tất cả cặp (RI_1, RI_2) hợp lệ
    valid_ri_pairs = [
        (r1, r2)
        for r1 in available_layers
        for r2 in available_layers
        if r1 + r2 <= max_rank
    ]

    print(f'\n  Layers hỗ trợ     : {available_layers}')
    print(f'  Các cặp RI hợp lệ : {valid_ri_pairs}')
    print(f'  CQI range         : {cqi_range[0]} – {cqi_range[-1]}  (Table 2, Shannon inverse)')
    print(f'  CQI max delta     : ±{cqi_max_delta}')
    print(f'  Giới hạn samples  : {max_samples:,}')

    output_csv = config['output_csv']
    columns = [
        'PMI_1', 'RI_1', 'CQI_1',
        'PMI_2', 'RI_2', 'CQI_2',
        'Chordal_Distance',
        'SINR_MU_1', 'SINR_MU_2',
        'SumRate_MU', 'SumRate_SU', 'Gain',
    ]

    file_exists = os.path.exists(output_csv)
    buffer      = []
    total_saved = 0

    if file_exists:
        # Đọc nhanh chỉ 1 cột để đếm số dòng
        existing    = pd.read_csv(output_csv, usecols=[0])
        total_saved = len(existing)
        print(f'\n  File CSV đã có {total_saved:,} samples → tiếp tục append.')
        if total_saved >= max_samples:
            print(f'  ✅ Đã đủ {max_samples:,} samples. Không cần sinh thêm.')
            return
    else:
        print(f'\n  Tạo file CSV mới: {output_csv}')

    # Graceful shutdown khi Ctrl+C
    running = [True]
    def handle_sigint(sig, frame):
        print('\n\n[Dừng] Ctrl+C nhận được. Đang lưu buffer còn lại...')
        running[0] = False
    signal.signal(signal.SIGINT, handle_sigint)

    print(f'\n[Giai đoạn 2-4] Bắt đầu sinh dataset. Nhấn Ctrl+C để dừng sớm.\n')
    hdr = (f'{"Total":>11} | {"R1":>2} {"R2":>2} | {"Q1":>2} {"Q2":>2} | '
           f'{"Chordal":>7} | {"SumMU":>8} | {"Gain":>6} | {"Rej%":>5} | {"Done%":>5}')
    print(hdr)
    print('-' * len(hdr))

    sample_count   = 0
    total_attempts = 0
    rejected       = 0

    while running[0]:
        if total_saved + sample_count >= max_samples:
            print(f'\n  ✅ Đã đạt giới hạn {max_samples:,} samples. Dừng sinh.')
            break

        total_attempts += 1

        # ── Sampling ──────────────────────────────────────────────────────
        ri1, ri2 = valid_ri_pairs[np.random.randint(len(valid_ri_pairs))]

        pool1    = codebook_dict[ri1]
        pool2    = codebook_dict[ri2]
        pmi1_idx = np.random.randint(len(pool1))
        pmi2_idx = np.random.randint(len(pool2))
        W1       = pool1[pmi1_idx]
        W2       = pool2[pmi2_idx]

        cqi1 = cqi_range[np.random.randint(len(cqi_range))]
        cqi2 = cqi_range[np.random.randint(len(cqi_range))]

        # Lọc CQI delta
        if abs(cqi1 - cqi2) > cqi_max_delta:
            rejected += 1
            continue

        # ── Tính label ────────────────────────────────────────────────────
        cd, sinr_mu1, sinr_mu2, sumrate_mu, sumrate_su, gain = compute_sumrate(
            W1, ri1, cqi1, W2, ri2, cqi2
        )

        # ── Đóng gói ──────────────────────────────────────────────────────
        buffer.append({
            'PMI_1'           : pmi1_idx + 1,   # 1-indexed, đồng bộ MATLAB
            'RI_1'            : ri1,
            'CQI_1'           : cqi1,
            'PMI_2'           : pmi2_idx + 1,
            'RI_2'            : ri2,
            'CQI_2'           : cqi2,
            'Chordal_Distance': round(cd,         6),
            'SINR_MU_1'       : round(sinr_mu1,   4),
            'SINR_MU_2'       : round(sinr_mu2,   4),
            'SumRate_MU'      : round(sumrate_mu,  4),
            'SumRate_SU'      : round(sumrate_su,  4),
            'Gain'            : round(gain,         4),
        })

        sample_count += 1

        # Log
        if sample_count % config['log_interval'] == 0:
            rej_pct  = rejected / total_attempts * 100
            done_pct = (total_saved + sample_count) / max_samples * 100
            print(f'{total_saved + sample_count:>11,} | {ri1:>2} {ri2:>2} | '
                  f'{cqi1:>2} {cqi2:>2} | '
                  f'{cd:>7.4f} | {sumrate_mu:>8.4f} | {gain:>6.4f} | '
                  f'{rej_pct:>4.1f}% | {done_pct:>4.1f}%')

        # Ghi CSV định kỳ
        if sample_count % config['save_interval'] == 0:
            _flush_buffer(buffer, output_csv, columns, file_exists or total_saved > 0)
            total_saved += len(buffer)
            buffer.clear()
            file_exists = True

    # Lưu phần còn lại khi thoát
    if buffer:
        _flush_buffer(buffer, output_csv, columns, file_exists or total_saved > 0)
        total_saved += len(buffer)

    rej_rate = rejected / total_attempts * 100 if total_attempts > 0 else 0.0
    print(f'\n{"=" * 56}')
    print(f'  ✅ Hoàn thành!')
    print(f'     Tổng samples đã lưu  : {total_saved:,} / {max_samples:,}')
    print(f'     Tổng lần thử          : {total_attempts:,}')
    print(f'     Rejected (CQI delta)  : {rejected:,}  ({rej_rate:.1f}%)')
    print(f'     File                  : {output_csv}')
    print(f'{"=" * 56}')


def _flush_buffer(buffer, filepath, columns, append):
    df     = pd.DataFrame(buffer, columns=columns)
    mode   = 'a' if append else 'w'
    header = not append
    df.to_csv(filepath, mode=mode, header=header, index=False)


# =========================================================================
# ENTRY POINT
# =========================================================================
if __name__ == '__main__':
    np.random.seed()   # seed ngẫu nhiên thật sự mỗi lần chạy
    generate_dataset(CONFIG)