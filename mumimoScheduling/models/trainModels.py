import torch
import torch.nn as nn
import torch.optim as optim
import pandas as pd
import numpy as np
from torch.utils.data import Dataset, DataLoader, Subset

# ==========================================
# 1. THÔNG SỐ CẤU HÌNH
# ==========================================
N_PORT      = 32
FEAT_DIM    = N_PORT * 4 * 2   # 256  — real + imag của ma trận 32×4 (pad nếu layer < 4)
BATCH_SIZE  = 1024
EPOCHS      = 100
LR          = 0.001
OUTPUT_FILE = 'mu_mimo_weights_v9.pth'

CODEBOOK_FILES = {
    1: 'Layer1_Port32_N1_4_N2-4_c1.txt',
    2: 'Layer2_Port32_N1_4_N2-4_c1.txt',
    3: 'Layer3_Port32_N1_4_N2-4_c1.txt',
    4: 'Layer4_Port32_N1_4_N2-4_c1.txt',
}

# =========================================================
# CQI Table 2 — 3GPP TS 38.214 Table 5.2.2.1-3
# Spectral efficiency (bits/s/Hz)
# SINR_nominal = 2^eff - 1  (Shannon inverse)
# =========================================================
CQI_EFFICIENCY = {
     1:  0.1523,  2:  0.3770,  3:  0.8770,  4:  1.4766,
     5:  1.9141,  6:  2.4063,  7:  2.7305,  8:  3.3223,
     9:  3.9023, 10:  4.5234, 11:  5.1152, 12:  5.5547,
    13:  6.2266, 14:  6.9141, 15:  7.4063,
}
EFF_MIN = min(CQI_EFFICIENCY.values())   # 0.1523
EFF_MAX = max(CQI_EFFICIENCY.values())   # 7.4063

def cqi_to_norm_eff(cqi_array):
    """Normalize spectral efficiency về [-1, 1]."""
    eff = np.array([CQI_EFFICIENCY[c] for c in cqi_array], dtype=np.float32)
    return (eff - EFF_MIN) / (EFF_MAX - EFF_MIN) * 2 - 1

# RI normalize: RI ∈ {1,2,3,4} → [-1, -0.33, 0.33, 1]
def ri_normalize(ri_array):
    return ((np.array(ri_array, dtype=np.float32) - 1) / 3.0) * 2 - 1

# ==========================================
# 2. NẠP CODEBOOK
# ==========================================
def load_pmi_pool(filename, n_port, n_layers):
    w_pool = []
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
            w_pool.append(W)
    return w_pool

def pool_to_feature_matrix(pmi_pool, target_dim=256):
    """
    Flatten từng ma trận W (32 × n_layers) thành [real, imag] rồi pad lên target_dim.
    Layer 1: 32×1 → 64 dims → pad → 256
    Layer 2: 32×2 → 128 dims → pad → 256
    Layer 3: 32×3 → 192 dims → pad → 256
    Layer 4: 32×4 → 256 dims → không pad
    """
    features = []
    for W in pmi_pool:
        vec = np.concatenate([W.real.flatten(), W.imag.flatten()])
        if len(vec) < target_dim:
            vec = np.pad(vec, (0, target_dim - len(vec)))
        features.append(vec.astype(np.float32))
    return torch.tensor(np.array(features), dtype=torch.float32)

print("=" * 65)
print("   TRAINING V9 — Layer 1-4 | CQI Table 2 | RI norm fix")
print("=" * 65)

print("\n[1/3] Nạp codebook...")
feature_matrices = {}
for n_layers, filepath in CODEBOOK_FILES.items():
    pool = load_pmi_pool(filepath, N_PORT, n_layers)
    feature_matrices[n_layers] = pool_to_feature_matrix(pool, target_dim=FEAT_DIM)
    print(f"  Layer{n_layers}: {len(pool):>5} matrices → feature shape {feature_matrices[n_layers].shape}")

# ==========================================
# 3. DATASET CLASS
# ==========================================
class PMIDataset(Dataset):
    def __init__(self, csv_path, chunksize=200_000):
        print(f"  Đang đọc CSV theo chunk (chunksize={chunksize:,})...")
        self.data = pd.concat(
            pd.read_csv(
                csv_path,
                usecols=['PMI_1', 'RI_1', 'CQI_1',
                         'PMI_2', 'RI_2', 'CQI_2',
                         'Chordal_Distance'],
                dtype={
                    'PMI_1'           : 'int32',
                    'RI_1'            : 'int8',
                    'CQI_1'           : 'int8',
                    'PMI_2'           : 'int32',
                    'RI_2'            : 'int8',
                    'CQI_2'           : 'int8',
                    'Chordal_Distance': 'float32',
                },
                chunksize=chunksize,
            ),
            ignore_index=True,
        )
        # Cap 2M rows để an toàn RAM trên t3.medium
        if len(self.data) > 2_000_000:
            self.data = self.data.iloc[:2_000_000].reset_index(drop=True)
        print(f"  Loaded: {len(self.data):,} rows (capped at 2M)")

        # Precompute scalars — lưu dưới dạng tensor 1-D để __getitem__ nhanh
        self.eff1   = torch.tensor(cqi_to_norm_eff(self.data['CQI_1'].values), dtype=torch.float32)
        self.eff2   = torch.tensor(cqi_to_norm_eff(self.data['CQI_2'].values), dtype=torch.float32)
        self.ri1_f  = torch.tensor(ri_normalize(self.data['RI_1'].values),     dtype=torch.float32)
        self.ri2_f  = torch.tensor(ri_normalize(self.data['RI_2'].values),     dtype=torch.float32)
        self.labels = torch.tensor(self.data['Chordal_Distance'].values,       dtype=torch.float32)

        self.pmi1    = self.data['PMI_1'].values.astype(np.int32)
        self.pmi2    = self.data['PMI_2'].values.astype(np.int32)
        self.ri1_raw = self.data['RI_1'].values.astype(np.int8)
        self.ri2_raw = self.data['RI_2'].values.astype(np.int8)

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        r1 = int(self.ri1_raw[idx])
        r2 = int(self.ri2_raw[idx])

        # Lấy feature vector từ precomputed matrix (1-indexed PMI → 0-indexed)
        f1 = feature_matrices[r1][self.pmi1[idx] - 1]   # (256,)
        f2 = feature_matrices[r2][self.pmi2[idx] - 1]   # (256,)

        # Ghép CQI efficiency (normalized) + RI (normalized) → (258,)
        f1_full = torch.cat([f1,
                              self.eff1[idx].unsqueeze(0),
                              self.ri1_f[idx].unsqueeze(0)])
        f2_full = torch.cat([f2,
                              self.eff2[idx].unsqueeze(0),
                              self.ri2_f[idx].unsqueeze(0)])

        return f1_full, f2_full, self.labels[idx].unsqueeze(0)

# ==========================================
# 4. NẠP DỮ LIỆU
# ==========================================
print("\n[2/3] Đọc CSV...")
full_ds = PMIDataset('mu_mimo_dataset.csv')

total   = len(full_ds)
indices = np.random.permutation(total)
split   = int(total * 0.8)

train_ds     = Subset(full_ds, indices[:split])
test_ds      = Subset(full_ds, indices[split:])
use_cuda     = torch.cuda.is_available()
n_workers    = 2  # EC2 suggestion

train_loader = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True,
                          num_workers=n_workers, pin_memory=use_cuda)
test_loader  = DataLoader(test_ds,  batch_size=BATCH_SIZE, shuffle=False,
                          num_workers=n_workers, pin_memory=use_cuda)
print(f"  Train: {len(train_ds):,} | Test: {len(test_ds):,}")

# ==========================================
# 5. KIẾN TRÚC MODEL
# ==========================================
FEAT_FULL = FEAT_DIM + 2   # 258 = 256 (PMI) + 1 (CQI eff) + 1 (RI)

class ResBlock(nn.Module):
    def __init__(self, hidden_dim):
        super().__init__()
        self.block = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.GELU(),
            nn.Dropout(0.1),
            nn.Linear(hidden_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
        )
        self.act = nn.GELU()

    def forward(self, x):
        return self.act(x + self.block(x))

class OrthogonalPredictorV9(nn.Module):
    """
    Kiến trúc siamese:
      encoder(258) → 64-dim embedding
      combined = [v1+v2 | v1*v2 | |v1-v2| | dot | dist] → 193 dims
      MLP → ResBlocks → scalar output (Chordal Distance)
    """
    def __init__(self, feat_dim=FEAT_FULL):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(feat_dim, 256),
            nn.LayerNorm(256),
            nn.GELU(),
            nn.Dropout(0.1),
            nn.Linear(256, 128),
            nn.LayerNorm(128),
            nn.GELU(),
            nn.Linear(128, 64),
            nn.LayerNorm(64),
            nn.GELU(),
        )
        # combined dim: 64+64+64+1+1 = 194
        self.fusion = nn.Sequential(
            nn.Linear(194, 256),
            nn.LayerNorm(256),
            nn.GELU(),
        )
        self.res_blocks = nn.Sequential(
            ResBlock(256),
            ResBlock(256),
            ResBlock(256),
        )
        self.head = nn.Sequential(
            nn.Linear(256, 64),
            nn.LayerNorm(64),
            nn.GELU(),
            nn.Linear(64, 1),
            nn.Sigmoid(),   # Chordal Distance ∈ [0, 1]
        )

    def forward(self, f1, f2):
        v1 = self.encoder(f1)
        v2 = self.encoder(f2)
        combined = torch.cat([
            v1 + v2,                                        # 64
            v1 * v2,                                        # 64
            torch.abs(v1 - v2),                             # 64
            (v1 * v2).sum(dim=1, keepdim=True),             #  1
            torch.norm(v1 - v2, dim=1, keepdim=True),       #  1
        ], dim=1)                                           # → 194
        x = self.fusion(combined)
        x = self.res_blocks(x)
        return self.head(x)

# ==========================================
# 6. LOSS
# ==========================================
def ranking_loss(preds, labels, margin=0.02):
    p = preds.squeeze(1)
    l = labels.squeeze(1)
    p_i = p.unsqueeze(1); p_j = p.unsqueeze(0)
    l_i = l.unsqueeze(1); l_j = l.unsqueeze(0)
    should_be_higher  = (l_i - l_j) > margin
    violation         = torch.clamp(margin - (p_i - p_j), min=0)
    active_violations = violation * should_be_higher.float()
    n_viol = (active_violations > 0).float().sum()
    if n_viol > 0:
        return active_violations.sum() / n_viol
    return torch.zeros(1, requires_grad=True, device=preds.device).squeeze()

def combined_loss(preds, labels, lambda_rank=0.5):
    mse  = nn.MSELoss()(preds, labels)
    rank = ranking_loss(preds, labels)
    return mse + lambda_rank * rank, mse.item(), rank.item()

# ==========================================
# 7. KHỞI TẠO MODEL
# ==========================================
print("\n[3/3] Khởi tạo model...")
device    = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model     = OrthogonalPredictorV9().to(device)
optimizer = optim.AdamW(model.parameters(), lr=LR, weight_decay=1e-4)
scheduler = torch.optim.lr_scheduler.CosineAnnealingWarmRestarts(
    optimizer, T_0=15, T_mult=2, eta_min=1e-6
)
print(f"  Device  : {device}")
print(f"  Params  : {sum(p.numel() for p in model.parameters()):,}")
print(f"  Feat dim: {FEAT_FULL}  (256 PMI + 1 CQI_eff + 1 RI)")

# ==========================================
# 8. TRAINING LOOP
# ==========================================
PATIENCE          = 12
MIN_DELTA         = 1e-7
ZERO_LOSS_THRESH  = 1e-6
best_val_loss     = float('inf')
best_epoch        = 0
epochs_no_improve = 0
warmup_epochs     = EPOCHS // 2   # pure MSE trước, ramp ranking sau

print(f"\n--- BẮT ĐẦU TRAINING V9 (epochs={EPOCHS}, warmup={warmup_epochs}) ---")
print(f"{'Ep':>4} | {'λ':>5} | {'Total':>10} | {'MSE':>10} | {'Rank':>10} | {'ValMSE':>10} | Note")
print("-" * 75)

for epoch in range(EPOCHS):
    # Lambda ramp: 0 trong warmup, tăng tuyến tính sau đó (max 0.5)
    if epoch < warmup_epochs:
        current_lambda = 0.0
    else:
        current_lambda = 0.5 * (epoch - warmup_epochs) / max(EPOCHS - warmup_epochs - 1, 1)

    model.train()
    t_loss = t_mse = t_rank = 0.0

    for f1, f2, bl in train_loader:
        f1, f2, bl = f1.to(device), f2.to(device), bl.to(device)
        optimizer.zero_grad()
        preds = model(f1, f2)
        loss, mse_v, rank_v = combined_loss(preds, bl, lambda_rank=current_lambda)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        optimizer.step()
        t_loss += loss.item()
        t_mse  += mse_v
        t_rank += rank_v

    scheduler.step()
    n = len(train_loader)

    # Validation
    model.eval()
    val_mse = 0.0
    with torch.no_grad():
        for f1, f2, bl in test_loader:
            f1, f2, bl = f1.to(device), f2.to(device), bl.to(device)
            val_mse += nn.MSELoss()(model(f1, f2), bl).item()
    avg_val = val_mse / len(test_loader)

    note = ""
    if avg_val < (best_val_loss - MIN_DELTA):
        best_val_loss     = avg_val
        best_epoch        = epoch + 1
        epochs_no_improve = 0
        torch.save({
            'epoch'           : epoch + 1,
            'model_state_dict': model.state_dict(),
            'val_mse'         : best_val_loss,
            'feat_dim'        : FEAT_FULL,
        }, OUTPUT_FILE)
        note = "✓ SAVED"
    else:
        epochs_no_improve += 1
        note = f"⏳ {epochs_no_improve}/{PATIENCE}"

    print(f"{epoch+1:>4} | {current_lambda:>5.3f} | {t_loss/n:>10.6f} | "
          f"{t_mse/n:>10.6f} | {t_rank/n:>10.6f} | {avg_val:>10.6f} | {note}")

    # Early stopping
    if t_mse/n < ZERO_LOSS_THRESH and avg_val < ZERO_LOSS_THRESH:
        print(f"\n🚀 Hội tụ hoàn toàn tại epoch {epoch+1}")
        break
    if epochs_no_improve >= PATIENCE:
        print(f"\n🛑 Early stopping sau {PATIENCE} epochs không cải thiện.")
        break

print(f"\n{'='*55}")
print(f"  ✅ Hoàn thành!")
print(f"     Best epoch : {best_epoch}")
print(f"     Val MSE    : {best_val_loss:.6f}")
print(f"     Saved      : '{OUTPUT_FILE}'")
print(f"{'='*55}")