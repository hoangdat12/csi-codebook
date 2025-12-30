# Type I Single-Panel Codebook – Parameter Description

Tài liệu này giải thích ý nghĩa các tham số được sử dụng trong **Type I Single-Panel codebook**
theo 3GPP TS 38.214, phục vụ cho việc đọc spec, implement code hoặc debug PMI.

---

## 1. Tổng quan

Type I Single-Panel codebook được sử dụng khi gNB và UE làm việc với **một panel anten duy nhất**.
UE không báo cáo trực tiếp ma trận precoding mà chỉ báo **PMI (Precoding Matrix Indicator)**,
tức là các **chỉ số** để gNB tái tạo lại ma trận precoding.

---

## 2. Các tham số cấu hình cao tầng (UE không report)

### N1
- Số phần tử anten theo **chiều azimuth (ngang)** của panel
- Được cấu hình bởi gNB
- Ảnh hưởng đến độ phân giải beam theo phương ngang

### N2
- Số phần tử anten theo **chiều elevation (dọc)** của panel
- Được cấu hình bởi gNB
- Nếu `N2 = 1` → panel 1D (ULA)

---

### O1
- Hệ số oversampling theo **azimuth**
- Quyết định số lượng beam có thể quét theo phương ngang

### O2
- Hệ số oversampling theo **elevation**
- Quyết định số lượng beam theo phương dọc
- Khi `N2 = 1` thì `O2` không có ý nghĩa thực tế

---

## 3. Các tham số UE báo cáo trong PMI

PMI gồm hai nhóm chỉ số chính: **i1** và **i2**

---

## 4. Nhóm i1 – Chỉ số hướng không gian (beam direction)

### i1,1 (l)
- Chỉ số beam theo **phương azimuth**
- Biểu diễn hướng phát chính của beam trên mặt phẳng ngang
- Giá trị lớn → beam lệch nhiều hơn so với trục trung tâm

---

### i1,2 (m)
- Chỉ số beam theo **phương elevation**
- Biểu diễn độ nghiêng của beam theo chiều dọc
- Chỉ có ý nghĩa khi `N2 > 1`
- Khi `N2 = 1` thì `i12` không được báo cáo nên `i12 = 0`

---

### i1,3
- Chỉ xuất hiện khi:
- Số layer (RI) = {2, 3, 4}
- Không phải là beam mới
- Dùng để **ánh xạ logic** sang các beam phụ khi tạo nhiều layer
- Việc ánh xạ cụ thể được quy định bằng bảng `Table 5.2.2.2.1-3` và `Table 5.2.2.2.1-4` trong spec

---

## 5. Nhóm i2 – Chỉ số pha (phase index)

### i2
- Chỉ số lựa chọn **pha tương đối** giữa các beam hoặc layer
- Dùng để cải thiện khả năng phân tách layer

> Lưu ý: hệ số mạnh nhất luôn có pha mặc định, UE **không báo cáo pha cho hệ số này**

---

## 6. RI (Rank Indicator)

- RI là số **layer truyền song song**
- RI quyết định:
  - UE report bao nhiêu chỉ số trong PMI
  - Có hay không sự xuất hiện của `i1,3`
  - Cấu trúc ma trận precoding tại gNB

---

## 7. Những tham số UE KHÔNG báo cáo

UE **không trực tiếp báo cáo**:
- N1, N2
- O1, O2
- Số CSI-RS ports
- Vector beam
- Ma trận precoding

Tất cả các thông tin trên được gNB suy ra từ:
- Cấu hình cao tầng
- PMI
- RI

---

## 8. Tóm tắt nhanh

| Tham số | Ý nghĩa |
|------|-------|
| N1 | Số anten theo azimuth |
| N2 | Số anten theo elevation |
| O1 | Oversampling azimuth |
| O2 | Oversampling elevation |
| i1,1 | Chỉ số beam azimuth |
| i1,2 | Chỉ số beam elevation |
| i1,3 | Chỉ số mapping cho multi-layer |
| i2 | Chỉ số pha |
| RI | Số layer |
| PMI | Tập chỉ số để dựng precoder |

---

## 9. Thông số ví dụ

- 1 Layer:
    - N1 = 2
    - N2 = 1
    - O1 = 4
    - O2 = 2
    - $$i_{1,1}$$ = 0
    - $$i_{1,2}$$ = 0
    - $$i_{2}$$ = 0

- 2 Layer:
    - N1 = 2
    - N2 = 1
    - O1 = 4
    - O2 = 1
    - $$i_{1,1}$$ = 0
    - $$i_{1,2}$$ = 0
    - $$i_{1,3}$$ = 1
    - $$i_{2}$$ = 1

- 1 Layer:
    - N1 = 8
    - N2 = 1
    - O1 = 4
    - O2 = 1
    - $$i_{1,1}$$ = 4
    - $$i_{1,2}$$ = 0
    - $$i_{2}$$ = 2

- 4 Layer:
    - N1 = 4
    - N2 = 2
    - O1 = 4
    - O2 = 2
    - $$i_{1,1}$$ = 2
    - $$i_{1,2}$$ = 1
    - $$i_{1,3}$$ = 0
    - $$i_{2}$$ = 0

---

## 10. Cách dùng các hàm

### validateInputs

---

## 11. Tài liệu tham khảo

- 3GPP TS 38.214  
  Section 5.2.2.2.1 – Type I Single-Panel Codebook
