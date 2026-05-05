import torch
import torch.nn as nn
import numpy as np
import itertools
import random

# ==========================================
# 1. CẤU TRÚC MODEL AI (Đồng bộ với train.py - V2)
# ==========================================
class OrthogonalPredictor(nn.Module):
    def __init__(self, num_pmi=1024, embed_dim=128):  # embed_dim=128, giống train.py
        super(OrthogonalPredictor, self).__init__()

        self.embedding = nn.Embedding(num_embeddings=num_pmi, embedding_dim=embed_dim)

        # Input: 128 + 128 + 2 = 258 chiều
        input_size = embed_dim * 2 + 2

        # Kiến trúc giống hệt train.py (có BatchNorm + Dropout)
        self.mlp = nn.Sequential(
            nn.Linear(input_size, 256),
            nn.BatchNorm1d(256),
            nn.ReLU(),
            nn.Dropout(0.2),

            nn.Linear(256, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.Dropout(0.2),

            nn.Linear(128, 32),
            nn.ReLU(),

            nn.Linear(32, 1),
            nn.Sigmoid()
        )

    def forward(self, pmi1, pmi2):
        vec1 = self.embedding(pmi1)
        vec2 = self.embedding(pmi2)
        dot_product = (vec1 * vec2).sum(dim=1, keepdim=True)
        l2_dist = torch.norm(vec1 - vec2, dim=1, keepdim=True)
        combined = torch.cat((vec1, vec2, dot_product, l2_dist), dim=1)
        return self.mlp(combined)


# ==========================================
# 2. CÁC HÀM TIỆN ÍCH (Toán học & Đọc file)
# ==========================================
def calculate_math_chordal(pmi_m, pmi_n):
    num_layers = pmi_m.shape[1]
    R = pmi_m.conj().T @ pmi_n
    norm_r2 = np.linalg.norm(R, 'fro') ** 2
    norm_m2 = np.linalg.norm(pmi_m, 'fro') ** 2
    norm_n2 = np.linalg.norm(pmi_n, 'fro') ** 2
    correlation = (num_layers * norm_r2) / (norm_m2 * norm_n2)
    return 1.0 - min(np.real(correlation), 1.0)


def load_pmi_pool(filename, n_port=32, n_layers=4):
    w_pool = []
    try:
        with open(filename, 'r') as f:
            while True:
                info_line = f.readline()
                if not info_line:
                    break
                info_line = info_line.strip()
                if not info_line:
                    continue

                w_temp = np.zeros((n_port, n_layers), dtype=np.complex128)
                for r in range(n_port):
                    row_data = f.readline().strip().replace('i', 'j').replace(' ', ' ')
                    w_temp[r, :] = [complex(x) for x in row_data.split()]
                w_pool.append(w_temp)
        return w_pool
    except Exception as e:
        print(f"Lỗi đọc file: {e}")
        return []


# ==========================================
# 3. QUY TRÌNH LẬP LỊCH & KIỂM CHỨNG
# ==========================================
def schedule_users(ue_queue, pool_file, top_k=5):
    print(f"\n--- BƯỚC 1: HÀNG CHỜ NGƯỜI DÙNG TẠI TTI HIỆN TẠI ---")
    print(f"Danh sách UE (Index PMI): {ue_queue}")
    print(f"Số lượng UE: {len(ue_queue)} -> Tổng số cặp khả thi: {len(ue_queue)*(len(ue_queue)-1)//2}\n")

    # Load Model (đúng kiến trúc V2)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"-> Thiết bị đang dùng: {device}")

    model = OrthogonalPredictor(num_pmi=1024, embed_dim=128).to(device)
    model.load_state_dict(torch.load('mu_mimo_ai_weights.pth', map_location=device, weights_only=True))
    model.eval()

    # Tạo tất cả các cặp
    all_pairs = list(itertools.combinations(ue_queue, 2))
    ai_results = []

    print("--- BƯỚC 2: AI SUY LUẬN TÌM CẶP TỐT NHẤT ---")
    with torch.no_grad():
        for pmi1, pmi2 in all_pairs:
            t1 = torch.tensor([pmi1 - 1], dtype=torch.long).to(device)
            t2 = torch.tensor([pmi2 - 1], dtype=torch.long).to(device)
            score = model(t1, t2).item()
            ai_results.append({
                'pair': (pmi1, pmi2),
                'ai_score': score
            })

    # Sắp xếp theo AI Score giảm dần (điểm gần 1.0 = trực giao cao)
    ai_results.sort(key=lambda x: x['ai_score'], reverse=True)
    top_pairs = ai_results[:top_k]

    print(f"AI đã chọn ra {top_k} cặp có độ trực giao cao nhất.\n")

    # Kiểm chứng lại bằng file text và Toán học
    print("--- BƯỚC 3: KIỂM CHỨNG LẠI BẰNG TOÁN HỌC TRÊN FILE TEXT ---")
    pmi_pool = load_pmi_pool(pool_file)
    if not pmi_pool:
        print("Không đọc được file PMI pool. Dừng lại.")
        return

    print(f"{'Hạng':<5} | {'Cặp UE (PMI)':<15} | {'Điểm do AI chọn':<18} | {'Điểm Toán Học Thực Tế':<22} | {'Nhận xét'}")
    print("-" * 95)

    for i, result in enumerate(top_pairs):
        pmi1, pmi2 = result['pair']
        ai_score = result['ai_score']

        W1 = pmi_pool[pmi1 - 1]
        W2 = pmi_pool[pmi2 - 1]

        math_score = calculate_math_chordal(W1, W2)

        if math_score > 0.95:
            nhan_xet = "Hoàn hảo (Trực giao mạnh)"
        elif math_score > 0.85:
            nhan_xet = "Tốt (Chấp nhận được)"
        else:
            nhan_xet = "Tệ (Nhiễu cao)"

        print(f"#{i+1:<4} | ({pmi1}, {pmi2})".ljust(23) +
              f" | {ai_score:.6f}".ljust(21) +
              f" | {math_score:.6f}".ljust(25) +
              f" | {nhan_xet}")

    print("-" * 95)
    print("Kết luận: AI đã thực hiện lập lịch thành công!")


if __name__ == "__main__":
    file_name = "Layer4_Port32_N1_4_N2-4_c1.txt"

    random.seed(42)
    current_queue = random.sample(range(1, 1025), 20)

    schedule_users(current_queue, file_name, top_k=5)