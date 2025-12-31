# Type I Multi-Panel Codebook – Parameter Explanation
**(3GPP TS 38.214 – Section 5.2.2.2.2)**

Tài liệu này giải thích **các tham số cấu hình và chỉ số PMI/RI** trong **Type I Multi-Panel codebook**, ngoại trừ:
- Vector beam $v_{l,m}$
- Pha $\varphi$
- Ma trận precoder $W$

---

## 1. $N_g$ (Number of Panels)

- $N_g \in \{2, 4\}$ 
- Là số lượng **panel antenna vật lý**.
- Antenna array được chia thành $N_g$ nhóm độc lập.

**Ảnh hưởng:**
- Số panel quyết định việc có cần báo cáo pha liên panel hay không.
- Quy định `codebookMode` được phép sử dụng.

**Quy tắc:**
- Nếu $N_g = 2 \to$ `codebookMode` có thể là **1** hoặc **2**.
- Nếu $N_g = 4 \to$ `codebookMode` bắt buộc là **1**.

---

## 2. $N_1, N_2$ (Panel Dimensions)

Các giá trị này được cấu hình qua tham số lớp cao `ng-n1-n2`.
- $N_1$: Số antenna theo chiều ngang (chiều 1) trong mỗi panel.
- $N_2$: Số antenna theo chiều dọc (chiều 2) trong mỗi panel.

**Tổng số CSI-RS ports:**
Công thức tính bao gồm hệ số phân cực (x2):

$$P_{CSI-RS} = 2 \times N_g \times N_1 \times N_2$$

**Các cấu hình hỗ trợ (Theo Table 5.2.2.2.2-1):**
| Số Ports | Cấu hình $(N_g, N_1, N_2)$ | Tính toán |
| :---: | :---: | :--- |
| **8** | $(2, 2, 1)$ | $2 \times 2 \times 2 \times 1 = 8$ |
| **16** | $(2, 4, 1)$ | $2 \times 2 \times 4 \times 1 = 16$ |
| **16** | $(4, 2, 1)$ | $2 \times 4 \times 2 \times 1 = 16$ |
| **32** | $(4, 2, 2)$ | $2 \times 4 \times 2 \times 2 = 32$ |

---

## 3. $O_1, O_2$ (Oversampling Factors)

- $O_1$: Hệ số oversampling theo chiều $N_1$.
- $O_2$: Hệ số oversampling theo chiều $N_2$.
- Quy định **độ mịn của beam index**.

UE không tự chọn mà giá trị này phụ thuộc cố định vào cấu hình $(N_g, N_1, N_2)$ theo **Bảng 5.2.2.2.2-1**.

**Ví dụ:**
- Nếu $(N_g, N_1, N_2) = (2, 2, 1) \to (O_1, O_2) = (4, 1)$.
- Nếu $(N_g, N_1, N_2) = (2, 2, 2) \to (O_1, O_2) = (4, 4)$.

---

## 4. codebookMode

Xác định cách sử dụng PMI cấp cao (Higher-layer parameter).

| Mode | Ý nghĩa | Điều kiện áp dụng |
| :---: | :--- | :--- |
| **1** | Cấu trúc PMI đơn giản | Áp dụng cho cả $N_g=2$ và $N_g=4$ |
| **2** | PMI linh hoạt hơn (thêm thông tin pha/biên độ) | Chỉ áp dụng khi $N_g=2$ |

---

## 5. RI (Rank Indicator) – $\nu$

- $\nu \in \{1, 2, 3, 4\}$
- Số **layer truyền** (transmission layers).
- Mỗi giá trị RI sử dụng một bảng codebook riêng biệt được quy định trong chuẩn.

**Bảng tra cứu tương ứng:**
- **RI = 1** $\to$ Table 5.2.2.2.2-3
- **RI = 2** $\to$ Table 5.2.2.2.2-4
- **RI = 3** $\to$ Table 5.2.2.2.2-5
- **RI = 4** $\to$ Table 5.2.2.2.2-6

---

## 6. PMI Structure (Cấu trúc chỉ số Precoding)

PMI bao gồm các chỉ số codebook $i_1$ và $i_2$.

### 6.1 PMI cấp 1 ($i_1$) – Wideband/Long-term
Bao gồm các thành phần:
- $i_{1,1}$: Chỉ số beam theo chiều $N_1$ ($0 \dots N_1O_1 - 1$).
- $i_{1,2}$: Chỉ số beam theo chiều $N_2$ ($0 \dots N_2O_2 - 1$).
- $i_{1,4}$: Chỉ số liên quan đến panel (pha/biên độ liên panel).

**Lưu ý:** Nếu $N_2 = 1$, UE không báo cáo $i_{1,2}$ (mặc định bằng 0).

---

## 6. Chi tiết cấu trúc PMI ($i_1, i_2$)

Mỗi báo cáo PMI bao gồm hai nhóm chỉ số: **$i_1$ (Wideband/Long-term)** và **$i_2$ (Subband/Short-term)**.

### 6.1 Các tham số trong $i_1$
Vector $i_1$ có thể bao gồm các thành phần sau tùy thuộc vào Rank và Mode:

1.  **$i_{1,1}$ (Beam chiều 1):**
    - Chọn beam index theo chiều $N_1$.
    - Miền giá trị: $0, \dots, N_1 O_1 - 1$.

2.  **$i_{1,2}$ (Beam chiều 2):**
    - Chọn beam index theo chiều $N_2$.
    - Miền giá trị: $0, \dots, N_2 O_2 - 1$.
    - *Lưu ý:* Nếu $N_2 = 1$, tham số này không được báo cáo (mặc định = 0).

3.  **$i_{1,3}$ (Layer Mapping):**
    - **Chỉ xuất hiện khi Rank = 3 hoặc 4.**
    - Xác định giá trị $k_1, k_2$ để map beam cho các layer khác nhau (theo Table 5.2.2.2.2-2).

4.  **$i_{1,4}$ (Panel Co-phasing):**
    - Xác định hệ số đồng pha giữa các panel.
    - Cấu trúc phụ thuộc số panel:
        - Nếu $N_g = 2$: $i_{1,4} = [i_{1,4,1}]$.
        - Nếu $N_g = 4$: $i_{1,4} = [i_{1,4,1}, i_{1,4,2}, i_{1,4,3}]$.

### 6.2 Các tham số trong $i_2$
Tham số $i_2$ dùng để chọn beam (beam selection) và đồng pha phân cực (polarization co-phasing).

- **Với codebookMode = 1:**
    - $i_2$ là một giá trị đơn (scalar).
    - Ví dụ: $i_2 \in \{0, 1\}$ hoặc $\{0, 1, 2, 3\}$.

- **Với codebookMode = 2 (Chỉ $N_g=2$):**
    - $i_2$ phức tạp hơn, bao gồm nhiều phần tử con cho từng layer hoặc nhóm layer.
    - Ký hiệu: $i_2 = [i_{2,0}, i_{2,1}, \dots]$.

### 6.3 Tóm tắt Mapping tham số PMI
| Rank ($\nu$) | Thành phần của $i_1$ | Thành phần của $i_2$ |
| :--- | :--- | :--- |
| **1** | $i_{1,1}, i_{1,2}, i_{1,4}$ | $i_2$ |
| **2** | $i_{1,1}, i_{1,2}, i_{1,4}$ | $i_2$ (Mode 1) hoặc $i_{2,0}, i_{2,1} \dots$ (Mode 2) |
| **3, 4** | $i_{1,1}, i_{1,2}, \mathbf{i_{1,3}}, i_{1,4}$ | $i_2$ |

---

## 7. Cấu hình hạn chế (Restriction)

### 7.1 ng-n1-n2 Restriction
- Là một bitmap $a_{A_c-1}, \dots, a_0$.
- **Bit = 0**: Báo cáo PMI tương ứng bị cấm (không được dùng precoder đó).
- Tổng số bit: $A_c = N_1 O_1 N_2 O_2$.

### 7.2 ri-Restriction
- Là chuỗi bit $r_3, r_2, r_1, r_0$ tương ứng với 4 layer.
- **Bit $r_i$ = 0**: Cấm báo cáo RI = $i+1$.
- Ví dụ: Nếu $r_0 = 0 \to$ Không được báo cáo Rank 1.

---

## 8. CSI-RS Port Indexing

Các cổng antenna CSI-RS được đánh số bắt đầu từ 3000.
- Dải cổng: $3000$ đến $3000 + P_{CSI-RS} - 1$.
- Ví dụ: Với 8 ports, các cổng là $3000, 3001, \dots, 3007$.