# README – Giải thích các tham số Type-II Codebook (3GPP TS 38.214)

Tài liệu này giải thích **ý nghĩa, nguồn gốc và cách sử dụng** các tham số thường gặp khi hiện thực **Type-II CSI codebook** theo **3GPP TS 38.214 – mục 5.2.2.2.3**.

Phạm vi áp dụng cho cấu hình điển hình:

* Type-II codebook
* N1 × N2 antenna grid (ví dụ 4 × 4)
* L = numberOfBeams
* RI = 1 hoặc 2 (Type-II giới hạn RI ≤ 2)

---

## 1. Tổng quan luồng chỉ số

UE **không báo trực tiếp ma trận precoding W** mà báo các **chỉ số PMI** gồm hai nhóm:

* **i1**: chọn beam + amplitude chính
* **i2**: phase + subband amplitude

Từ các chỉ số này, gNB **tái tạo lại W**.

---

## 2. Nhóm chỉ số i1

```text
i1 = { i11, i12, i13, i14 }
```

### 2.1 i11 – Beam index theo chiều N1

**Ký hiệu trong spec**: $$i_{1,1}$$

**Miền giá trị**:

```text
0 … O1 − 1
```

**Ý nghĩa**:

* Chọn beam theo trục **N1** (horizontal / azimuth)
* Dùng để tạo chỉ số beam m1

**Công thức liên quan**:
$$m_1^{(i)} = O_1 n_1^{(i)} + q_1$$

**Lưu ý**:

* UE báo **L hoặc ν giá trị** (phụ thuộc RI)
* Không phải vị trí antenna

---

### 2.2 i12 – Beam index theo chiều N2

**Ký hiệu trong spec**: $$i_{1,2}$$

**Miền giá trị**:

$$i_{1,2} \in \{0, 1, \dots, \binom{N_1 N_2}{L} - 1\}$$

**Ý nghĩa**:

* Chọn beam theo trục **N2** (vertical / elevation)
* Dùng để tạo chỉ số beam m2

**Công thức**:
$$m_2^{(i)} = O_2 n_2^{(i)} + q_2$$

---

### 2.3 i13 – Strongest coefficient index

**Ký hiệu trong spec**: $$i_{1,3}$$

**Miền giá trị**:

```text
0 … (2L − 1)
```

**Ý nghĩa**:

* Xác định **hệ số mạnh nhất** trong tập 2L coefficients
* Với hệ số này:

  * Amplitude = 1 (mặc định)
  * Phase = 0
  * **Không được báo trong i14, i21, i22**

---

### 2.4 i14 – Amplitude coefficient indices

**Ký hiệu trong spec**: $$i_{1,4}$$

**Miền giá trị**:

```text
0 … 7
```

**Ý nghĩa**:

* Chỉ số biên độ của các coefficient còn lại
* Map sang giá trị biên độ thực theo **Table 5.2.2.2.3-2**

**Ví dụ mapping**:

| i14 | p(1) |
| --- | ---- |
| 7   | 1    |
| 6   | 1/2  |
| 5   | 1/4  |
| 4   | 1/8  |
| 0   | 0    |

**Số lượng phần tử**:

```text
2L − 1  (loại strongest coefficient)
```

**Lưu ý**:

* **Strongest coeffcient** không được báo và mặc định = 7.

---

## 3. Nhóm chỉ số i2

```text
i2 = { i21, i22 }
```

### 3.1 i21 – Phase coefficient indices

**Ký hiệu trong spec**: ( i_{2,1,l} )

**Miền giá trị**:

```text
0 … N_PSK − 1
```

**Ý nghĩa**:

* Quy định pha của mỗi coefficient

**Công thức pha**:
$$\phi = \frac{2\pi}{N_{PSK}} \cdot c$$

**Lưu ý**:

* Strongest coefficient **không có phase** (mặc định 0)
* UE báo cáo PMI cho GNB.
- Số lượng phần tử:  
$$\min(M_l, K^{(2)}) - 1$$
- Các phần tử trong nhóm này được báo cáo với **độ phân giải đầy đủ**.
- Miền giá trị của hệ số:
$$c_{l,i} \in \{0, 1, \dots, N_{PSK} - 1\}$$

- Số lượng phần tử:
$$M_l - \min(M_l, K^{(2)})$$

- Các phần tử này chỉ được báo cáo với **độ phân giải thấp hơn** nhằm giảm overhead phản hồi.
- Miền giá trị của hệ số:
$$c_{l,i} \in \{0, 1, 2, 3\}$$

- Số lượng phần tử:
$$2L - M_l$$

- Các phần tử này **không được UE báo cáo**.
- Tại phía gNB, các hệ số này được mặc định:
$$c_{l,i} = 0$$

---

### 3.2 i22 – Subband amplitude indices

**Điều kiện tồn tại**:

```text
subbandAmplitude = true
```

**Nếu subbandAmplitude = false**:
**i22** mặc định bằng 1 cho toàn bộ.

**Miền giá trị**:

```text
0 … 1
```

**Ý nghĩa**:

* Điều chỉnh biên độ phụ theo subband
* Map theo **Table 5.2.2.2.3-3**

**Amplitude cuối**:
$$a = p^{(1)} \cdot p^{(2)}$$

**Lưu ý**:

* UE báo cáo PMI cho GNB

Đối với mỗi lớp \(l\), các chỉ số nhị phân \(k_{l,i}^{(2)}\) được báo cáo theo nguyên tắc sau:

- Chỉ báo cáo:
$$\min(M_l, K^{(2)}) - 1$$
  phần tử.
- Các phần tử này tương ứng với **các hệ số mạnh nhất**, **ngoại trừ hệ số mạnh nhất tuyệt đối** có chỉ số $$i_{1,3,l}$$.

- Các phần tử được báo cáo có miền giá trị nhị phân:
$$k_{l,i}^{(2)} \in \{0, 1\}$$

- Số lượng phần tử không được báo cáo:
$$2L - \min(M_l, K^{(2)})$$

- Các phần tử này **không được UE báo cáo**.
- Tại phía gNB, các giá trị này được mặc định:
$$k_{l,i}^{(2)} = 1$$

---

## 4. Các biến nội bộ (UE không report)

### 4.1 n1, n2 – Beam position indices

* Xác định vị trí beam trong lưới N1 × N2
* Được **suy ra từ i11, i12 bằng ánh xạ tổ hợp**
* Dựa trên **Table 5.2.2.2.3-1 (Combinatorial coefficients)**

UE **không báo trực tiếp** n1, n2

---

### 4.2 m1, m2 – Beam indices thực

**Công thức**:
* $$m_1 = O_1 n_1 + q_1$$
* $$m_2 = O_2 n_2 + q_2$$

Dùng để sinh vector beam:
* $$u_{m_1,m_2}(n_1,n_2)$$

---

### 4.3 p1, p2 – Amplitude thực

* p1: từ i14 (Table 3-2)
* p2: từ i22 (Table 3-3)

**Amplitude cuối**:
$$a = p_1 \cdot p_2$$

---

## 5. Bảng tóm tắt nhanh

| Tham số | UE report | Ý nghĩa               |
| ------- | --------- | --------------------- |
| i11     | ✔         | Beam index N1         |
| i12     | ✔         | Beam index N2         |
| i13     | ✔         | Strongest coefficient |
| i14     | ✔         | Amplitude chính       |
| i21     | ✔         | Phase                 |
| i22     | ✔         | Subband amplitude     |
| n1, n2  | ✘         | Vị trí beam           |
| m1, m2  | ✘         | Beam thực             |
| p1, p2  | ✘         | Amplitude thực        |

---
## 6. UE input parameters (Type II Codebook)

* Ví dụ tập tham số CSI do UE báo cáo cho Codebook Type II:

```matlab
L = 4;          % Number of layers
NPsk = 8;       % PSK order for coefficient phase

N1 = 4; N2 = 4; % Antenna grid size
O1 = 4; O2 = 4; % Oversampling factors

% i1: Beam / basis indices
i11 = [2, 1];   % Beam index (dimension 1)
i12 = [2];      % Beam index (dimension 2)
i13 = [3, 1];   % Additional beam refinement indices
i14 = [ ...
  4, 6, 5, 0, 2, 3, 1;
  3, 2, 4, 1, 5, 6, 0
];

% i2: Coefficient indices
i21 = [ ...
  1, 3, 4, 2, 5, 7;
  2, 0, 5, 1, 4, 6
];               % Phase indices (0 … NPsk−1)

i22 = [ ...
  0, 1, 0, 1, 0;
  1, 1, 0, 0, 1
];               % Amplitude / group indices

i1 = {i11, i12, i13, i14};
i2 = {i21, i22};
```

---
## 7. Cách dùng các hàm

### validateInputs
**Mô tả**  
Kiểm tra tính hợp lệ của các tham số CSI do UE báo cáo.

**Input**
- `nLayers`: số layer truyền
- `sbAmplitude`: cấu hình biên độ theo subband
- `i1`: tập chỉ số beam `{i11, i12, i13, i14}`
- `i2`: tập chỉ số hệ số `{i21, i22}`

**Output**
- Không có (chỉ thực hiện kiểm tra)

---

### computeInputs
**Mô tả**  
Lấy các input **i11, i12, i13, i14, i21, i22** và format chuẩn để xử lý.

**Input**
- `L`: số layer
- `i1`: các chỉ số beam
- `i2`: các chỉ số hệ số

**Output**
- `i11`: chỉ số beam theo chiều N1
- `i12`: chỉ số beam theo chiều N2
- `i14`: các chỉ số beam bổ sung
- `i21`: chỉ số pha
- `i22`: chỉ số nhóm biên độ

**Example**

_Input_
```matlab
cfg = struct();

cfg.CodebookConfig.N1 = 4;
cfg.CodebookConfig.N2 = 4;
cfg.CodebookConfig.O1 = 4;
cfg.CodebookConfig.O2 = 4;

cfg.CodebookConfig.NumberOfBeams = 4;     % L
cfg.CodebookConfig.PhaseAlphabetSize = 8; % NPSK
cfg.CodebookConfig.SubbandAmplitude = true;
cfg.CodebookConfig.numLayers = 2;         % nLayers

i11 = [2, 1];
i12 = [2];
i13 = [3, 1];
i14 = [4, 6, 5, 0, 2, 3, 1 ; 3, 2, 4, 1, 5, 6, 0];
i21 = [1, 3, 4, 2, 5, 7 ; 2, 0, 5, 1, 4, 6];
i22 = [0, 1, 0, 1, 0 ; 1, 1, 0, 0, 1];

i1 = {i11, i12, i13, i14};
i2 = {i21, i22};
```

_Output_
```matlab
i11 = [2, 1]

i12 = [2]

i13 = 3

i14 = [4, 6, 5, 7, 0, 2, 3, 1;
       3, 7, 2, 4, 1, 5, 6, 0]

i21 = [1, 3, 4, 0, 0, 2, 5, 7;
       2, 0, 0, 5, 1, 4, 6, 0]

i22 = [0, 0, 1, 1, 1, 0, 1, 1;
       0, 1, 1, 0, 1, 1, 1, 1]
```

---

### computeN1N2
**Mô tả**  
Tính các chỉ số beam theo lưới anten.

**Input**
- `L`: số layer
- `N1`, `N2`: kích thước lưới anten
- `i12`: chỉ số beam theo chiều N2

**Output**
- `n1`: chỉ số beam theo chiều N1
- `n2`: chỉ số beam theo chiều N2

---

### mappingAmplitudesK1K2ToP1P2
**Mô tả**  
Ánh xạ chỉ số biên độ sang hệ số biên độ.

**Input**
- `i14`: chỉ số tổ hợp beam
- `i22`: chỉ số nhóm biên độ

**Output**
- `p1_li`: hệ số biên độ nhóm 1
- `p2_li`: hệ số biên độ nhóm 2

---

### computePhi
**Mô tả**  
Tính giá trị pha cho các hệ số precoding.

**Input**
- `i14`: chỉ số beam
- `i21`: chỉ số pha
- `L`: số layer
- `NPSK`: bậc PSK

**Output**
- `phi`: ma trận pha của các hệ số precoding

---
## 8. Tài liệu tham chiếu

* 3GPP TS 38.214

  * Section 5.2.2.2.3 – Type-II Codebook
  * Tables 5.2.2.2.3-1 → 5.2.2.2.3-5

---
