"""
step1_gen_dataset.py
====================
Tạo dataset cân bằng cho Siamese MU-MIMO.
Output: DeepSets_TrainData.npz

Chạy:
    python step1_gen_dataset.py
"""

import numpy as np
import time
from pathlib import Path

# ══════════════════════════════════════════════════════════════
# CẤU HÌNH — chỉnh ở đây
# ══════════════════════════════════════════════════════════════
FILENAME   = "Layer4_Port32_N1_4_N2-4_c1.txt"
N_LAYERS   = 4
N1, N2     = 4, 4
N_PORT     = 2 * N1 * N2        # 32

N_SAMPLES  = 10_000             # số TTI muốn sinh
K_WAITING  = 10                 # số UE mỗi TTI
THRESHOLD  = 0.9999             # ngưỡng chordal distance
MAX_RETRY  = 20                 # retry khi 8 UE random bị conflict

SAVE_PATH  = "DeepSets_TrainData.npz"


# ══════════════════════════════════════════════════════════════
# HÀM ĐỌC CODEBOOK
# ══════════════════════════════════════════════════════════════
def read_codebook(filename, n_port, n_layers):
    filepath = Path(filename)
    if not filepath.exists():
        raise FileNotFoundError(f"Không tìm thấy: {filename}")

    W_list = []
    with open(filepath, 'r') as f:
        lines = [l.rstrip('\n') for l in f.readlines()]

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        # info_line (header PMI)
        W_temp = np.zeros((n_port, n_layers), dtype=np.complex128)
        i += 1
        for row in range(n_port):
            if i >= len(lines):
                break
            row_data = lines[i].strip()
            i += 1
            if not row_data:
                continue
            tokens = row_data.split()
            vals = []
            for t in tokens:
                try:
                    vals.append(complex(t.replace('i', 'j').replace('I', 'j')))
                except ValueError:
                    pass
            if len(vals) == n_layers:
                W_temp[row, :] = vals
        W_list.append(W_temp)

    return np.stack(W_list, axis=0)   # (N_PMI, n_port, n_layers)


# ══════════════════════════════════════════════════════════════
# HÀM TÍNH CHORDAL DISTANCE (Đồng bộ MATLAB - Frobenius Norm)
# ══════════════════════════════════════════════════════════════
def chordal_distance_matrix(W_pool):
    """
    Tính toàn bộ distance matrix dựa trên chuẩn Frobenius (đồng bộ với MATLAB).
    W_pool: (N, n_port, n_layers) complex
    Returns: dist_mat (N, N) float32
    """
    N, n_port, n_layers = W_pool.shape

    # 1 & 3. Tính chuẩn Frobenius bình phương cho tất cả PMI
    norms2 = np.sum(np.abs(W_pool)**2, axis=(1, 2)) + 1e-12

    # Chuẩn hóa W_pool trước bằng năng lượng của nó
    W_norm = W_pool / np.sqrt(norms2)[:, np.newaxis, np.newaxis]

    dist_mat = np.zeros((N, N), dtype=np.float32)

    for i in range(N - 1):
        # 2. Tính ma trận tương quan chéo R = W_i' * W_j (nhân hàng loạt cho tất cả j > i)
        R_batch = np.matmul(W_norm[i].conj().T, W_norm[i+1:])  # (Batch, n_layers, n_layers)

        # Tính normR2 = norm(R, 'fro')^2 cho toàn bộ batch
        normR2_batch = np.sum(np.abs(R_batch)**2, axis=(1, 2))

        # 4. Tính correlation có nhân thêm NumLayers
        corr_batch = n_layers * normR2_batch

        # Ngăn chặn sai số phẩy động
        corr_batch = np.clip(corr_batch, a_min=None, a_max=1.0)

        # 5. Trả về khoảng cách Orthogonality Score
        dist_batch = 1.0 - corr_batch

        # Cập nhật vào ma trận đối xứng
        dist_mat[i, i+1:] = dist_batch
        dist_mat[i+1:, i] = dist_batch

    return dist_mat


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
def main():
    # ── Bước 1: Đọc codebook ──────────────────────────────────
    print("=" * 55)
    print("BƯỚC 1: ĐỌC CODEBOOK")
    print("=" * 55)
    W_pool    = read_codebook(FILENAME, N_PORT, N_LAYERS)
    pmi_count = W_pool.shape[0]
    print(f"=> Loaded {pmi_count} PMI | shape: {W_pool.shape}\n")

    # ── Bước 2: Precompute distance matrix ────────────────────
    print("=" * 55)
    print("BƯỚC 2: PRECOMPUTE DISTANCE MATRIX")
    print("=" * 55)
    total_pairs = pmi_count * (pmi_count - 1) // 2
    print(f"Tổng cặp cần tính: {total_pairs:,}")

    t0       = time.time()
    dist_mat = chordal_distance_matrix(W_pool)
    t_pre    = time.time() - t0

    # Lấy valid pairs
    i_idx, j_idx = np.triu_indices(pmi_count, k=1)
    dists_flat   = dist_mat[i_idx, j_idx]
    valid_mask   = dists_flat >= THRESHOLD

    valid_i = i_idx[valid_mask].astype(np.uint16)
    valid_j = j_idx[valid_mask].astype(np.uint16)
    valid_d = dists_flat[valid_mask]
    n_valid = int(valid_mask.sum())

    pmi_valid_count = np.zeros(pmi_count, dtype=np.int32)
    np.add.at(pmi_valid_count, valid_i, 1)
    np.add.at(pmi_valid_count, valid_j, 1)

    print(f"\n{'─'*40}")
    print(f"Cặp hợp lệ  : {n_valid:,} / {total_pairs:,}  ({100*n_valid/total_pairs:.2f}%)")
    print(f"Thời gian   : {t_pre:.1f} giây")
    print(f"PMI active  : {(pmi_valid_count > 0).sum()} / {pmi_count}")
    print(f"{'─'*40}\n")

    if n_valid == 0:
        raise ValueError(f"Không có cặp nào đạt ngưỡng {THRESHOLD}! Giảm THRESHOLD.")

    # ── Bước 3: Build lookup table ────────────────────────────
    print("=" * 55)
    print("BƯỚC 3: BUILD LOOKUP TABLE")
    print("=" * 55)
    active_pmis  = np.where(pmi_valid_count > 0)[0]
    n_active     = len(active_pmis)

    pmi_to_pairs = [[] for _ in range(pmi_count)]
    for k in range(n_valid):
        pmi_to_pairs[valid_i[k]].append(k)
        pmi_to_pairs[valid_j[k]].append(k)
    pmi_to_pairs = [np.array(lst, dtype=np.int32) for lst in pmi_to_pairs]
    print(f"=> {n_active} PMI active\n")

    # ── Bước 4: Precompute feature vectors ────────────────────
    print("=" * 55)
    print("BƯỚC 4: PRECOMPUTE FEATURE VECTORS")
    print("=" * 55)
    F_features = N_PORT * N_LAYERS * 2   # 256

    X_pmi = np.zeros((pmi_count, F_features), dtype=np.float32)
    for i in range(pmi_count):
        W_flat   = W_pool[i].flatten()
        X_pmi[i] = np.concatenate([W_flat.real, W_flat.imag])
    print(f"=> Feature matrix: {X_pmi.shape}\n")

    # ── Bước 5: Precompute safe-sets ─────────────────────────
    print("=" * 55)
    print("BƯỚC 5: PRECOMPUTE SAFE-SETS")
    print("=" * 55)
    print("  Đang tính safe-sets...", end=" ", flush=True)
    t0 = time.time()
    # safe_sets[i] = danh sách PMI không conflict với PMI i (dist < THRESHOLD)
    safe_sets = []
    for i in range(pmi_count):
        safe_sets.append(np.where(dist_mat[i] < THRESHOLD)[0].astype(np.uint16))
    print(f"xong ({time.time()-t0:.1f}s)\n")

    # ── Bước 6: Sinh dataset ──────────────────────────────────
    print("=" * 55)
    print(f"BƯỚC 6: SINH {N_SAMPLES:,} MẪU")
    print("=" * 55)

    X_dataset = np.zeros((N_SAMPLES, K_WAITING, F_features), dtype=np.float32)
    Y_dataset = np.zeros((N_SAMPLES, K_WAITING),              dtype=np.float32)
    pmi_usage = np.zeros(pmi_count, dtype=np.int32)

    rng     = np.random.default_rng(seed=42)
    s       = 0
    skipped = 0
    t0      = time.time()

    while s < N_SAMPLES:
        # A. Chọn anchor PMI bằng adaptive weight (cân bằng)
        usage_act        = pmi_usage[active_pmis].astype(np.float64) + 1.0
        adaptive_weights = 1.0 / usage_act
        adaptive_weights /= adaptive_weights.sum()
        anchor_local = rng.choice(n_active, p=adaptive_weights)
        anchor_pmi   = active_pmis[anchor_local]

        # B. Chọn 1 valid pair chứa anchor
        k_chosen = rng.choice(pmi_to_pairs[anchor_pmi])
        w_pmi_1  = int(valid_i[k_chosen])
        w_pmi_2  = int(valid_j[k_chosen])

        # C. Candidate pool: safe với CẢ HAI winner (dùng precomputed safe_sets)
        candidates = np.intersect1d(
            safe_sets[w_pmi_1],
            safe_sets[w_pmi_2],
            assume_unique=True
        )
        # Loại 2 winner khỏi pool
        candidates = candidates[
            (candidates != w_pmi_1) & (candidates != w_pmi_2)
        ]

        if len(candidates) < K_WAITING - 2:
            skipped += 1
            continue

        # D. Greedy pick K-2 từ candidates (kiểm tra không conflict với nhau)
        conflict  = True
        rand_pmis = None
        for _ in range(MAX_RETRY):
            chosen = rng.choice(candidates, size=K_WAITING - 2, replace=False)
            sub    = dist_mat[np.ix_(chosen, chosen)]
            np.fill_diagonal(sub, 0)
            if not np.any(sub >= THRESHOLD):
                rand_pmis = chosen
                conflict  = False
                break

        if conflict:
            skipped += 1
            continue

        # E. Ghép 10 UE, shuffle
        all_pmis    = np.concatenate([[w_pmi_1, w_pmi_2], rand_pmis])
        shuffle_idx = rng.permutation(K_WAITING)
        slot_pmi    = all_pmis[shuffle_idx]
        winner_pos  = np.where((shuffle_idx == 0) | (shuffle_idx == 1))[0]

        # F. Build X & Y
        X_dataset[s]     = X_pmi[slot_pmi]
        y_label          = np.zeros(K_WAITING, dtype=np.float32)
        y_label[winner_pos] = 1.0

        if y_label.sum() != 2:
            continue   # sanity check

        Y_dataset[s] = y_label
        pmi_usage[w_pmi_1] += 1
        pmi_usage[w_pmi_2] += 1
        s += 1

        if s % 1000 == 0:
            u = pmi_usage[active_pmis]
            elapsed = time.time() - t0
            eta     = elapsed / s * (N_SAMPLES - s)
            print(f"  [{s:5d}/{N_SAMPLES}] "
                  f"usage std={u.std():.2f} | min={u.min()} max={u.max()} | "
                  f"skipped={skipped} | ETA={eta:.0f}s")

    t_gen = time.time() - t0

    # ── Bước 7: Báo cáo & lưu ────────────────────────────────
    print(f"\n{'='*55}")
    print("KẾT QUẢ")
    print(f"{'='*55}")
    print(f"Thời gian sinh  : {t_gen:.1f} giây")
    print(f"Skipped TTIs    : {skipped}")
    u = pmi_usage[active_pmis]
    print(f"PMI usage std   : {u.std():.2f}  (thấp = cân bằng tốt)")
    print(f"PMI usage min/max: {u.min()} / {u.max()}")
    print(f"X shape         : {X_dataset.shape}")
    print(f"Y shape         : {Y_dataset.shape}")
    print(f"Label check     : {Y_dataset.sum(axis=1).mean():.2f} winners/sample (phải = 2.0)")

    np.savez_compressed(
        SAVE_PATH,
        X           = X_dataset,
        Y           = Y_dataset,
        valid_pairs = np.stack([valid_i, valid_j], axis=1),
        valid_dists = valid_d,
        pmi_usage   = pmi_usage,
        dist_mat    = dist_mat,   # lưu luôn để dùng lại nếu cần
    )
    print(f"\n=> Đã lưu: {SAVE_PATH}")
    print("HOÀN TẤT!")


if __name__ == "__main__":
    main()