"""
mu_mimo_inference.py
====================
Python wrapper cho MATLAB gọi qua py.importmodule.
MATLAB chỉ cần gọi:
    py.mu_mimo_inference.predict_cd(pmi1, ri1, cqi1, pmi2, ri2, cqi2)
    py.mu_mimo_inference.predict_batch(pmi1_list, ri1_list, ...)
"""

import torch
import torch.nn as nn
import numpy as np
import os

# =========================================================================
# CONFIG — chỉnh đường dẫn nếu cần
# =========================================================================
WEIGHT_FILE = 'mu_mimo_weights_v9.pth'
N_PORT      = 32
FEAT_DIM    = 256

CODEBOOK_FILES = {
    1: 'Layer1_Port32_N1_4_N2-4_c1.txt',
    2: 'Layer2_Port32_N1_4_N2-4_c1.txt',
    3: 'Layer3_Port32_N1_4_N2-4_c1.txt',
    4: 'Layer4_Port32_N1_4_N2-4_c1.txt',
}

CQI_EFFICIENCY = {
     1: 0.1523,  2: 0.3770,  3: 0.8770,  4: 1.4766,
     5: 1.9141,  6: 2.4063,  7: 2.7305,  8: 3.3223,
     9: 3.9023, 10: 4.5234, 11: 5.1152, 12: 5.5547,
    13: 6.2266, 14: 6.9141, 15: 7.4063,
}
EFF_MIN = min(CQI_EFFICIENCY.values())
EFF_MAX = max(CQI_EFFICIENCY.values())
CQI_TO_SINR = {cqi: (2.0 ** eff - 1.0) for cqi, eff in CQI_EFFICIENCY.items()}

# =========================================================================
# MODEL
# =========================================================================
FEAT_FULL = FEAT_DIM + 2  # 258

class ResBlock(nn.Module):
    def __init__(self, d):
        super().__init__()
        self.block = nn.Sequential(
            nn.Linear(d, d), nn.LayerNorm(d), nn.GELU(),
            nn.Dropout(0.1),
            nn.Linear(d, d), nn.LayerNorm(d),
        )
        self.act = nn.GELU()
    def forward(self, x):
        return self.act(x + self.block(x))

class OrthogonalPredictorV9(nn.Module):
    def __init__(self, feat_dim=FEAT_FULL):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(feat_dim, 256), nn.LayerNorm(256), nn.GELU(), nn.Dropout(0.1),
            nn.Linear(256, 128),     nn.LayerNorm(128), nn.GELU(),
            nn.Linear(128, 64),      nn.LayerNorm(64),  nn.GELU(),
        )
        self.fusion = nn.Sequential(
            nn.Linear(194, 256), nn.LayerNorm(256), nn.GELU(),
        )
        self.res_blocks = nn.Sequential(ResBlock(256), ResBlock(256), ResBlock(256))
        self.head = nn.Sequential(
            nn.Linear(256, 64), nn.LayerNorm(64), nn.GELU(),
            nn.Linear(64, 1),   nn.Sigmoid(),
        )
    def forward(self, f1, f2):
        v1, v2 = self.encoder(f1), self.encoder(f2)
        x = torch.cat([
            v1 + v2, v1 * v2, torch.abs(v1 - v2),
            (v1 * v2).sum(1, keepdim=True),
            torch.norm(v1 - v2, dim=1, keepdim=True),
        ], dim=1)
        return self.head(self.res_blocks(self.fusion(x)))

# =========================================================================
# HELPERS
# =========================================================================
def _load_pmi_pool(filename, n_port, n_layers):
    pool = []
    with open(filename, 'r') as f:
        while True:
            line = f.readline()
            if not line: break
            if not line.strip(): continue
            W = np.zeros((n_port, n_layers), dtype=np.complex128)
            for r in range(n_port):
                row = f.readline().strip().replace('i', 'j')
                W[r, :] = [complex(x) for x in row.split()]
            pool.append(W)
    return pool

def _pool_to_feature_matrix(pool, target_dim=256):
    feats = []
    for W in pool:
        vec = np.concatenate([W.real.flatten(), W.imag.flatten()]).astype(np.float32)
        if len(vec) < target_dim:
            vec = np.pad(vec, (0, target_dim - len(vec)))
        feats.append(vec)
    return torch.tensor(np.array(feats), dtype=torch.float32)

def _norm_eff(cqi):
    return (CQI_EFFICIENCY[int(cqi)] - EFF_MIN) / (EFF_MAX - EFF_MIN) * 2 - 1

def _norm_ri(ri):
    return ((int(ri) - 1) / 3.0) * 2 - 1

def _make_feature(pmi, ri, cqi):
    ri  = int(ri)
    pmi = int(pmi)
    cqi = int(cqi)
    f   = _feature_matrices[ri][pmi - 1]
    e   = torch.tensor([_norm_eff(cqi)])
    r   = torch.tensor([_norm_ri(ri)])
    return torch.cat([f, e, r])

def _compute_sumrate(cd, ri1, cqi1, ri2, cqi2):
    s1 = CQI_TO_SINR[int(cqi1)]
    s2 = CQI_TO_SINR[int(cqi2)]
    f  = 1.0 - float(cd)
    sinr1  = (int(ri1) * s1) / (f * int(ri2) * s2 + 1.0)
    sinr2  = (int(ri2) * s2) / (f * int(ri1) * s1 + 1.0)
    sr_mu  = int(ri1) * np.log2(1 + sinr1) + int(ri2) * np.log2(1 + sinr2)
    sr_su  = int(ri1) * np.log2(1 + int(ri1)*s1) + int(ri2) * np.log2(1 + int(ri2)*s2)
    gain   = sr_mu / sr_su if sr_su > 0 else 0.0
    return float(sr_mu), float(sr_su), float(gain)

# =========================================================================
# KHỞI TẠO (chạy 1 lần khi import)
# =========================================================================
_device          = torch.device('cpu')   # MATLAB thường không có GPU context
_feature_matrices = {}
_model           = None
_initialized     = False

def _initialize():
    global _feature_matrices, _model, _initialized
    if _initialized:
        return

    print('[mu_mimo_inference] Dang khoi tao...')

    # Load codebook
    for n_layers, fp in CODEBOOK_FILES.items():
        if not os.path.exists(fp):
            raise FileNotFoundError(f'Khong tim thay: {fp}')
        pool = _load_pmi_pool(fp, N_PORT, n_layers)
        _feature_matrices[n_layers] = _pool_to_feature_matrix(pool, FEAT_DIM)
    print(f'  Codebook: {[f"Layer{k}:{v.shape[0]}" for k,v in _feature_matrices.items()]}')

    # Load model
    if not os.path.exists(WEIGHT_FILE):
        raise FileNotFoundError(f'Khong tim thay weight file: {WEIGHT_FILE}')
    _model = OrthogonalPredictorV9().to(_device)
    ckpt   = torch.load(WEIGHT_FILE, map_location=_device)
    _model.load_state_dict(ckpt['model_state_dict'])
    _model.eval()
    print(f'  Model: epoch={ckpt.get("epoch","?")}, val_mse={ckpt.get("val_mse",0):.6f}')

    _initialized = True
    print('[mu_mimo_inference] San sang.\n')

# Tự khởi tạo khi import
_initialize()

# =========================================================================
# PUBLIC API — MATLAB gọi các hàm này
# =========================================================================

def predict_cd(pmi1, ri1, cqi1, pmi2, ri2, cqi2):
    """
    Dự đoán Chordal Distance cho 1 cặp UE.

    MATLAB call:
        cd = py.mu_mimo_inference.predict_cd(733, 3, 10, 862, 4, 10)

    Returns: float — Chordal Distance trong [0, 1]
    """
    f1 = _make_feature(pmi1, ri1, cqi1).unsqueeze(0).to(_device)
    f2 = _make_feature(pmi2, ri2, cqi2).unsqueeze(0).to(_device)
    with torch.no_grad():
        cd = _model(f1, f2).item()
    return float(cd)


def predict_with_gain(pmi1, ri1, cqi1, pmi2, ri2, cqi2):
    """
    Dự đoán CD + tính SumRate + Gain cho 1 cặp UE.

    MATLAB call:
        result = py.mu_mimo_inference.predict_with_gain(733,3,10, 862,4,10)
        cd     = double(result{1})
        sr_mu  = double(result{2})
        sr_su  = double(result{3})
        gain   = double(result{4})
        is_mu  = logical(result{5})

    Returns: list [cd, sr_mu, sr_su, gain, is_mu]
    """
    cd             = predict_cd(pmi1, ri1, cqi1, pmi2, ri2, cqi2)
    sr_mu, sr_su, gain = _compute_sumrate(cd, ri1, cqi1, ri2, cqi2)
    is_mu          = gain >= 0.95
    return [cd, sr_mu, sr_su, gain, is_mu]


def predict_batch(pmi1_list, ri1_list, cqi1_list,
                  pmi2_list, ri2_list, cqi2_list):
    """
    Dự đoán CD + Gain cho nhiều cặp cùng lúc (nhanh hơn loop từng cặp).

    MATLAB call — truyền vào cell array hoặc list:
        pmi1_list = py.list({int32(733), int32(512)})
        ri1_list  = py.list({int32(3),   int32(4)})
        ...
        results = py.mu_mimo_inference.predict_batch(
                      pmi1_list, ri1_list, cqi1_list,
                      pmi2_list, ri2_list, cqi2_list)

        % Giải nén kết quả
        cd_list   = double(py.array.array('d', results{1}))
        gain_list = double(py.array.array('d', results{4}))
        ismu_list = logical(double(py.array.array('d', results{5})))

    Returns: list of 5 lists [cd_list, sr_mu_list, sr_su_list, gain_list, is_mu_list]
    """
    # Convert từ MATLAB types sang Python list
    pmi1 = [int(x) for x in pmi1_list]
    ri1  = [int(x) for x in ri1_list]
    cqi1 = [int(x) for x in cqi1_list]
    pmi2 = [int(x) for x in pmi2_list]
    ri2  = [int(x) for x in ri2_list]
    cqi2 = [int(x) for x in cqi2_list]

    n = len(pmi1)
    f1_list, f2_list = [], []
    for i in range(n):
        f1_list.append(_make_feature(pmi1[i], ri1[i], cqi1[i]))
        f2_list.append(_make_feature(pmi2[i], ri2[i], cqi2[i]))

    F1 = torch.stack(f1_list).to(_device)
    F2 = torch.stack(f2_list).to(_device)

    with torch.no_grad():
        cd_preds = _model(F1, F2).squeeze(1).cpu().numpy()

    cd_list    = []
    sr_mu_list = []
    sr_su_list = []
    gain_list  = []
    is_mu_list = []

    for i in range(n):
        cd_val = float(cd_preds[i])
        sr_mu, sr_su, gain = _compute_sumrate(cd_val, ri1[i], cqi1[i], ri2[i], cqi2[i])
        cd_list.append(cd_val)
        sr_mu_list.append(sr_mu)
        sr_su_list.append(sr_su)
        gain_list.append(gain)
        is_mu_list.append(1.0 if gain >= 0.95 else 0.0)

    return [cd_list, sr_mu_list, sr_su_list, gain_list, is_mu_list]