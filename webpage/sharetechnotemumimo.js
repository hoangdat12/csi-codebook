/**
 * 5G NR Type I Single-Panel Codebook Visualizer (3GPP 38.214)
 * Dual-polarized DFT beamforming, Rank 1 and Rank 2.
 */
(function($) {
  'use strict';

  const PI = Math.PI;
  const TAU = 2 * PI;

  const Complex = {
    mul: (a, b) => ({ re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re }),
    add: (a, b) => ({ re: a.re + b.re, im: a.im + b.im }),
    exp: (phase) => ({ re: Math.cos(phase), im: Math.sin(phase) })
  };

  const CONFIGS = {
    '2,1': { N1: 2, N2: 1, O1: 4, O2: 1 },
    '2,2': { N1: 2, N2: 2, O1: 4, O2: 4 },
    '4,1': { N1: 4, N2: 1, O1: 4, O2: 1 },
    '4,2': { N1: 4, N2: 2, O1: 4, O2: 4 }
  };

  function getKOffsets_Layer3_4(i13, cfg) {
    const { N1, N2, O1, O2 } = cfg;
    const idx = parseInt(i13, 10) || 0;

    // Cấu hình N1 = 2, N2 = 1 (Chỉ có i1,3 = 0)
    if (N1 === 2 && N2 === 1) {
      return { k1: O1, k2: 0 }; 
    }
    
    // Cấu hình N1 = 4, N2 = 1 (i1,3 từ 0 đến 2)
    if (N1 === 4 && N2 === 1) {
      const map = [[O1, 0], [2 * O1, 0], [3 * O1, 0]];
      const validIdx = Math.min(Math.max(idx, 0), 2); // Chặn giá trị an toàn
      return { k1: map[validIdx][0], k2: map[validIdx][1] };
    }

    // Cấu hình N1 = 6, N2 = 1 (i1,3 từ 0 đến 3)
    if (N1 === 6 && N2 === 1) {
      const map = [[O1, 0], [2 * O1, 0], [3 * O1, 0], [4 * O1, 0]];
      const validIdx = Math.min(Math.max(idx, 0), 3);
      return { k1: map[validIdx][0], k2: map[validIdx][1] };
    }

    // Cấu hình N1 = 2, N2 = 2 (i1,3 từ 0 đến 2)
    if (N1 === 2 && N2 === 2) {
      const map = [[O1, 0], [0, O2], [O1, O2]];
      const validIdx = Math.min(Math.max(idx, 0), 2);
      return { k1: map[validIdx][0], k2: map[validIdx][1] };
    }

    // Cấu hình N1 = 3, N2 = 2 (i1,3 từ 0 đến 3)
    if (N1 === 3 && N2 === 2) {
      const map = [[O1, 0], [0, O2], [O1, O2], [2 * O1, 0]];
      const validIdx = Math.min(Math.max(idx, 0), 3);
      return { k1: map[validIdx][0], k2: map[validIdx][1] };
    }

    // Mặc định an toàn nếu không rơi vào các trường hợp trên
    return { k1: 0, k2: 0 };
  }

  /**
   * Table 5.2.2.2.1-3: Mapping of i1,3 to k1 and k2 for 2-layer CSI reporting.
   */
  function getKOffsets(i13, cfg) {
    const { N1, N2, O1, O2 } = cfg;
    const idx = parseInt(i13, 10) || 0;
    if (N1 > N2 && N2 > 1) {
      const map = [[0, 0], [O1, 0], [0, O2], [2 * O1, 0]];
      return { k1: map[idx][0], k2: map[idx][1] };
    }
    if (N1 === N2 && N1 > 1) {
      const map = [[0, 0], [O1, 0], [0, O2], [O1, O2]];
      return { k1: map[idx][0], k2: map[idx][1] };
    }
    if (N1 === 2 && N2 === 1) {
      const map = [[0, 0], [O1, 0]];
      return { k1: map[idx % 2][0], k2: 0 };
    }
    if (N1 > 2 && N2 === 1) {
      const map = [[0, 0], [O1, 0], [2 * O1, 0], [3 * O1, 0]];
      return { k1: map[Math.min(idx, 3)][0], k2: 0 };
    }
    return { k1: 0, k2: 0 };
  }

  /**
   * 3GPP 38.214: Table 5.2.2.2.1-5 (Rank 1) and 5.2.2.2.1-6 (Rank 2).
   * Rank 1 getIndices(i11, i12, i2) -> { l, m, n }. Rank 2 getIndices(i11, i12, i2, i13, cfg) -> { l, m, lp, mp, n }.
   */
  const CODEBOOK_TABLES = {
    '5.2.2.2.1-5': {
      '1-layer CSI (Mode 1)': {
        mode: 1,
        rank: 1,
        i2_max: 3,
        getIndices: function (i11, i12, i2) {
          return { l: i11, m: i12, n: i2 };
        }
      },
      '1-layer CSI (Mode 2, N2 > 1)': {
        mode: 2,
        rank: 1,
        i2_max: 15,
        getIndices: function (i11, i12, i2) {
          const k = (i2 >= 4 && i2 <= 7) || (i2 >= 12) ? 1 : 0;
          const s = (i2 >= 8) ? 1 : 0;
          const n = i2 % 4;
          return { l: 2 * i11 + k, m: 2 * i12 + s, n: n };
        }
      },
      '1-layer CSI (Mode 2, N2 = 1)': {
        mode: 2,
        rank: 1,
        i2_max: 15,
        getIndices: function (i11, i12, i2) {
          const k = Math.floor(i2 / 4);
          const n = i2 % 4;
          return { l: 2 * i11 + k, m: 0, n: n };
        }
      }
    },
    '5.2.2.2.1-6': {
      '2-layer CSI (Mode 1)': {
        mode: 1,
        rank: 2,
        i2_max: 1,
        getIndices: function (i11, i12, i2, i13, cfg) {
          const { k1, k2 } = getKOffsets(i13, cfg);
          return { l: i11, m: i12, lp: i11 + k1, mp: i12 + k2, n: i2 };
        }
      },
      '2-layer CSI (Mode 2, N2 > 1)': {
        mode: 2,
        rank: 2,
        i2_max: 7,
        getIndices: function (i11, i12, i2, i13, cfg) {
          const k_row = (i2 === 2 || i2 === 3 || i2 === 6 || i2 === 7) ? 1 : 0;
          const s_row = (i2 >= 4) ? 1 : 0;
          const n_val = i2 % 2;
          const { k1, k2 } = getKOffsets(i13, cfg);
          const l = 2 * i11 + k_row;
          const m = 2 * i12 + s_row;
          return { l, m, lp: l + k1, mp: m + k2, n: n_val };
        }
      },
      '2-layer CSI (Mode 2, N2 = 1)': {
        mode: 2,
        rank: 2,
        i2_max: 7,
        getIndices: function (i11, i12, i2, i13, cfg) {
          const k_offset = Math.floor(i2 / 2);
          const n_val = i2 % 2;
          const { k1 } = getKOffsets(i13, cfg);
          const l = 2 * i11 + k_offset;
          return { l, m: 0, lp: l + k1, mp: 0, n: n_val };
        }
      },
    },
    '5.2.2.2.1-7': {
      '3-layer CSI (Mode 1-2, P < 16)': {
        mode: 1, 
        rank: 3,
        i2_max: 1,
        getIndices: function (i11, i12, i2, i13, cfg) {
          // Áp dụng cho các cấu hình 4, 8 port (N1*N2 <= 4)
          const { k1, k2 } = getKOffsets_Layer3_4(i13, cfg);
          return { l: i11, m: i12, lp: i11 + k1, mp: i12 + k2, n: i2, isGe16: false };
        }
      },
      '3-layer CSI (Mode 1-2, P >= 16)': {
        mode: 1,
        rank: 3,
        i2_max: 1,
        getIndices: function (i11, i12, i2, i13, cfg) {
          // Áp dụng cho các cấu hình 16, 32 port.
          // Trả về p thay vì lp, mp. Phải xử lý isGe16: true ở calculatePrecoder
          return { l: i11, m: i12, p: i13, n: i2, isGe16: true };
        }
      }
    },
    '5.2.2.2.1-8': {
      '4-layer CSI (Mode 1-2, P < 16)': {
        mode: 1,
        rank: 4,
        i2_max: 1,
        getIndices: function (i11, i12, i2, i13, cfg) {
          // Áp dụng cho các cấu hình 4, 8 port
          const { k1, k2 } = getKOffsets_Layer3_4(i13, cfg);
          return { l: i11, m: i12, lp: i11 + k1, mp: i12 + k2, n: i2, isGe16: false };
        }
      },
      '4-layer CSI (Mode 1-2, P >= 16)': {
        mode: 1,
        rank: 4,
        i2_max: 1,
        getIndices: function (i11, i12, i2, i13, cfg) {
          // Áp dụng cho các cấu hình 16, 32 port.
          return { l: i11, m: i12, p: i13, n: i2, isGe16: true };
        }
      }
    }
  };

  /** Feasible single-panel configs up to 32 ports (p = 2*N1*N2). Used for Config dropdown filtering. */
  const ALL_CONFIGS = {
    '2,1': { N1: 2, N2: 1, O1: 4, O2: 1, p: 4 },
    '4,1': { N1: 4, N2: 1, O1: 4, O2: 1, p: 8 },
    '8,1': { N1: 8, N2: 1, O1: 4, O2: 1, p: 16 },
    '16,1': { N1: 16, N2: 1, O1: 4, O2: 1, p: 32 },
    '2,2': { N1: 2, N2: 2, O1: 4, O2: 4, p: 8 },
    '4,2': { N1: 4, N2: 2, O1: 4, O2: 4, p: 16 },
    '8,2': { N1: 8, N2: 2, O1: 4, O2: 4, p: 32 },
    '2,4': { N1: 2, N2: 4, O1: 4, O2: 4, p: 16 },
    '4,4': { N1: 4, N2: 4, O1: 4, O2: 4, p: 32 }
  };

  let polarScaleAzimuth = 'linear';
  let polarScaleElevation = 'linear';
  let currentBottomPlane = 'azimuth';
  const POLAR_DB_FLOOR = -40;

  function getConfig() {
    const key = $('#cb5g-config').val();
    const cfg = ALL_CONFIGS[key] || CONFIGS[key] || ALL_CONFIGS['4,2'] || CONFIGS['2,2'];

    const i11 = parseInt($('#cb5g-i11').val(), 10);
    const i12 = parseInt($('#cb5g-i12').val(), 10);
    const i2 = parseInt($('#cb5g-i2').val(), 10);
    const i13 = parseInt($('#cb5g-i13').val(), 10);
    const rank = parseInt($('#cb5g-rank').val(), 10);
    return { ...cfg, i11, i12, i2, i13: isNaN(i13) ? 0 : i13, rank };
  }

  function getTableLogic() {
    const tableKey = $('#cb5g-table-select').val();
    const subKey = $('#cb5g-subtable-select').val();
    if (!tableKey || !subKey || !CODEBOOK_TABLES[tableKey] || !CODEBOOK_TABLES[tableKey][subKey]) {
      const t = Object.keys(CODEBOOK_TABLES)[0];
      const s = t && Object.keys(CODEBOOK_TABLES[t])[0];
      return (t && s) ? CODEBOOK_TABLES[t][s] : null;
    }
    return CODEBOOK_TABLES[tableKey][subKey];
  }

  /**
   * Steering vector per 3GPP 38.214: u_m (N2-dim) then v_l,m = Kronecker expansion.
   * l = i11 (horizontal beam index), m = i12 (vertical beam index).
   */
  function getSteeringVector(N1, N2, O1, O2, l, m) {
    // 1. Vertical vector u_m (N2 dimension)
    const um = [];
    if (N2 === 1) {
      um.push({ re: 1, im: 0 });
    } else {
      for (let n2 = 0; n2 < N2; n2++) {
        const phase = (2 * PI * m * n2) / (O2 * N2);
        um.push(Complex.exp(phase));
      }
    }

    // 2. 2D beam vector v_l,m: Kronecker (e^(j*2*pi*l*n1/(O1*N1)) * u_m for each n1)
    const v_lm = [];
    for (let n1 = 0; n1 < N1; n1++) {
      const outerPhase = (2 * PI * l * n1) / (O1 * N1);
      const outerExp = Complex.exp(outerPhase);
      for (let i = 0; i < um.length; i++) {
        v_lm.push(Complex.mul(outerExp, um[i]));
      }
    }
    return v_lm;
  }

  /**
   * Precoder weights via selected 3GPP table.
   * Rank 1: getIndices(i11, i12, i2) -> { l, m, n }; W = [v_lm; phi_n*v_lm].
   * Rank 2: getIndices(i11, i12, i2, i13, cfg) -> { l, m, lp, mp, n }; Layer1 = [v_lm; phi_n*v_lm], Layer2 = [v_lpmp; -phi_n*v_lpmp].
   */
  function calculatePrecoder() {
    const rootCfg = getConfig();
    const tableLogic = getTableLogic();

    // Lấy giá trị PMI từ 2 ô input
    const PMIUE1 = parseInt($('#cb5g-pmi-global-ue1').val(), 10) || 0;
    const PMIUE2 = parseInt($('#cb5g-pmi-global-ue2').val(), 10) || 0;

    // Hàm nội bộ để tính toán Precoder Data (layer1, layer2...) cho một UE cụ thể
    // Dựa trên các tham số cấu hình (N1, N2, i11, i12, v.v.)
    function computePrecoderDataForUE(cfgParams) {
        if (!tableLogic) {
            const v_lm = getSteeringVector(cfgParams.N1, cfgParams.N2, cfgParams.O1, cfgParams.O2, cfgParams.i11, cfgParams.i12);
            const phi_n = Complex.exp((PI * cfgParams.i2) / 2);
            const layer1 = [];
            v_lm.forEach(function (v) { layer1.push(v); });
            v_lm.forEach(function (v) { layer1.push(Complex.mul(v, phi_n)); });
            
            const layer2 = cfgParams.rank === 2 
                ? v_lm.map(function (v) { return v; }).concat(v_lm.map(function (v) { return Complex.mul(v, { re: -phi_n.re, im: -phi_n.im }); })) 
                : null;
                
            return { layer1: layer1, layer2: layer2, N1: cfgParams.N1, N2: cfgParams.N2 };
        }

        if (tableLogic.rank == 1 || tableLogic.rank == 2) {
            if (tableLogic.rank === 2) {
                const i13 = parseInt(cfgParams.i13, 10) || 0;
                const idx = tableLogic.getIndices(cfgParams.i11, cfgParams.i12, cfgParams.i2, i13, cfgParams);
                const v_lm = getSteeringVector(cfgParams.N1, cfgParams.N2, cfgParams.O1, cfgParams.O2, idx.l, idx.m);
                const v_lpmp = getSteeringVector(cfgParams.N1, cfgParams.N2, cfgParams.O1, cfgParams.O2, idx.lp, idx.mp);
                const phi_n = Complex.exp((PI * idx.n) / 2);
                const neg_phi_n = { re: -phi_n.re, im: -phi_n.im };
                const layer1 = v_lm.concat(v_lm.map(function (v) { return Complex.mul(v, phi_n); }));
                const layer2 = v_lpmp.concat(v_lpmp.map(function (v) { return Complex.mul(v, neg_phi_n); }));
                return { layer1: layer1, layer2: layer2, N1: cfgParams.N1, N2: cfgParams.N2 };
            }

            const { l, m, n } = tableLogic.getIndices(cfgParams.i11, cfgParams.i12, cfgParams.i2);
            const v_lm = getSteeringVector(cfgParams.N1, cfgParams.N2, cfgParams.O1, cfgParams.O2, l, m);
            const phi_n = Complex.exp((PI * n) / 2);
            const layer1 = [];
            v_lm.forEach(function (v) { layer1.push(v); });
            v_lm.forEach(function (v) { layer1.push(Complex.mul(v, phi_n)); });
            return { layer1: layer1, layer2: null, N1: cfgParams.N1, N2: cfgParams.N2 };
            
        } else {
            // Xử lý cho Rank 3 và Rank 4
            const i13 = parseInt(cfgParams.i13, 10) || 0;
            const idx = tableLogic.getIndices(cfgParams.i11, cfgParams.i12, cfgParams.i2, i13, cfgParams);
            const phi_n = Complex.exp((PI * idx.n) / 2);
            const neg_phi_n = { re: -phi_n.re, im: -phi_n.im };

            if (idx.isGe16) {
                // Trường hợp P_CSIRS >= 16: ma trận 4 khối với v_tilde
                const v_tilde = getSteeringVector(cfgParams.N1 / 2, cfgParams.N2, cfgParams.O1, cfgParams.O2, idx.l, idx.m);
                const theta_p = Complex.exp((PI * idx.p) / 4);
                const neg_theta_p = { re: -theta_p.re, im: -theta_p.im };
                const phi_theta = Complex.mul(phi_n, theta_p);
                const neg_phi_theta = { re: -phi_theta.re, im: -phi_theta.im };

                const layer1 = [], layer2 = [], layer3 = [], layer4 = [];

                if (tableLogic.rank === 3) {
                    v_tilde.forEach(function (v) { layer1.push(v); layer2.push(v); layer3.push(v); });
                    v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, theta_p)); layer2.push(Complex.mul(v, neg_theta_p)); layer3.push(Complex.mul(v, theta_p)); });
                    v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, phi_n)); layer2.push(Complex.mul(v, phi_n)); layer3.push(Complex.mul(v, neg_phi_n)); });
                    v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, phi_theta)); layer2.push(Complex.mul(v, neg_phi_theta)); layer3.push(Complex.mul(v, neg_phi_theta)); });
                    return { layer1: layer1, layer2: layer2, layer3: layer3, layer4: null, N1: cfgParams.N1, N2: cfgParams.N2 };
                }

                if (tableLogic.rank === 4) {
                    v_tilde.forEach(function (v) { layer1.push(v); layer2.push(v); layer3.push(v); layer4.push(v); });
                    v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, theta_p)); layer2.push(Complex.mul(v, neg_theta_p)); layer3.push(Complex.mul(v, theta_p)); layer4.push(Complex.mul(v, neg_theta_p)); });
                    v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, phi_n)); layer2.push(Complex.mul(v, phi_n)); layer3.push(Complex.mul(v, neg_phi_n)); layer4.push(Complex.mul(v, neg_phi_n)); });
                    v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, phi_theta)); layer2.push(Complex.mul(v, neg_phi_theta)); layer3.push(Complex.mul(v, neg_phi_theta)); layer4.push(Complex.mul(v, phi_theta)); });
                    return { layer1: layer1, layer2: layer2, layer3: layer3, layer4: layer4, N1: cfgParams.N1, N2: cfgParams.N2 };
                }
            } else {
                // Trường hợp P_CSIRS < 16: ghép mảng như Rank 2
                const v_lm = getSteeringVector(cfgParams.N1, cfgParams.N2, cfgParams.O1, cfgParams.O2, idx.l, idx.m);
                const v_lpmp = getSteeringVector(cfgParams.N1, cfgParams.N2, cfgParams.O1, cfgParams.O2, idx.lp, idx.mp);
                const layer1 = v_lm.concat(v_lm.map(function (v) { return Complex.mul(v, phi_n); }));
                const layer2 = v_lpmp.concat(v_lpmp.map(function (v) { return Complex.mul(v, phi_n); }));
                const layer3 = v_lm.concat(v_lm.map(function (v) { return Complex.mul(v, neg_phi_n); }));
                let layer4 = null;

                if (tableLogic.rank === 4) {
                    layer4 = v_lpmp.concat(v_lpmp.map(function (v) { return Complex.mul(v, neg_phi_n); }));
                }
                return { layer1: layer1, layer2: layer2, layer3: layer3, layer4: layer4, N1: cfgParams.N1, N2: cfgParams.N2 };
            }
        }
    }

    // 1. Chuyển đổi PMI thành các thông số i11, i12, i2, i13... cho UE1
    const resultUE1 = convertPMIToValues(
        rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, tableLogic.rank, tableLogic.mode, PMIUE1
    );
    
    // Gộp rootCfg mặc định với các tham số mới tính toán từ PMIUE1
    const cfgUE1 = Object.assign({}, rootCfg, resultUE1);

    // 2. Chuyển đổi PMI thành các thông số i11, i12, i2, i13... cho UE2
    const resultUE2 = convertPMIToValues(
        rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, tableLogic.rank, tableLogic.mode, PMIUE2
    );
    
    // Gộp rootCfg mặc định với các tham số mới tính toán từ PMIUE2
    const cfgUE2 = Object.assign({}, rootCfg, resultUE2);

    // 3. Tính toán data (layer arrays) cho cả 2 UE
    const dataUE1 = computePrecoderDataForUE(cfgUE1);
    const dataUE2 = computePrecoderDataForUE(cfgUE2);

    // 4. Trả về mảng chứa precoder data của 2 UE
    // (Mảng này chính là mảng `dataUEs` được truyền vào `renderBottomRowPolars` ở phần trước)
    return [dataUE1, dataUE2];
  }

  /**
   * Array factor at (theta, phi) with physical coordinate mapping per 38.214.
   * Orthogonal polarizations: total power = |Pol0|^2 + |Pol1|^2 so i2 (co-phase) does not null the beam.
   * weights[] order: [Pol0: (n1,n2)... Pol1: (n1,n2)...]. N1 = horizontal (X), N2 = vertical (Z).
   */
  function calculateGain(theta, phi, weights, N1, N2) {
    var pol0Re = 0, pol0Im = 0, pol1Re = 0, pol1Im = 0;
    var nPortsPerPol = N1 * N2;

    for (var n1 = 0; n1 < N1; n1++) {
      for (var n2 = 0; n2 < N2; n2++) {
        var spatialPhase = PI * (n1 * Math.sin(theta) * Math.cos(phi) + n2 * Math.cos(theta));
        var e = Complex.exp(spatialPhase);

        var t0 = Complex.mul(weights[(n1 * N2) + n2], e);
        pol0Re += t0.re;
        pol0Im += t0.im;

        var t1 = Complex.mul(weights[nPortsPerPol + (n1 * N2) + n2], e);
        pol1Re += t1.re;
        pol1Im += t1.im;
      }
    }
    var totalPower = (pol0Re * pol0Re + pol0Im * pol0Im) + (pol1Re * pol1Re + pol1Im * pol1Im);
    return Math.sqrt(totalPower) / (2 * N1 * N2);
  }


  let scene;
 
  function drawPolarPlot(canvasId, type, data) {
    const canvas = document.getElementById(canvasId);
    if (!canvas || !data) return;
    
    // Đưa data về dạng mảng để xử lý chung (dù là 1 hay 2 UE)
    const dataArray = Array.isArray(data) ? data : [data];
    if (dataArray.length === 0 || !dataArray[0].layer1) return;

    const parent = canvas.parentElement;
    if (!parent || !parent.clientWidth) return;

    const w = (canvas.width = parent.clientWidth);
    const h = (canvas.height = parent.clientHeight);
    const center = { x: w / 2, y: h / 2 };
    const radius = Math.min(w, h) * 0.38;
    const ctx = canvas.getContext('2d');
    
    ctx.clearRect(0, 0, w, h);

    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1;
    for (let r = 0.2; r <= 1; r += 0.2) {
        ctx.beginPath();
        ctx.arc(center.x, center.y, radius * r, 0, TAU);
        ctx.stroke();
    }
    for (let a = 0; a < TAU; a += PI / 4) {
        ctx.beginPath();
        ctx.moveTo(center.x, center.y);
        ctx.lineTo(center.x + radius * Math.cos(a), center.y + radius * Math.sin(a));
        ctx.stroke();
    }

    function getRadius(gain) {
        const scaleMode = (type === 'azimuth') ? polarScaleAzimuth : polarScaleElevation;
        if (scaleMode === 'dB') {
            const dB = 20 * Math.log10(Math.max(gain, 1e-10));
            return Math.max(0, Math.min(1, (dB - POLAR_DB_FLOOR) / (0 - POLAR_DB_FLOOR))) * radius;
        }
        return gain * radius;
    }

    const ueColors = [
        { // Màu cho UE 1 (Azimuth: Xanh dương, Elevation: Đỏ)
            azimuthFill: 'rgba(68,136,255,0.15)',   azimuthStroke: '#4488ff',
            elevationFill: 'rgba(255,68,68,0.15)',  elevationStroke: '#ff4444'
        },
        { // Màu cho UE 2 (Azimuth: Xanh lá, Elevation: Cam)
            azimuthFill: 'rgba(68,204,68,0.15)',    azimuthStroke: '#44cc44',
            elevationFill: 'rgba(255,170,51,0.15)', elevationStroke: '#ffaa33'
        }
    ];

    dataArray.forEach((ueData, index) => {
        if (!ueData || !ueData.layer1) return;

        const steps = 180;
        const layerPoints = { total: [], l1: [], l2: [], l3: [], l4: [] };

        // Lấy tọa độ cho UE hiện tại
        for (let i = 0; i <= steps; i++) {
            let theta, phi;
            if (type === 'azimuth') {
                theta = PI / 2;
                phi = (i / steps) * TAU;
            } else {
                theta = (i / steps) * PI;
                phi = 0;
            }
            const g1 = calculateGain(theta, phi, ueData.layer1, ueData.N1, ueData.N2);
            const g2 = ueData.layer2 ? calculateGain(theta, phi, ueData.layer2, ueData.N1, ueData.N2) : 0;
            const g3 = ueData.layer3 ? calculateGain(theta, phi, ueData.layer3, ueData.N1, ueData.N2) : 0;
            const g4 = ueData.layer4 ? calculateGain(theta, phi, ueData.layer4, ueData.N1, ueData.N2) : 0;
            const gTotal = Math.sqrt(g1 * g1 + g2 * g2 + g3 * g3 + g4 * g4);
            const angle = (type === 'azimuth') ? phi : theta - PI / 2;
            function getXY(g) {
                const rad = getRadius(g);
                return { x: center.x + rad * Math.cos(angle), y: center.y + rad * Math.sin(angle) };
            }
            layerPoints.total.push(getXY(gTotal));
            layerPoints.l1.push(getXY(g1));
            if (ueData.layer2) layerPoints.l2.push(getXY(g2));
            if (ueData.layer3) layerPoints.l3.push(getXY(g3));
            if (ueData.layer4) layerPoints.l4.push(getXY(g4));
        }
        const colors = ueColors[index % ueColors.length];
        const baseStrokeColor = (type === 'azimuth') ? colors.azimuthStroke : colors.elevationStroke;
        ctx.beginPath();
        layerPoints.total.forEach((p, i) => i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y));
        ctx.closePath();
        ctx.fillStyle = (type === 'azimuth') ? colors.azimuthFill : colors.elevationFill;
        ctx.fill();
        ctx.strokeStyle = baseStrokeColor;
        ctx.lineWidth = 2;
        ctx.setLineDash([]);
        ctx.stroke();
        ctx.setLineDash([3, 3]);
        ctx.lineWidth = 1;
        ctx.strokeStyle = baseStrokeColor; // <--- TẤT CẢ LAYER CÙNG 1 MÀU
        ctx.beginPath();
        layerPoints.l1.forEach((p, i) => i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y));
        ctx.stroke();
        if (ueData.layer2) {
            ctx.beginPath();
            layerPoints.l2.forEach((p, i) => i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y));
            ctx.stroke();
        }
        if (ueData.layer3) {
            ctx.beginPath();
            layerPoints.l3.forEach((p, i) => i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y));
            ctx.stroke();
        }
        if (ueData.layer4) {
            ctx.beginPath();
            layerPoints.l4.forEach((p, i) => i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y));
            ctx.stroke();
        }

        ctx.setLineDash([]); 
    });
  }

  function updateScaleButtonIcons() {
    ['polarAzimuth', 'polarElevation'].forEach(function (id) {
      const btn = document.getElementById(id + 'ScaleBtn');
      if (!btn) return;
      const scale = (id === 'polarAzimuth') ? polarScaleAzimuth : polarScaleElevation;
      const lin = btn.querySelector('.cb5g-icon-lin');
      const db = btn.querySelector('.cb5g-icon-db');
      if (lin && db) {
        lin.style.display = scale === 'dB' ? '' : 'none';
        db.style.display = scale === 'linear' ? '' : 'none';
      }
    });
  }

  function update2DPlots(data) {
    const logic = getTableLogic();
    if (!data) data = calculatePrecoder();
    drawPolarPlot('polarAzimuth', 'azimuth', data);
    drawPolarPlot('polarElevation', 'elevation', data);
    renderBottomLayers(logic?.rank ? logic.rank : 4, data);
  }

  function updateMeshes() {
    const data = calculatePrecoder();

    if (!scene) {
      update2DPlots(data);
      return;
    }

    update2DPlots(data);
  }

  function convertPMIToValues(N1, N2, O1, O2, nLayers, codebookMode, PMI) {
    const { idx11_end, idx12_end, idx13_end, idx2_end } = findRangeValues(N1, N2, O1, O2, nLayers, codebookMode);
    let lookupTable = genLookupTable(idx11_end, idx12_end, idx13_end, idx2_end);
    return {
      i11: lookupTable?.i11_lookup[PMI],
      i12: lookupTable?.i12_lookup[PMI],
      i13: lookupTable?.i13_lookup[PMI],
      i2: lookupTable?.i2_lookup[PMI]
    }
  }

  function genLookupTable(idx11_end, idx12_end, idx13_end, idx2_end) {
    const N = (idx11_end + 1) * (idx12_end + 1) * (idx13_end + 1) * (idx2_end + 1);

    const i11_lookup = new Array(N);
    const i12_lookup = new Array(N);
    const i13_lookup = new Array(N);
    const i2_lookup  = new Array(N);

    let n = 0;
    for (let idx11 = 0; idx11 <= idx11_end; idx11++) {
      for (let idx12 = 0; idx12 <= idx12_end; idx12++) {
        for (let idx13 = 0; idx13 <= idx13_end; idx13++) {
          for (let idx2 = 0; idx2 <= idx2_end; idx2++) {
            i11_lookup[n] = idx11;
            i12_lookup[n] = idx12;
            i13_lookup[n] = idx13;
            i2_lookup[n]  = idx2;
            n++;
          }
        }
      }
    }

    return { i11_lookup, i12_lookup, i13_lookup, i2_lookup };
  }

  function findRangeValues(N1, N2, O1, O2, nLayers, codebookMode) {
    let idx11_end = 0;
    let idx12_end = 0;
    let idx13_end = 0;
    let idx2_end  = 0;

    switch (nLayers) {
      case 1:
        idx13_end = 0;
        if (codebookMode === 1) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = (N2 * O2) - 1;
          idx2_end  = 3;
        } else if (codebookMode === 2) {
          idx11_end = (N1 * O1) / 2 - 1;
          idx12_end = N2 > 1 ? (N2 * O2) / 2 - 1 : 0;
          idx2_end  = 15;
        } else {
          console.warn("Invalid codebookMode for layer 1!");
        }
        break;

      case 2:
        if (codebookMode === 1) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = (N2 * O2) - 1;
          idx2_end  = 1;
        } else if (codebookMode === 2) {
          idx11_end = (N1 * O1) / 2 - 1;
          idx12_end = N2 > 1 ? (N2 * O2) / 2 - 1 : 0;
          idx2_end  = 7;
        } else {
          console.warn("Invalid codebookMode for layer 2!");
        }
        idx13_end = findRangeValueOfI13Layer2(N1, N2);
        break;

      case 3: {
        const nPorts = 2 * N1 * N2;
        if (nPorts < 16) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = (N2 * O2) - 1;
          idx13_end = findRangeValueOfI13Layer34(N1, N2);
          idx2_end  = 1;
        } else {
          idx11_end = (N1 * O1) / 2 - 1;
          idx12_end = (N2 * O2) - 1;
          idx13_end = 3;
          idx2_end  = 1;
        }
        break;
      }

      case 4: {
        const nPorts = 2 * N1 * N2;
        if (nPorts < 16) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = (N2 * O2) - 1;
          idx13_end = findRangeValueOfI13Layer34(N1, N2);
          idx2_end  = 1;
        } else {
          idx11_end = (N1 * O1) / 2 - 1;
          idx12_end = (N2 * O2) - 1;
          idx13_end = 3;
          idx2_end  = 1;
        }
        break;
      }

      case 5:
        idx13_end = 0;
        if (N2 > 1) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = (N2 * O2) - 1;
          idx2_end  = 1;
        } else if (N1 > 2 && N2 === 1) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = 0;
          idx2_end  = 1;
        } else {
          console.warn("Invalid parameters for layer 5!");
        }
        break;

      case 6:
        idx13_end = 0;
        if (N2 > 1) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = (N2 * O2) - 1;
          idx2_end  = 1;
        } else if (N1 > 2 && N2 === 1) {
          idx11_end = (N1 * O1) - 1;
          idx12_end = 0;
          idx2_end  = 1;
        } else {
          console.warn("Invalid parameters for layer 6!");
        }
        break;

      case 7:
        idx13_end = 0;
        idx2_end  = 1;
        if      (N1 === 4 && N2 === 1) { idx11_end = (N1 * O1 / 2) - 1; idx12_end = 0; }
        else if (N1 >  4 && N2 === 1) { idx11_end = (N1 * O1)     - 1; idx12_end = 0; }
        else if (N1 === 2 && N2 === 2) { idx11_end = (N1 * O1)     - 1; idx12_end = (N2 * O2)     - 1; }
        else if (N1 >  2 && N2 === 2) { idx11_end = (N1 * O1)     - 1; idx12_end = (N2 * O2 / 2) - 1; }
        else if (N1 >  2 && N2 >  2) { idx11_end = (N1 * O1)     - 1; idx12_end = (N2 * O2)     - 1; }
        else { console.warn("Invalid parameters for layer 7!"); }
        break;

      case 8:
        idx13_end = 0;
        idx2_end  = 1;
        if      (N1 === 4 && N2 === 1) { idx11_end = (N1 * O1 / 2) - 1; idx12_end = 0; }
        else if (N1 >  4 && N2 === 1) { idx11_end = (N1 * O1)     - 1; idx12_end = 0; }
        else if (N1 === 2 && N2 === 2) { idx11_end = (N1 * O1)     - 1; idx12_end = (N2 * O2)     - 1; }
        else if (N1 >  2 && N2 === 2) { idx11_end = (N1 * O1)     - 1; idx12_end = (N2 * O2 / 2) - 1; }
        else if (N1 >  2 && N2 >  2) { idx11_end = (N1 * O1)     - 1; idx12_end = (N2 * O2)     - 1; }
        else { console.warn("Invalid parameters for layer 8!"); }
        break;

      default:
        console.warn("Unsupported nLayers:", nLayers);
    }

    return { idx11_end, idx12_end, idx13_end, idx2_end };
  }

  function findRangeValueOfI13Layer2(N1, N2) {
    return (N1 === 2 && N2 === 1) ? 1 : 3;
  }

  function findRangeValueOfI13Layer34(N1, N2) {
    const nPorts = 2 * N1 * N2;
    if (nPorts >= 16) return 3;

    if      (N1 === 2 && N2 === 1)                           return 0;
    else if ((N1 === 4 && N2 === 1) || (N1 === 2 && N2 === 2)) return 2;
    else if ((N1 === 6 && N2 === 1) || (N1 === 3 && N2 === 2)) return 3;
    else return 0;
  }

  /** Filter Config (N1 x N2) by sub-table text (N2, Ports) */
  function populateConfigDropdown(subTableKey) {
    const $sel = $('#cb5g-config');
    if (!$sel.length) return;
    const currentVal = $sel.val();
    $sel.empty();
    
    // Bắt các điều kiện lọc từ tên của sub-table
    const isN2One = subTableKey && (subTableKey.indexOf('N2 = 1') !== -1 || subTableKey.indexOf('N2=1') !== -1);
    const isN2GtOne = subTableKey && subTableKey.indexOf('N2 > 1') !== -1;
    const isPLt16 = subTableKey && subTableKey.indexOf('P < 16') !== -1;
    const isPGe16 = subTableKey && subTableKey.indexOf('P >= 16') !== -1;

    Object.keys(ALL_CONFIGS).forEach(function (key) {
      const c = ALL_CONFIGS[key];
      // Bỏ qua nếu không thỏa mãn N2
      if (isN2One && c.N2 !== 1) return;
      if (isN2GtOne && c.N2 <= 1) return;
      
      // Bỏ qua nếu không thỏa mãn số Port (P) cho Rank 3 và 4
      if (isPLt16 && c.p >= 16) return;
      if (isPGe16 && c.p < 16) return;

      $sel.append($('<option></option>').attr('value', key).text(c.N1 + 'x' + c.N2 + ' (' + c.p + ' p)'));
    });
    
    if ($sel.find('option[value="' + currentVal + '"]').length) $sel.val(currentVal);
    else $sel.prop('selectedIndex', 0);
    $sel.trigger('change');
  }

  function drawSingleLayerPolar(canvasId, type, dataArray, layerIndex) {
    const canvas = document.getElementById(canvasId);
    if (!canvas || !dataArray || dataArray.length === 0) return;

    // Lấy kích thước thực tế bằng getBoundingClientRect để chống lỗi bóp méo của Flexbox
    const parent = canvas.parentElement;
    if (!parent) return;
    const rect = parent.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const w = (canvas.width = rect.width);
    const h = (canvas.height = rect.height);
    const center = { x: w / 2, y: h / 2 };
    const radius = Math.min(w, h) * 0.38;
    const ctx = canvas.getContext('2d');
    
    // Xóa toàn bộ canvas trước khi vẽ
    ctx.clearRect(0, 0, w, h);

    // ==========================================
    // 1. VẼ LƯỚI POLAR GRID
    // ==========================================
    ctx.strokeStyle = '#e0e0e0'; // Màu lưới nhạt
    ctx.lineWidth = 1;
    ctx.setLineDash([]); // Đảm bảo lưới vẽ bằng nét liền

    // Vẽ các vòng tròn đồng tâm
    for (let r = 0.2; r <= 1; r += 0.2) {
        ctx.beginPath();
        ctx.arc(center.x, center.y, radius * r, 0, 2 * Math.PI); 
        ctx.stroke();
    }
    // Vẽ các đường chéo xuyên tâm
    for (let a = 0; a < 2 * Math.PI; a += Math.PI / 4) {
        ctx.beginPath();
        ctx.moveTo(center.x, center.y);
        ctx.lineTo(center.x + radius * Math.cos(a), center.y + radius * Math.sin(a));
        ctx.stroke();
    }

    // Hàm tính bán kính nội bộ
    function getRadius(gain) {
        const scaleMode = (type === 'azimuth') ? polarScaleAzimuth : polarScaleElevation;
        if (scaleMode === 'dB') {
            const dB = 20 * Math.log10(Math.max(gain, 1e-10));
            return Math.max(0, Math.min(1, (dB - POLAR_DB_FLOOR) / (0 - POLAR_DB_FLOOR))) * radius;
        }
        return gain * radius;
    }

    // ==========================================
    // 2. BẢNG MÀU CHUNG (1 MÀU DUY NHẤT CHO MỖI LAYER)
    // ==========================================
    const layerColorMap = {
        1: { fill: 'rgba(68, 136, 255, 0.2)', stroke: '#4488ff' }, // Layer 1: Xanh dương
        2: { fill: 'rgba(255, 68, 68, 0.2)',  stroke: '#ff4444' }, // Layer 2: Đỏ
        3: { fill: 'rgba(68, 204, 68, 0.2)',  stroke: '#44cc44' }, // Layer 3: Xanh lá
        4: { fill: 'rgba(255, 170, 51, 0.2)', stroke: '#ffaa33' }  // Layer 4: Cam
    };

    // Lấy bộ màu cho Layer hiện tại (Quay vòng nếu layerIndex > 4)
    const activeColor = layerColorMap[((layerIndex - 1) % 4) + 1];

    // ==========================================
    // 3. VẼ DỮ LIỆU CỦA ĐÚNG LAYER ĐƯỢC CHỈ ĐỊNH
    // ==========================================
    dataArray.forEach((ueData, index) => {
        // Động xác định key của layer (ví dụ: 'layer1', 'layer2')
        const targetLayerKey = `layer${layerIndex}`;
        if (!ueData || !ueData[targetLayerKey]) return; // Bỏ qua nếu UE này không tồn tại layer đó

        const steps = 180;
        const targetPoints = [];

        // Tính toán các điểm tọa độ
        for (let i = 0; i <= steps; i++) {
            let theta, phi;
            if (type === 'azimuth') {
                theta = Math.PI / 2;
                phi = (i / steps) * 2 * Math.PI;
            } else {
                theta = (i / steps) * Math.PI;
                phi = 0;
            }
            
            const gain = calculateGain(theta, phi, ueData[targetLayerKey], ueData.N1, ueData.N2);
            const angle = (type === 'azimuth') ? phi : theta - Math.PI / 2;
            
            const rad = getRadius(gain);
            targetPoints.push({
                x: center.x + rad * Math.cos(angle),
                y: center.y + rad * Math.sin(angle)
            });
        }

        // Bắt đầu vẽ hình dạng của mảng antenna
        ctx.beginPath();
        targetPoints.forEach((p, i) => i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y));
        ctx.closePath();
        
        // Đổ màu nền (Fill)
        ctx.fillStyle = activeColor.fill;       
        ctx.fill();
        
        // Thiết lập viền (Stroke)
        ctx.strokeStyle = activeColor.stroke;   
        ctx.lineWidth = 2;
        
        // PHÂN BIỆT UE BẰNG NÉT VẼ (UE 1: Nét đứt, UE 2: Nét liền)
        if (index === 0) {
            ctx.setLineDash([6, 6]); // Nét đứt (gạch dài 6px, cách 6px)
        } else {
            ctx.setLineDash([]);     // Nét liền
        }
        
        // Quét viền lên Canvas
        ctx.stroke();

        // Trả lại nét liền mặc định để không ảnh hưởng đến các vòng lặp phía sau
        ctx.setLineDash([]); 
    });
  }

  /** Update min/max limits for input sliders based on codebook constraints */
  function updateSliderRanges() {
    const key = $('#cb5g-config').val();
    const cfg = ALL_CONFIGS[key] || CONFIGS[key] || ALL_CONFIGS['4,2'] || CONFIGS['2,2'];
    const logic = getTableLogic();
    
    const mode = logic ? logic.mode : 1;
    const rank = logic ? logic.rank : 1;
    const isGe16 = logic ? logic.isGe16 : false;

    // Giới hạn của i11: Bị chia đôi nếu Mode 2 HOẶC (Rank 3,4 và P >= 16)
    const isHalfI11 = (mode === 2) || (rank >= 3 && isGe16);
    const maxI11 = isHalfI11 ? Math.floor((cfg.O1 * cfg.N1) / 2) - 1 : (cfg.O1 * cfg.N1) - 1;
    const maxI12 = (mode === 2 && cfg.N2 > 1) ? Math.floor((cfg.O2 * cfg.N2) / 2) - 1 : Math.max(0, (cfg.O2 * cfg.N2) - 1);
    
    $('#cb5g-i11').attr('max', Math.max(0, maxI11));
    $('#cb5g-i12').attr('max', Math.max(0, maxI12));
    
    if (logic) {
      $('#cb5g-i2').attr('max', logic.i2_max);
      const v2 = Math.min(parseInt($('#cb5g-i2').val(), 10), logic.i2_max);
      $('#cb5g-i2').val(v2);
    }
    
    const v11 = Math.min(parseInt($('#cb5g-i11').val(), 10), Math.max(0, maxI11));
    const v12 = Math.min(parseInt($('#cb5g-i12').val(), 10), Math.max(0, maxI12));
    $('#cb5g-i11').val(v11);
    $('#cb5g-i12').val(v12);

    // Xử lý riêng cho i1,3 (Rank >= 2 mới có)
    const $i13Row = $('#cb5g-i13-row');
    const $i13Input = $('#cb5g-i13');
    
    if (rank >= 2) {
      $i13Row.show();
      let i13Max = 3;
      
      if (rank === 2) {
        i13Max = (cfg.N1 === 2 && cfg.N2 === 1) ? 1 : 3;
      } else { // Rank 3 và Rank 4
        if (isGe16) {
          i13Max = 3; // P >= 16 luôn là 0,1,2,3
        } else {
          // P < 16 áp dụng luật từ Table 5.2.2.2.1-4
          if (cfg.N1 === 2 && cfg.N2 === 1) i13Max = 0;
          else if (cfg.N1 === 4 && cfg.N2 === 1) i13Max = 2;
          else if (cfg.N1 === 2 && cfg.N2 === 2) i13Max = 2;
          else i13Max = 3;
        }
      }
      
      $i13Input.attr('max', i13Max);
      const v13 = Math.min(parseInt($i13Input.val(), 10) || 0, i13Max);
      $i13Input.val(Math.max(0, v13));
    } else {
      $i13Row.hide();
      $i13Input.val(0); // Reset về 0 cho an toàn nếu rớt xuống Rank 1
    }
  }

  function populateTables() {
    const $tableSel = $('#cb5g-table-select');
    const $subSel = $('#cb5g-subtable-select');
    if (!$tableSel.length || !$subSel.length) return;

    $tableSel.empty();
    Object.keys(CODEBOOK_TABLES).forEach(function (table) {
      $tableSel.append($('<option></option>').attr('value', table).text(table));
    });

    $tableSel.off('change').on('change', function () {
      const tableKey = $(this).val();
      const tableData = CODEBOOK_TABLES[tableKey];
      $subSel.empty();
      if (tableData) {
        Object.keys(tableData).forEach(function (sub) {
          $subSel.append($('<option></option>').attr('value', sub).text(sub));
        });
      }

      // Tự động set Rank (Layer) dựa trên đuôi của tên Table
      if (tableKey) {
        if (tableKey.indexOf('-5') !== -1) {
          $('#cb5g-rank').val('1');
        } else if (tableKey.indexOf('-6') !== -1) {
          $('#cb5g-rank').val('2');
        } else if (tableKey.indexOf('-7') !== -1) {
          $('#cb5g-rank').val('3');
        } else if (tableKey.indexOf('-8') !== -1) {
          $('#cb5g-rank').val('4');
        }
      }

      $subSel.trigger('change');
    });

    $subSel.off('change').on('change', function () {
      const subKey = $(this).val();
      populateConfigDropdown(subKey);
      
      const tableKey = $tableSel.val();
      const config = tableKey && subKey && CODEBOOK_TABLES[tableKey] && CODEBOOK_TABLES[tableKey][subKey] ? CODEBOOK_TABLES[tableKey][subKey] : null;
      
      if (config) {
        $('#cb5g-i2').attr('max', config.i2_max);
        
        // Đã bỏ dòng $('#cb5g-rank').val(config.rank); để không bị ghi đè logic ở trên
        
        const v2 = Math.min(parseInt($('#cb5g-i2').val(), 10) || 0, config.i2_max);
        $('#cb5g-i2').val(v2);
      }
      
      // Đồng bộ giá trị trước khi vẽ để tránh lỗi 3D
      if (typeof syncValues === 'function') syncValues();
      updateSliderRanges();
      if (typeof updateMeshes === 'function') updateMeshes();
    });

    $tableSel.trigger('change');
  }

  function syncValues() {
  }

  function renderBottomLayers(rank, data) {
    const bottomRow = document.getElementById('bottom-row');
    if (!bottomRow) return;
    
    bottomRow.innerHTML = ''; 
    const dataArray = Array.isArray(data) ? data : [data];

    // Bảng màu tương ứng cho 4 Layer
    const layerColors = ['#4488ff', '#ff4444', '#44cc44', '#ffaa33'];

    for (let i = 1; i <= rank; i++) {
        const currentColor = layerColors[(i - 1) % layerColors.length];
        const panelCol = document.createElement('div');
        panelCol.id = `polar-col-layer-${i}`;
        panelCol.style.flex = "1";
        panelCol.style.minWidth = "250px";

        // Tự động IN HOA chữ azimuth hoặc elevation để hiển thị trên Title
        const planeLabel = currentBottomPlane.toUpperCase();

        panelCol.innerHTML = `
          <div class="polar-panel-each-layer" style="display: flex; flex-direction: column; height: 100%;">
              
              <div class="polar-toolbar-each-layer" style="display: flex; align-items: center; gap: 8px;">
                  <div class="legend-dot" style="background: ${currentColor}; width: 12px; height: 12px; border-radius: 50%;"></div>
                  <span class="polar-label-each-layer" style="font-weight: bold; color: ${currentColor};">LAYER ${i} - ${planeLabel}</span>
              </div>
              
              <div class="polar-canvas-wrap-each-layers" style="flex: 1; position: relative; min-height: 0;">
                  <canvas id="polarCanvas-layer${i}" class="polar-canvas-each-layer"></canvas>
              </div>
              
          </div>
        `;
        bottomRow.appendChild(panelCol);

        setTimeout(() => {
            // TRUYỀN BIẾN currentBottomPlane VÀO HÀM VẼ THAY VÌ CHỮ CỨNG
            drawSingleLayerPolar(`polarCanvas-layer${i}`, currentBottomPlane, dataArray, i);
        }, 50);
    }
  }

  function init() {
    const root = $('#cb5g-root');
    if (!root.length) return;

    populateTables();
    updateSliderRanges();
    syncValues();

    // ==========================================
    // BẮT SỰ KIỆN KHI THAY ĐỔI PMI CỦA UE1 & UE2
    // ==========================================
    $('#cb5g-pmi-global-ue1, #cb5g-pmi-global-ue2').on('input change', function() {
        // Gọi hàm update2DPlots, hàm này sẽ tự gọi calculatePrecoder() 
        // và đẩy mảng data của 2 UE vào hàm drawPolarPlot
        update2DPlots(); 
    });
    // ==========================================

    $('#cb5g-config').on('change', function() {
      updateSliderRanges();
      syncValues(); 
      update2DPlots();
    });
    
    $('#cb5g-i11, #cb5g-i12, #cb5g-i2, #cb5g-i13, #cb5g-rank').on('input change', function() {
      syncValues();
    });

    $('#polarAzimuthScaleBtn').on('click', function() {
      polarScaleAzimuth = polarScaleAzimuth === 'linear' ? 'dB' : 'linear';
      updateScaleButtonIcons();
      update2DPlots();
    });
    
    $('#polarElevationScaleBtn').on('click', function() {
      polarScaleElevation = polarScaleElevation === 'linear' ? 'dB' : 'linear';
      updateScaleButtonIcons();
      update2DPlots();
    });

    $('#btn-toggle-plane').on('click', function() {
      // 1. Đảo ngược trạng thái
      if (currentBottomPlane === 'azimuth') {
          currentBottomPlane = 'elevation';
          $(this).text('Show: AZIMUTH'); // Đổi nhãn nút bấm để mời người dùng bấm quay lại
          $(this).css('background-color', '#d35400'); // (Tùy chọn) Đổi màu nút cho sinh động
      } else {
          currentBottomPlane = 'azimuth';
          $(this).text('Show: ELEVATION');
          $(this).css('background-color', '#333');
      }
      
      // 2. Gọi lại hàm tổng vẽ đồ thị để nó render lại Bottom Row với trục mới
      update2DPlots(); 
    });

    $(window).on('resize', function() {
      update2DPlots();
    });
}

$(document).ready(init);
})(jQuery);
