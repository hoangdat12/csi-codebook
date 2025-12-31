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

Mỗi báo cáo PMI được xác định bởi cặp chỉ số codebook $(i_1, i_2)$. Cấu trúc của các vector này thay đổi chính xác theo công thức dưới đây.

### 6.1 Vector $i_1$ (Wideband/Long-term)
Cấu trúc của $i_1$ phụ thuộc vào Rank ($\nu$) như sau:

$$
i_1 = 
\begin{cases} 
[i_{1,1}, \ i_{1,2}, \ i_{1,4}] & \text{khi } \nu = 1 \\
[i_{1,1}, \ i_{1,2}, \ i_{1,3}, \ i_{1,4}] & \text{khi } \nu \in \{2, 3, 4\}
\end{cases}
$$

**Giải thích các thành phần:**
1.  **$i_{1,1}$**: Beam index theo chiều $N_1$.
2.  **$i_{1,2}$**: Beam index theo chiều $N_2$.
3.  **$i_{1,3}$**: Chỉ số mapping layer (Có mặt trong vector khi Rank $\ge 2$).
4.  **$i_{1,4}$**: Chỉ số liên quan đến đồng pha panel (Xem mục 6.2).

### 6.2 Cấu trúc $i_{1,4}$ và $i_2$ theo codebookMode

#### Trường hợp A: codebookMode = 1
Khi `codebookMode` được đặt là '1', cấu trúc của $i_{1,4}$ phụ thuộc vào số lượng panel ($N_g$):

$$
i_{1,4} = 
\begin{cases} 
i_{1,4,1} & \text{khi } N_g = 2 \text{ (1 giá trị)} \\
[i_{1,4,1}, \ i_{1,4,2}, \ i_{1,4,3}] & \text{khi } N_g = 4 \text{ (3 giá trị)}
\end{cases}
$$

*(Trong mode này, $i_2$ thường là một giá trị đơn lẻ tùy theo bảng).*

#### Trường hợp B: codebookMode = 2
Khi `codebookMode` được đặt là '2', cấu trúc vector mở rộng như sau:

$$
\begin{aligned}
i_{1,4} &= [i_{1,4,1}, \ i_{1,4,2}] \\
i_2 &= [i_{2,0}, \ i_{2,1}, \ i_{2,2}]
\end{aligned}
$$

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

---

## 9. Ví dụ Minh Họa Giá Trị Báo Cáo (Examples)

Dưới đây là các ví dụ cụ thể về giá trị PMI ($i_1$) trong báo cáo thực tế, minh họa sự khác biệt khi thay đổi số panel ($N_g$) và số layer (Rank).

### Ví dụ 1: Cấu hình 2 Panel, Truyền 1 Layer (Rank 1)
**Cấu hình:**
- $N_g = 2$
- $N_1 = 4, N_2 = 1$ (Tổng 16 ports)
- `codebookMode` = 1
- **Rank ($\nu$) = 1**

**Giá trị báo cáo $i_1$:**
Do Rank = 1 nên vector không chứa $i_{1,3}$.
Do $N_g = 2$ (Mode 1) nên $i_{1,4}$ chỉ có 1 phần tử.

- $i_{1,1} = 1$ (Chọn beam index theo chiều ngang)
- $i_{1,2} = 0$ (Mặc định bằng 0 do $N_2=1$)
- $i_{1,4} = [1]$ (Hệ số pha giữa Panel 1 và Panel 2)

---

### Ví dụ 2: Cấu hình 4 Panel, Truyền 2 Layers (Rank 2)
**Cấu hình:**
- $N_g = 4$
- $N_1 = 2, N_2 = 1$ (Tổng 16 ports)
- `codebookMode` = 1 (Bắt buộc với $N_g=4$)
- **Rank ($\nu$) = 2**

**Giá trị báo cáo $i_1$:**
Do Rank = 2 nên vector **xuất hiện $i_{1,3}$** để map layer.
Do $N_g = 4$ nên $i_{1,4}$ bắt buộc phải là **vector 3 phần tử** $[i_{1,4,1}, i_{1,4,2}, i_{1,4,3}]$.

- $i_{1,1} = 2$
- $i_{1,2} = 0$
- **$i_{1,3} = 0$** (Chỉ số Layer Mapping, tra cứu bảng Table 5.2.2.2.1-3)
- **$i_{1,4} = [1, 0, 2]$** (Pha của 3 panel còn lại so với panel quy chiếu)

---

## 10. Cách dùng các hàm