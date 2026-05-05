import torch
import torch.nn as nn
import torch.optim as optim
import pandas as pd
from torch.utils.data import Dataset, DataLoader
from sklearn.model_selection import train_test_split

# ==========================================
# 1. Định nghĩa cấu trúc Dataset
# ==========================================
class PMIDataset(Dataset):
    def __init__(self, pmi1, pmi2, labels):
        # Trừ 1 vì index trong file CSV là 1-1024, còn PyTorch bắt đầu từ 0-1023
        self.pmi1 = torch.tensor(pmi1 - 1, dtype=torch.long)
        self.pmi2 = torch.tensor(pmi2 - 1, dtype=torch.long)
        self.labels = torch.tensor(labels, dtype=torch.float32).unsqueeze(1)

    def __len__(self):
        return len(self.labels)

    def __getitem__(self, idx):
        return self.pmi1[idx], self.pmi2[idx], self.labels[idx]

# ==========================================
# 2. Định nghĩa Model (Siamese Network NÂNG CẤP)
# ==========================================
# ==========================================
# MODEL V2: SIAMESE MLP DEEP & WIDE (NÂNG CẤP)
# ==========================================
class OrthogonalPredictor(nn.Module):
    # Tăng embed_dim từ 16 lên 128 để chứa đủ thông tin không gian của 32 Ăng-ten
    def __init__(self, num_pmi=1024, embed_dim=128): 
        super(OrthogonalPredictor, self).__init__()
        
        self.embedding = nn.Embedding(num_embeddings=num_pmi, embedding_dim=embed_dim)
        
        # Input bây giờ sẽ là: 128 + 128 + 2 = 258 chiều
        input_size = embed_dim * 2 + 2 
        
        # Mở rộng số lượng Nơ-ron và thêm các lớp bảo vệ (Dropout, BatchNorm)
        self.mlp = nn.Sequential(
            nn.Linear(input_size, 256),
            nn.BatchNorm1d(256),       # Chuẩn hóa Batch giúp hội tụ nhanh và ổn định
            nn.ReLU(),
            nn.Dropout(0.2),           # Bắt model quên đi 20% nơ-ron để chống học vẹt
            
            nn.Linear(256, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.Dropout(0.2),           # Chống học vẹt lần 2
            
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
        out = self.mlp(combined)
        return out

# ==========================================
# 3. Nạp dữ liệu từ CSV
# ==========================================
print("Đang đọc dữ liệu từ CSV... (Chờ chút nhé)")
# Sửa lại tên file ở đây nếu bro lưu tên khác
df = pd.read_csv('mu_mimo_dataset_full.csv')

X_pmi1 = df['PMI_Index_1'].values
X_pmi2 = df['PMI_Index_2'].values
y_labels = df['Chordal_Distance'].values

# Chia 80% train, 20% test
pmi1_train, pmi1_test, pmi2_train, pmi2_test, y_train, y_test = train_test_split(
    X_pmi1, X_pmi2, y_labels, test_size=0.2, random_state=42
)

# Batch_size=1024 giúp đẩy nhanh tốc độ train trên CPU/GPU
train_dataset = PMIDataset(pmi1_train, pmi2_train, y_train)
test_dataset = PMIDataset(pmi1_test, pmi2_test, y_test)

train_loader = DataLoader(train_dataset, batch_size=1024, shuffle=True)
test_loader = DataLoader(test_dataset, batch_size=1024, shuffle=False)

# ==========================================
# 4. Cấu hình Training
# ==========================================
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"-> Thiết bị đang dùng để train: {device}")

model = OrthogonalPredictor(num_pmi=1024, embed_dim=16).to(device)
criterion = nn.MSELoss()
optimizer = optim.Adam(model.parameters(), lr=0.005) # Learning rate 0.005

# ==========================================
# 5. Vòng lặp Huấn luyện (Epochs)
# ==========================================
epochs = 30 # Chạy thử 30 vòng xem sao

print("\n--- BẮT ĐẦU TRAINING ---")
for epoch in range(epochs):
    model.train()
    total_loss = 0

    for b_pmi1, b_pmi2, b_labels in train_loader:
        b_pmi1, b_pmi2, b_labels = b_pmi1.to(device), b_pmi2.to(device), b_labels.to(device)

        optimizer.zero_grad()
        predictions = model(b_pmi1, b_pmi2)
        loss = criterion(predictions, b_labels)

        loss.backward()
        optimizer.step()

        total_loss += loss.item()

    avg_train_loss = total_loss / len(train_loader)

    # Validation (Chạy test để xem model có học vẹt không)
    model.eval()
    val_loss = 0
    with torch.no_grad():
        for b_pmi1, b_pmi2, b_labels in test_loader:
            b_pmi1, b_pmi2, b_labels = b_pmi1.to(device), b_pmi2.to(device), b_labels.to(device)
            preds = model(b_pmi1, b_pmi2)
            val_loss += criterion(preds, b_labels).item()

    avg_val_loss = val_loss / len(test_loader)

    print(f"Epoch [{epoch+1}/{epochs}] | Train Loss: {avg_train_loss:.5f} | Val Loss: {avg_val_loss:.5f}")

# Lưu "Bộ Não" lại
torch.save(model.state_dict(), 'mu_mimo_ai_weights.pth')
print("\n--- HOÀN THÀNH! ---")
print("Đã lưu trọng số tại 'mu_mimo_ai_weights.pth'")