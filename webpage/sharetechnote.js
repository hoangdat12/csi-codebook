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
  let patternScale3D = 'linear';
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

  /** Returns HTML for indices block: i1,1 / i1,2 (and i1,3 for Rank >= 2), range row, current values. */
  function buildIndicesMiniTableHTML(config) {
    const logic = getTableLogic();
    const mode = logic ? logic.mode : 1;
    const rank = logic ? logic.rank : 1;
    
    // Theo Table 5.2.2.2.1-7/8: Nếu P >= 16 (Rank 3, 4), range của i1,1 bị chia 2 giống hệt Mode 2
    let isHalfI11 = (mode === 2) || (rank >= 3 && logic && logic.isGe16);
    const range1 = isHalfI11 ? '0...N<sub>1</sub>O<sub>1</sub>/2-1' : '0...N<sub>1</sub>O<sub>1</sub>-1';
    
    const range2 = (mode === 2 && config.N2 > 1) ? '0...N<sub>2</sub>O<sub>2</sub>/2-1' : ((mode === 2 && config.N2 === 1) ? '0' : '0...N<sub>2</sub>O<sub>2</sub>-1');
    
    let tbl = '<table class="cb5g-indices-mini">' +
      '<tr><th>i<sub>1,1</sub></th><th>i<sub>1,2</sub></th>';
      
    // Hiển thị i1,3 cho Rank 2, 3 và 4
    if (logic && rank >= 2) {
      let i13Max = 3;
      
      if (rank === 2) {
        i13Max = (config.N1 === 2 && config.N2 === 1) ? 1 : 3;
      } else if (rank >= 3) {
        if (logic.isGe16) {
          i13Max = 3; // P >= 16 luôn có i1,3 từ 0..3
        } else {
          // P < 16 dựa vào Table 5.2.2.2.1-4
          if (config.N1 === 2 && config.N2 === 1) i13Max = 0;
          else if (config.N1 === 4 && config.N2 === 1) i13Max = 2;
          else if (config.N1 === 2 && config.N2 === 2) i13Max = 2;
          else i13Max = 3;
        }
      }

      tbl += '<th>i<sub>1,3</sub></th></tr>' + 
             '<tr><td>' + range1 + '</td><td>' + range2 + '</td><td>0...' + i13Max + '</td></tr>' +
             '<tr><td>' + config.i11 + '</td><td>' + config.i12 + '</td><td>' + (config.i13 != null ? config.i13 : 0) + '</td></tr>';
    } else {
      tbl += '</tr><tr><td>' + range1 + '</td><td>' + range2 + '</td></tr><tr><td>' + config.i11 + '</td><td>' + config.i12 + '</td></tr>';
    }
    
    tbl += '</table>';
    return tbl;
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
    if (!tableLogic) {
      const v_lm = getSteeringVector(rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, rootCfg.i11, rootCfg.i12);
      const phi_n = Complex.exp((PI * rootCfg.i2) / 2);
      const layer1 = [];
      v_lm.forEach(function (v) { layer1.push(v); });
      v_lm.forEach(function (v) { layer1.push(Complex.mul(v, phi_n)); });
      const layer2 = rootCfg.rank === 2 ? v_lm.map(function (v) { return v; }).concat(v_lm.map(function (v) { return Complex.mul(v, { re: -phi_n.re, im: -phi_n.im }); })) : null;
      return { layer1: layer1, layer2: layer2, N1: rootCfg.N1, N2: rootCfg.N2 };
    }

    if (tableLogic.rank == 1 || tableLogic.rank == 2) {
      if (tableLogic.rank === 2) {
        const i13 = parseInt(rootCfg.i13, 10) || 0;
        const idx = tableLogic.getIndices(rootCfg.i11, rootCfg.i12, rootCfg.i2, i13, rootCfg);
        const v_lm = getSteeringVector(rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, idx.l, idx.m);
        const v_lpmp = getSteeringVector(rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, idx.lp, idx.mp);
        const phi_n = Complex.exp((PI * idx.n) / 2);
        const neg_phi_n = { re: -phi_n.re, im: -phi_n.im };
        const layer1 = v_lm.concat(v_lm.map(function (v) { return Complex.mul(v, phi_n); }));
        const layer2 = v_lpmp.concat(v_lpmp.map(function (v) { return Complex.mul(v, neg_phi_n); }));
        return { layer1: layer1, layer2: layer2, N1: rootCfg.N1, N2: rootCfg.N2 };
      }

      const { l, m, n } = tableLogic.getIndices(rootCfg.i11, rootCfg.i12, rootCfg.i2);
      const v_lm = getSteeringVector(rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, l, m);
      const phi_n = Complex.exp((PI * n) / 2);
      const layer1 = [];
      v_lm.forEach(function (v) { layer1.push(v); });
      v_lm.forEach(function (v) { layer1.push(Complex.mul(v, phi_n)); });
      return { layer1: layer1, layer2: null, N1: rootCfg.N1, N2: rootCfg.N2 };
    } else {
      // Xử lý cho Rank 3 và Rank 4
      const i13 = parseInt(rootCfg.i13, 10) || 0;
      const idx = tableLogic.getIndices(rootCfg.i11, rootCfg.i12, rootCfg.i2, i13, rootCfg);
      const phi_n = Complex.exp((PI * idx.n) / 2);
      const neg_phi_n = { re: -phi_n.re, im: -phi_n.im };

      if (idx.isGe16) {
        // Trường hợp P_CSIRS >= 16: ma trận 4 khối với v_tilde
        const v_tilde = getSteeringVector(rootCfg.N1 / 2, rootCfg.N2, rootCfg.O1, rootCfg.O2, idx.l, idx.m);
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
          return { layer1: layer1, layer2: layer2, layer3: layer3, layer4: null, N1: rootCfg.N1, N2: rootCfg.N2 };
        }

        if (tableLogic.rank === 4) {
          v_tilde.forEach(function (v) { layer1.push(v); layer2.push(v); layer3.push(v); layer4.push(v); });
          v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, theta_p)); layer2.push(Complex.mul(v, neg_theta_p)); layer3.push(Complex.mul(v, theta_p)); layer4.push(Complex.mul(v, neg_theta_p)); });
          v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, phi_n)); layer2.push(Complex.mul(v, phi_n)); layer3.push(Complex.mul(v, neg_phi_n)); layer4.push(Complex.mul(v, neg_phi_n)); });
          v_tilde.forEach(function (v) { layer1.push(Complex.mul(v, phi_theta)); layer2.push(Complex.mul(v, neg_phi_theta)); layer3.push(Complex.mul(v, neg_phi_theta)); layer4.push(Complex.mul(v, phi_theta)); });
          return { layer1: layer1, layer2: layer2, layer3: layer3, layer4: layer4, N1: rootCfg.N1, N2: rootCfg.N2 };
        }
      } else {
        // Trường hợp P_CSIRS < 16: ghép mảng như Rank 2
        const v_lm = getSteeringVector(rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, idx.l, idx.m);
        const v_lpmp = getSteeringVector(rootCfg.N1, rootCfg.N2, rootCfg.O1, rootCfg.O2, idx.lp, idx.mp);
        const layer1 = v_lm.concat(v_lm.map(function (v) { return Complex.mul(v, phi_n); }));
        const layer2 = v_lpmp.concat(v_lpmp.map(function (v) { return Complex.mul(v, phi_n); }));
        const layer3 = v_lm.concat(v_lm.map(function (v) { return Complex.mul(v, neg_phi_n); }));
        let layer4 = null;

        if (tableLogic.rank === 4) {
          layer4 = v_lpmp.concat(v_lpmp.map(function (v) { return Complex.mul(v, neg_phi_n); }));
        }
        return { layer1: layer1, layer2: layer2, layer3: layer3, layer4: layer4, N1: rootCfg.N1, N2: rootCfg.N2 };
      }
    }
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

  /** Build geometry: sphere vertices scaled by gain, with Red-to-Yellow color map. Linear or dB scale via patternScale3D. */
  function buildPatternGeometry(weights, N1, N2, colorHex) {
    const seg = 56;
    const geometry = new THREE.SphereGeometry(1, seg, seg);
    const pos = geometry.attributes.position;
    const count = pos.count;
    const colors = new Float32Array(count * 3);
    const gains = new Float32Array(count);

    let maxGain = 1e-10;
    for (let i = 0; i < count; i++) {
      const x = pos.getX(i);
      const y = pos.getY(i);
      const z = pos.getZ(i);
      const r = Math.sqrt(x * x + y * y + z * z) || 1e-6;
      const theta = Math.acos(Math.max(-1, Math.min(1, z / r)));
      const phi = Math.atan2(y, x);
      const g = calculateGain(theta, phi, weights, N1, N2);
      gains[i] = g;
      if (g > maxGain) maxGain = g;
    }

    const useDb = (patternScale3D === 'dB');

    for (let i = 0; i < count; i++) {
      const x = pos.getX(i);
      const y = pos.getY(i);
      const z = pos.getZ(i);
      const gain = gains[i];

      let t;
      if (useDb) {
        const dB = 20 * Math.log10(Math.max(gain, 1e-10));
        t = Math.max(0, Math.min(1, (dB - POLAR_DB_FLOOR) / (0 - POLAR_DB_FLOOR)));
      } else {
        t = maxGain > 0 ? Math.min(1, gain / maxGain) : 0;
      }

      const scale = 0.1 + 2.5 * t;
      pos.setXYZ(i, x * scale, y * scale, z * scale);

      const hue = t * 0.16;
      const c = new THREE.Color().setHSL(hue, 1.0, 0.75);
      colors[i * 3] = c.r;
      colors[i * 3 + 1] = c.g;
      colors[i * 3 + 2] = c.b;
    }

    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geometry.computeVertexNormals();
    return geometry;
  }

  let scene, camera, renderer, controls;
  let meshL1, meshL2, meshL3, meshL4, arrayGroup;

  /**
   * Builds physical X-pole antenna array in XZ-plane (red/blue axes).
   * N1 along X (horizontal, red), N2 along Z (vertical, blue); boresight along +Y (green).
   * Pole brightness reflects precoder weight magnitude; phase lines in XZ-plane.
   */
  function buildArrayGeometry(N1, N2, weights) {
    const group = new THREE.Group();
    const poleLength = 0.4;
    const poleRadius = 0.025;
    const spacing = 0.8;
    const arrowLength = 0.5;
    const numPerPol = N1 * N2;

    const poleGeo = new THREE.CylinderGeometry(poleRadius, poleRadius, poleLength, 8);
    group.userData.poleGeo = poleGeo;

    for (let n1 = 0; n1 < N1; n1++) {
      for (let n2 = 0; n2 < N2; n2++) {
        const elementGroup = new THREE.Group();

        // 3GPP: N1 horizontal (X-axis, red), N2 vertical (Z-axis, blue); array in XZ-plane
        const posX = (n1 - (N1 - 1) / 2) * spacing;
        const posZ = (n2 - (N2 - 1) / 2) * spacing;

        const idx1 = (n1 * N2) + n2;
        const idx2 = numPerPol + idx1;

        const w1 = weights && weights[idx1] ? weights[idx1] : { re: 1, im: 0 };
        const w2 = weights && weights[idx2] ? weights[idx2] : { re: 1, im: 0 };
        const mag1 = (Math.sqrt(w1.re * w1.re + w1.im * w1.im) || 1e-6);
        const mag2 = (Math.sqrt(w2.re * w2.re + w2.im * w2.im) || 1e-6);
        const phase1 = Math.atan2(w1.im, w1.re);
        const phase2 = Math.atan2(w2.im, w2.re);

        // Cross-poles flat in XZ plane (red/blue): cylinder axis Y → rotate into XZ, then ±45°
        const p1 = new THREE.Mesh(poleGeo, new THREE.MeshLambertMaterial({
          color: 0x0088ff,
          emissive: 0x0088ff,
          emissiveIntensity: Math.min(1, mag1 * 0.8)
        }));
        p1.rotation.z = PI / 2;
        p1.rotation.y = PI / 4;
        elementGroup.add(p1);

        const p2 = new THREE.Mesh(poleGeo, new THREE.MeshLambertMaterial({
          color: 0xff3333,
          emissive: 0xff3333,
          emissiveIntensity: Math.min(1, mag2 * 0.8)
        }));
        p2.rotation.z = PI / 2;
        p2.rotation.y = -PI / 4;
        elementGroup.add(p2);

        // Phase indicators flat in XZ plane (red/blue)
        const line1 = new THREE.Line(
          new THREE.BufferGeometry().setFromPoints([
            new THREE.Vector3(0, 0, 0),
            new THREE.Vector3(arrowLength * Math.cos(phase1), 0, arrowLength * Math.sin(phase1))
          ]),
          new THREE.LineBasicMaterial({ color: 0x0088ff })
        );
        elementGroup.add(line1);

        const line2 = new THREE.Line(
          new THREE.BufferGeometry().setFromPoints([
            new THREE.Vector3(0, 0, 0),
            new THREE.Vector3(arrowLength * Math.cos(phase2), 0, arrowLength * Math.sin(phase2))
          ]),
          new THREE.LineBasicMaterial({ color: 0xff3333 })
        );
        elementGroup.add(line2);

        elementGroup.position.set(posX, 0, posZ);
        group.add(elementGroup);
      }
    }

    // Boresight: green arrow along +Y (primary radiation direction)
    const boresightGeo = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(0, 0, 0),
      new THREE.Vector3(0, 1.2, 0)
    ]);
    const boresightLine = new THREE.Line(boresightGeo, new THREE.LineBasicMaterial({ color: 0x44cc44, linewidth: 2 }));
    group.add(boresightLine);
    group.userData.boresightGeo = boresightGeo;

    group.position.set(0, 0, 0);
    group.renderOrder = 1;
    return group;
  }

  function init3D(container) {
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0a0a0a);
    const w = container.width();
    const h = container.height();
    camera = new THREE.PerspectiveCamera(45, w / h, 0.1, 1000);
    camera.position.set(5, 4, 6);
    camera.lookAt(0, 0, 0);

    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(w, h);
    renderer.setPixelRatio(window.devicePixelRatio || 1);
    container.get(0).appendChild(renderer.domElement);

    if (typeof THREE.OrbitControls !== 'undefined') {
      controls = new THREE.OrbitControls(camera, renderer.domElement);
      controls.enableDamping = true;
      controls.dampingFactor = 0.05;
    }

    const light = new THREE.DirectionalLight(0xffffff, 0.9);
    light.position.set(5, 5, 5).normalize();
    scene.add(light);
    scene.add(new THREE.AmbientLight(0x404040));

    const grid = new THREE.GridHelper(2, 10, 0x444444, 0x333333);
    grid.rotation.x = PI / 2;
    scene.add(grid);

    const axesLen = 1.2;
    [
      [new THREE.Vector3(0, 0, 0), new THREE.Vector3(axesLen, 0, 0), 0xcc4444],
      [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, axesLen, 0), 0x44cc44],
      [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, axesLen), 0x4444cc]
    ].forEach(([a, b, c]) => {
      const geo = new THREE.BufferGeometry().setFromPoints([a, b]);
      scene.add(new THREE.Line(geo, new THREE.LineBasicMaterial({ color: c })));
    });

    updateMeshes();
    updateScaleButtonIcons();
    update3DScaleButtonIcon();
    animate();
  }

  /**
   * Draw a 2D polar cross-section (azimuth or elevation slice) on a canvas.
   * type 'azimuth': theta = PI/2, phi varies 0..2*PI (XY-plane).
   * type 'elevation': phi = 0, theta varies 0..PI (XZ-plane).
   */
  function drawPolarPlot(canvasId, type, data) {
    const canvas = document.getElementById(canvasId);
    if (!canvas || !data || !data.layer1) return;
    const parent = canvas.parentElement;
    if (!parent || !parent.clientWidth) return;

    const w = (canvas.width = parent.clientWidth);
    const h = (canvas.height = parent.clientHeight);
    const center = { x: w / 2, y: h / 2 };
    const radius = Math.min(w, h) * 0.38;
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, w, h);

    // Polar grid (concentric circles)
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
      const scaleMode = (canvasId === 'polarAzimuth') ? polarScaleAzimuth : polarScaleElevation;
      if (scaleMode === 'dB') {
        const dB = 20 * Math.log10(Math.max(gain, 1e-10));
        return Math.max(0, Math.min(1, (dB - POLAR_DB_FLOOR) / (0 - POLAR_DB_FLOOR))) * radius;
      }
      return gain * radius;
    }

    const steps = 180;
    // Thêm l3 và l4 vào object lưu điểm
    const layerPoints = { total: [], l1: [], l2: [], l3: [], l4: [] };

    for (let i = 0; i <= steps; i++) {
      let theta, phi;
      if (type === 'azimuth') {
        theta = PI / 2;
        phi = (i / steps) * TAU;
      } else {
        theta = (i / steps) * PI;
        phi = 0;
      }
      
      const g1 = calculateGain(theta, phi, data.layer1, data.N1, data.N2);
      const g2 = data.layer2 ? calculateGain(theta, phi, data.layer2, data.N1, data.N2) : 0;
      const g3 = data.layer3 ? calculateGain(theta, phi, data.layer3, data.N1, data.N2) : 0;
      const g4 = data.layer4 ? calculateGain(theta, phi, data.layer4, data.N1, data.N2) : 0;
      
      // Tổng công suất cho tất cả các layer
      const gTotal = Math.sqrt(g1 * g1 + g2 * g2 + g3 * g3 + g4 * g4);

      const angle = (type === 'azimuth') ? phi : theta - PI / 2;
      function getXY(g) {
        const rad = getRadius(g);
        return { x: center.x + rad * Math.cos(angle), y: center.y + rad * Math.sin(angle) };
      }
      
      layerPoints.total.push(getXY(gTotal));
      layerPoints.l1.push(getXY(g1));
      if (data.layer2) layerPoints.l2.push(getXY(g2));
      if (data.layer3) layerPoints.l3.push(getXY(g3));
      if (data.layer4) layerPoints.l4.push(getXY(g4));
    }

    // 1. Combined power (fill + solid line)
    ctx.beginPath();
    layerPoints.total.forEach(function (p, i) {
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.closePath();
    ctx.fillStyle = (canvasId.indexOf('Azimuth') !== -1) ? 'rgba(68,136,255,0.15)' : 'rgba(255,68,68,0.15)';
    ctx.fill();
    ctx.strokeStyle = (canvasId.indexOf('Azimuth') !== -1) ? '#4488ff' : '#ff4444';
    ctx.lineWidth = 2;
    ctx.setLineDash([]);
    ctx.stroke();

    // Cài đặt chung cho các nét đứt viền ngoài
    ctx.setLineDash([3, 3]);
    ctx.lineWidth = 1;

    // 2. Layer 1 outline (dotted blue)
    ctx.beginPath();
    layerPoints.l1.forEach(function (p, i) {
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.strokeStyle = '#0088ff';
    ctx.stroke();

    // 3. Layer 2 outline (dotted red)
    if (data.layer2) {
      ctx.beginPath();
      layerPoints.l2.forEach(function (p, i) {
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      ctx.strokeStyle = '#ff3333';
      ctx.stroke();
    }

    // 4. Layer 3 outline (dotted green)
    if (data.layer3) {
      ctx.beginPath();
      layerPoints.l3.forEach(function (p, i) {
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      ctx.strokeStyle = '#44cc44';
      ctx.stroke();
    }

    // 5. Layer 4 outline (dotted orange)
    if (data.layer4) {
      ctx.beginPath();
      layerPoints.l4.forEach(function (p, i) {
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      ctx.strokeStyle = '#ffaa33';
      ctx.stroke();
    }

    ctx.setLineDash([]); // Reset lại đường vẽ
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

  function update3DScaleButtonIcon() {
    const btn = document.getElementById('cb5g3dScaleBtn');
    if (!btn) return;
    const lin = btn.querySelector('.cb5g-icon-lin');
    const db = btn.querySelector('.cb5g-icon-db');
    if (lin && db) {
      lin.style.display = patternScale3D === 'dB' ? '' : 'none';
      db.style.display = patternScale3D === 'linear' ? '' : 'none';
    }
  }

  function update2DPlots(data) {
    if (!data) data = calculatePrecoder();
    drawPolarPlot('polarAzimuth', 'azimuth', data);
    drawPolarPlot('polarElevation', 'elevation', data);
  }

  /**
   * Renders the 3GPP 38.214 reference grid aligned with spec: Mode 1 single row; Mode 2 refinement grid
   * (Rank 1: 4 rows; Rank 2: 2 rows). Only the cell matching current i2 gets .cell-active. Formula W (Rank 1)
   * or W^(2) (Rank 2); active cell shows (l,m) or (l,l') in green. Table 5.2.2.2.1-3 (k1,k2) stays internal.
   */
  function renderFull3GPPTable() {
    const $container = $('#cb5g-table-reference');
    const config = getConfig();
    const tableKey = $('#cb5g-table-select').val();
    const subKey = $('#cb5g-subtable-select').val();
    const tableLogic = getTableLogic();

    if (!$container.length) return;
    $container.empty();

    let html = '<h4 class="ref-title">3GPP 38.214: ' + (subKey || '') + '</h4>';
    if (!tableLogic) {
        $container.append(html);
        return;
    }

    // 1. Xác định Rank động (1, 2, 3, hoặc 4)
    const rank = tableLogic.rank || 
                 (tableKey.includes('-5') ? 1 :
                  tableKey.includes('-6') ? 2 :
                  tableKey.includes('-7') ? 3 :
                  tableKey.includes('-8') ? 4 : 1);

    // Truy xuất indices (giả định tableLogic.getIndices đã handle nội bộ cho rank 3 & 4)
    const indices = tableLogic.getIndices(config.i11, config.i12, config.i2, config.i13 != null ? config.i13 : 0, config);
    const miniTable = buildIndicesMiniTableHTML(config);

    // --- HELPER FUNCTIONS ---
    // Helper tạo công thức W linh hoạt theo Rank
    function getW(r, subscripts) {
        if (r === 1) return 'W<sub>' + subscripts + '</sub>';
        return 'W<sup>(' + r + ')</sup><sub>' + subscripts + '</sub>';
    }

    // Helper tự động build chuỗi (l, m, l', m', l'', m'', l''', m''') tùy theo Rank
    function formatIndices(idx, r) {
        let res = '(l=' + idx.l + ', m=' + idx.m;
        if (r >= 2 && idx.lp !== undefined) res += ", l'=" + idx.lp + ", m'=" + idx.mp;
        if (r >= 3 && idx.lpp !== undefined) res += ", l''=" + idx.lpp + ", m''=" + idx.mpp;
        if (r >= 4 && idx.lppp !== undefined) res += ", l'''=" + idx.lppp + ", m'''=" + idx.mppp;
        res += ')';
        return res;
    }
    // ------------------------

    // Gộp Rank 3 & 4 vào luồng này vì chuẩn 3GPP định nghĩa chung là codebookMode = 1-2
    if (subKey.indexOf('Mode 1') !== -1 || rank >= 3) {
        const i2Cols = rank === 1 ? 4 : 2; 
        
        // Nhận diện < 16 ports hay >= 16 ports dựa trên tên subKey (Dropdown menu)
        const isGe16 = subKey.includes('16') && !subKey.includes('<');
        const showI13 = isGe16; // Cần hiển thị cột i1,3 nếu >= 16 ports
        
        html += '<table class="reference-grid">';
        html += '<tr><th>i<sub>1,1</sub></th><th>i<sub>1,2</sub></th>';
        if (showI13) html += '<th>i<sub>1,3</sub></th>';
        html += '<th colspan="' + i2Cols + '">i<sub>2</sub></th></tr>';
        
        // Xét Range chuẩn dựa theo port: >=16 port ở rank 2,3,4 thì range bị chia đôi
        let rangeI11 = (isGe16 && rank >= 2) ? '0...N<sub>1</sub>O<sub>1</sub>/2-1' : '0...N<sub>1</sub>O<sub>1</sub>-1';
        let rangeI12 = '0...N<sub>2</sub>O<sub>2</sub>-1';
        
        html += '<tr><td>' + rangeI11 + '</td><td>' + rangeI12 + '</td>';
        if (showI13) html += '<td>0, 1, 2, 3</td>'; // Range cho i1,3 luôn là 0,1,2,3
        
        for (var n = 0; n < i2Cols; n++) html += '<td>' + n + '</td>';
        html += '</tr><tr class="data-row"><td>' + config.i11 + '</td><td>' + config.i12 + '</td>';
        
        if (showI13) html += '<td>' + (config.i13 != null ? config.i13 : 0) + '</td>';
        
        for (var n = 0; n < i2Cols; n++) {
            var active = config.i2 === n;
            html += '<td class="' + (active ? 'cell-active' : '') + '">';
            
            // Xử lý chuỗi Subscript chính xác (thay thế cho Placeholder cũ)
            let subStr = '';
            if (isGe16) {
                // Theo chuẩn: Tất cả rank khi >= 16 ports sử dụng subscript: i1,1, i1,2, i1,3, i2
                subStr = 'i<sub>1,1</sub>, i<sub>1,2</sub>, i<sub>1,3</sub>, ' + n;
            } else {
                if (rank === 1) {
                    subStr = 'l,m,' + n;
                } else {
                    // Theo chuẩn: Rank 2, 3, 4 khi < 16 ports sử dụng subscript k1, k2
                    subStr = 'i<sub>1,1</sub>, i<sub>1,1</sub>+k<sub>1</sub>, i<sub>1,2</sub>, i<sub>1,2</sub>+k<sub>2</sub>, ' + n;
                }
            }

            html += getW(rank, subStr);
            
            if (active) {
                html += miniTable;
                html += '<div class="ref-cell-values" style="color:#0f0;font-size:9px;">' + formatIndices(indices, rank) + '</div>';
            }
            html += '</td>';
        }
        html += '</tr></table>';
    } else {
        // Mode 2 logic (Dành riêng cho Rank 1 & 2 khi chọn Mode 2)
        const isN2One = subKey.indexOf('N2 = 1') !== -1 || subKey.indexOf('N2=1') !== -1;
        const numRows = rank >= 2 ? 2 : 4; 
        const colsPerRow = 4;

        html += '<table class="reference-grid">';
        if (rank >= 2) {
            // Rank >= 2 Mode 2
            var rowspanStub = 4;
            var range1 = '0...N<sub>1</sub>O<sub>1</sub>/2-1';
            var range2 = isN2One ? '0' : '0...N<sub>2</sub>O<sub>2</sub>/2-1';
            
            // Các offset không gian
            var rowSubscripts = isN2One ? [
                '2i<sub>1,1</sub>, 2i<sub>1,1</sub>+k<sub>1</sub>, 0, 0',
                '2i<sub>1,1</sub>+1, 2i<sub>1,1</sub>+1+k<sub>1</sub>, 0, 0',
                '2i<sub>1,1</sub>+2, 2i<sub>1,1</sub>+2+k<sub>1</sub>, 0, 0',
                '2i<sub>1,1</sub>+3, 2i<sub>1,1</sub>+3+k<sub>1</sub>, 0, 0'
            ] : [
                '2i<sub>1,1</sub>, 2i<sub>1,1</sub>+k<sub>1</sub>, 2i<sub>1,2</sub>, 2i<sub>1,2</sub>+k<sub>2</sub>',
                '2i<sub>1,1</sub>+1, 2i<sub>1,1</sub>+1+k<sub>1</sub>, 2i<sub>1,2</sub>, 2i<sub>1,2</sub>+k<sub>2</sub>',
                '2i<sub>1,1</sub>, 2i<sub>1,1</sub>+k<sub>1</sub>, 2i<sub>1,2</sub>+1, 2i<sub>1,2</sub>+1+k<sub>2</sub>',
                '2i<sub>1,1</sub>+1, 2i<sub>1,1</sub>+1+k<sub>1</sub>, 2i<sub>1,2</sub>+1, 2i<sub>1,2</sub>+1+k<sub>2</sub>'
            ];

            html += '<tr><th rowspan="' + rowspanStub + '">i<sub>1,1</sub><br/><span class="ref-range">' + range1 + '</span></th>';
            html += '<th rowspan="' + rowspanStub + '">i<sub>1,2</sub><br/><span class="ref-range">' + range2 + '</span></th>';
            html += '<th>0</th><th>1</th><th>2</th><th>3</th></tr>';
            
            // Hàng 1 (i2 = 0 đến 3)
            html += '<tr>';
            for (var c = 0; c < 4; c++) {
                var currentI2 = c;
                var active = config.i2 === currentI2;
                var subIdx = Math.floor(currentI2 / 2);
                var nVal = currentI2 % 2;
                var formula = getW(rank, rowSubscripts[subIdx] + ', ' + nVal);
                
                html += '<td class="' + (active ? 'cell-active' : '') + '">' + formula;
                if (active) { 
                    html += miniTable; 
                    html += '<div class="ref-cell-values" style="color:#0f0;font-size:9px;">' + formatIndices(indices, rank) + '</div>'; 
                }
                html += '</td>';
            }
            html += '</tr>';
            
            // Hàng 2 (i2 = 4 đến 7)
            html += '<tr><th>4</th><th>5</th><th>6</th><th>7</th></tr>';
            html += '<tr>';
            for (var c = 0; c < 4; c++) {
                var currentI2 = 4 + c;
                var active = config.i2 === currentI2;
                var subIdx = Math.floor(currentI2 / 2);
                var nVal = currentI2 % 2;
                var formula = getW(rank, rowSubscripts[subIdx] + ', ' + nVal);
                
                html += '<td class="' + (active ? 'cell-active' : '') + '">' + formula;
                if (active) { 
                    html += miniTable; 
                    html += '<div class="ref-cell-values" style="color:#0f0;font-size:9px;">' + formatIndices(indices, rank) + '</div>'; 
                }
                html += '</td>';
            }
            html += '</tr>';
            
        } else {
            // Rank 1
            html += '<tr><th rowspan="2">i<sub>1,1</sub></th><th rowspan="2">i<sub>1,2</sub></th><th colspan="4">i2</th></tr>';
            html += '<tr><th>0</th><th>1</th><th>2</th><th>3</th></tr>';
            for (var r = 0; r < numRows; r++) {
                html += '<tr>';
                if (r === 0) {
                    html += '<td rowspan="' + numRows + '">0...N1O1/2-1</td><td rowspan="' + numRows + '">' + (isN2One ? '0' : '0...N2O2/2-1') + '</td>';
                }
                for (var c = 0; c < colsPerRow; c++) {
                    var currentI2 = r * colsPerRow + c;
                    var active = config.i2 === currentI2;
                    var formula = getW(rank, 'l,m,' + currentI2);
                    html += '<td class="' + (active ? 'cell-active' : '') + '">' + formula;
                    if (active) {
                        html += miniTable;
                        html += '<div class="ref-cell-values" style="color:#0f0;font-size:9px;">' + formatIndices(indices, rank) + '</div>';
                    }
                    html += '</td>';
                }
                html += '</tr>';
            }
        }
        html += '</table>';
    }
    $container.append(html);
    renderKTable();
  }

  /**
   * Renders Table 5.2.2.2.1-3: Mapping of i1,3 to k1 and k2.
   * Shown below the main W matrix when Rank 2 (Table 5.2.2.2.1-6) is selected.
   */
  function renderKTable() {
    const $container = $('#cb5g-k-table-reference');
    const tableKey = $('#cb5g-table-select').val() || '';
    const config = getConfig();

    if (!$container.length) return;
    $container.empty();

    // Xác định đang xem Rank nào thông qua tableKey
    const isRank2 = tableKey.includes('-6');
    const isRank3or4 = tableKey.includes('-7') || tableKey.includes('-8');

    // Nếu không phải Rank 2, 3, hoặc 4 thì ẩn bảng mapping i1,3 (do rank 1 không dùng k1, k2)
    if (!isRank2 && !isRank3or4) {
        $container.hide();
        return;
    }
    
    $container.show();
    let html = '';

    if (isRank2) {
        // --- Bảng cũ: 3GPP Table 5.2.2.2.1-3 (Cho Rank 2) ---
        html += '<h4 class="ref-title" style="margin-top:20px;">3GPP 38.214 Table 5.2.2.2.1-3: i<sub>1,3</sub> Mapping</h4>';
        html += '<table class="reference-grid k-table-ref">';
        html += '<tr><th rowspan="2">i<sub>1,3</sub></th>';
        html += '<th colspan="2">N<sub>1</sub> &gt; N<sub>2</sub> &gt; 1</th>';
        html += '<th colspan="2">N<sub>1</sub> = N<sub>2</sub></th>';
        html += '<th colspan="2">N<sub>1</sub> = 2, N<sub>2</sub> = 1</th>';
        html += '<th colspan="2">N<sub>1</sub> &gt; 2, N<sub>2</sub> = 1</th></tr>';
        html += '<tr><th>k<sub>1</sub></th><th>k<sub>2</sub></th><th>k<sub>1</sub></th><th>k<sub>2</sub></th><th>k<sub>1</sub></th><th>k<sub>2</sub></th><th>k<sub>1</sub></th><th>k<sub>2</sub></th></tr>';

        const rowData = [
            ['0', '0', '0', '0', '0', '0', '0', '0'],
            ['O<sub>1</sub>', '0', 'O<sub>1</sub>', '0', 'O<sub>1</sub>', '0', 'O<sub>1</sub>', '0'],
            ['0', 'O<sub>2</sub>', '0', 'O<sub>2</sub>', '', '', '2O<sub>1</sub>', '0'],
            ['2O<sub>1</sub>', '0', 'O<sub>1</sub>', 'O<sub>2</sub>', '', '', '3O<sub>1</sub>', '0']
        ];
        
        for (let i = 0; i < rowData.length; i++) {
            let isRowActive = (config.i13 === i);
            html += '<tr class="' + (isRowActive ? 'cell-active' : '') + '"><td>' + i + '</td>';
            rowData[i].forEach(function (cell) { html += '<td>' + cell + '</td>'; });
            html += '</tr>';
        }
        html += '</table>';
        
    } else if (isRank3or4) {
        // --- Bảng mới: 3GPP Table 5.2.2.2.2-2 (Cho Rank 3 và 4) ---
        html += '<h4 class="ref-title" style="margin-top:20px;">3GPP 38.214 Table 5.2.2.2.2-2: i<sub>1,3</sub> Mapping for 3-layer and 4-layer</h4>';
        html += '<table class="reference-grid k-table-ref">';
        html += '<tr><th rowspan="2">i<sub>1,3</sub></th>';
        html += '<th colspan="2">N<sub>1</sub> = 2, N<sub>2</sub> = 1</th>';
        html += '<th colspan="2">N<sub>1</sub> = 4, N<sub>2</sub> = 1</th>';
        html += '<th colspan="2">N<sub>1</sub> = 8, N<sub>2</sub> = 1</th>';
        html += '<th colspan="2">N<sub>1</sub> = 2, N<sub>2</sub> = 2</th>';
        html += '<th colspan="2">N<sub>1</sub> = 4, N<sub>2</sub> = 2</th></tr>';
        
        html += '<tr>';
        for (let c = 0; c < 5; c++) {
            html += '<th>k<sub>1</sub></th><th>k<sub>2</sub></th>';
        }
        html += '</tr>';

        // Khai báo dữ liệu từng dòng dựa trên ảnh cung cấp
        const rowData = [
            // i1,3 = 0
            ['O<sub>1</sub>', '0', 'O<sub>1</sub>', '0', 'O<sub>1</sub>', '0', 'O<sub>1</sub>', '0', 'O<sub>1</sub>', '0'],
            // i1,3 = 1
            ['', '', '2O<sub>1</sub>', '0', '2O<sub>1</sub>', '0', '0', 'O<sub>2</sub>', '0', 'O<sub>2</sub>'],
            // i1,3 = 2
            ['', '', '3O<sub>1</sub>', '0', '3O<sub>1</sub>', '0', 'O<sub>1</sub>', 'O<sub>2</sub>', 'O<sub>1</sub>', 'O<sub>2</sub>'],
            // i1,3 = 3
            ['', '', '', '', '4O<sub>1</sub>', '0', '', '', '2O<sub>1</sub>', '0']
        ];
        
        for (let i = 0; i < rowData.length; i++) {
            let isRowActive = (config.i13 === i);
            html += '<tr class="' + (isRowActive ? 'cell-active' : '') + '"><td>' + i + '</td>';
            rowData[i].forEach(function (cell) { html += '<td>' + cell + '</td>'; });
            html += '</tr>';
        }
        html += '</table>';
    }

    $container.append(html);
  }

  function renderMatrixTable(data) {
    const $table = $('#cb5g-matrix-table');
    if (!$table.length || !data || !data.layer1) return;
    $table.empty();

    // Xác định Rank dựa trên số lượng layer có trong data
    let rank = 1;
    if (data.layer4) rank = 4;
    else if (data.layer3) rank = 3;
    else if (data.layer2) rank = 2;

    // Xây dựng Header động
    let header = '<tr><th>Port</th><th>Layer 1 (W1)</th>';
    if (rank >= 2) header += '<th>Layer 2 (W2)</th>';
    if (rank >= 3) header += '<th>Layer 3 (W3)</th>';
    if (rank >= 4) header += '<th>Layer 4 (W4)</th>';
    header += '</tr>';
    $table.append(header);

    const numPorts = data.layer1.length; // Số lượng antenna ports (2 * N1 * N2)
    
    // Công thức chuẩn hóa: 1 / sqrt(Rank * số Ports)
    const normFactor = 1 / Math.sqrt(rank * numPorts);

    // Helper function để tính toán và format số phức
    const formatComplex = function(w) {
      const re = (w.re * normFactor).toFixed(3);
      const im = (w.im * normFactor).toFixed(3);
      return re + (w.im >= 0 ? '+' : '') + im + 'j';
    };

    for (let i = 0; i < numPorts; i++) {
      let row = '<tr><td>P' + (3000 + i) + '</td>';
      
      // Layer 1 (Xanh dương)
      row += '<td style="color:#4488ff">' + formatComplex(data.layer1[i]) + '</td>';
      
      // Layer 2 (Đỏ)
      if (rank >= 2) {
        row += '<td style="color:#ff4444">' + formatComplex(data.layer2[i]) + '</td>';
      }
      
      // Layer 3 (Xanh lá)
      if (rank >= 3) {
        row += '<td style="color:#44cc44">' + formatComplex(data.layer3[i]) + '</td>';
      }
      
      // Layer 4 (Cam)
      if (rank >= 4) {
        row += '<td style="color:#ffaa33">' + formatComplex(data.layer4[i]) + '</td>';
      }
      
      row += '</tr>';
      $table.append(row);
    }
  }

  function updateMeshes() {
    const data = calculatePrecoder();

    if (!scene) {
      update2DPlots(data);
      renderMatrixTable(data);
      renderFull3GPPTable();
      return;
    }

    // Xóa Array cũ
    if (arrayGroup) {
      scene.remove(arrayGroup);
      if (arrayGroup.userData.poleGeo) arrayGroup.userData.poleGeo.dispose();
      if (arrayGroup.userData.boresightGeo) arrayGroup.userData.boresightGeo.dispose();
      arrayGroup.traverse(function (obj) {
        if (obj.geometry && obj.geometry !== arrayGroup.userData.poleGeo && obj.geometry !== arrayGroup.userData.boresightGeo) obj.geometry.dispose();
        if (obj.material) obj.material.dispose();
      });
    }

    // Xóa các mesh layer cũ
    if (typeof meshL1 !== 'undefined' && meshL1) { scene.remove(meshL1); meshL1.geometry.dispose(); meshL1.material.dispose(); }
    if (typeof meshL2 !== 'undefined' && meshL2) { scene.remove(meshL2); meshL2.geometry.dispose(); meshL2.material.dispose(); }
    if (typeof meshL3 !== 'undefined' && meshL3) { scene.remove(meshL3); meshL3.geometry.dispose(); meshL3.material.dispose(); }
    if (typeof meshL4 !== 'undefined' && meshL4) { scene.remove(meshL4); meshL4.geometry.dispose(); meshL4.material.dispose(); }

    // --- Vẽ Layer 1 (Xanh dương) ---
    const mat1 = new THREE.MeshPhongMaterial({
      color: 0x4488ff,
      transparent: true,
      opacity: 0.7,
      wireframe: false,
      vertexColors: true,
      side: THREE.DoubleSide
    });
    const geo1 = buildPatternGeometry(data.layer1, data.N1, data.N2, 0x4488ff);
    meshL1 = new THREE.Mesh(geo1, mat1);
    scene.add(meshL1);

    // --- Vẽ Layer 2 (Đỏ) ---
    if (data.layer2) {
      const mat2 = new THREE.MeshPhongMaterial({
        color: 0xff4444,
        transparent: true,
        opacity: 0.5,
        wireframe: false,
        vertexColors: true,
        side: THREE.DoubleSide
      });
      const geo2 = buildPatternGeometry(data.layer2, data.N1, data.N2, 0xff4444);
      meshL2 = new THREE.Mesh(geo2, mat2);
      scene.add(meshL2);
    }

    // --- Vẽ Layer 3 (Xanh lá) ---
    if (data.layer3) {
      const mat3 = new THREE.MeshPhongMaterial({
        color: 0x44cc44,
        transparent: true,
        opacity: 0.4,
        wireframe: false,
        vertexColors: true,
        side: THREE.DoubleSide
      });
      const geo3 = buildPatternGeometry(data.layer3, data.N1, data.N2, 0x44cc44);
      meshL3 = new THREE.Mesh(geo3, mat3);
      scene.add(meshL3);
    }

    // --- Vẽ Layer 4 (Cam) ---
    if (data.layer4) {
      const mat4 = new THREE.MeshPhongMaterial({
        color: 0xffaa33,
        transparent: true,
        opacity: 0.4,
        wireframe: false,
        vertexColors: true,
        side: THREE.DoubleSide
      });
      const geo4 = buildPatternGeometry(data.layer4, data.N1, data.N2, 0xffaa33);
      meshL4 = new THREE.Mesh(geo4, mat4);
      scene.add(meshL4);
    }

    arrayGroup = buildArrayGeometry(data.N1, data.N2, data.layer1);
    scene.add(arrayGroup);

    update2DPlots(data);
    renderMatrixTable(data);
    renderFull3GPPTable();
  }

  /**
   * Draws Layer 1 precoder weights W in the complex plane (Re horizontal, Im vertical).
   * Small overlay at top-right of 3D viewport.
   */
  function drawWComplexPlane(weights) {
    const canvas = document.getElementById('cb5g-w-complex-canvas');
    if (!canvas || !weights || !weights.length) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;
    const center = { x: w / 2, y: h / 2 };
    const pad = Math.min(w, h) * 0.45;
    let maxMag = 1e-6;
    for (var i = 0; i < weights.length; i++) {
      var re = weights[i].re, im = weights[i].im;
      var m = Math.sqrt(re * re + im * im);
      if (m > maxMag) maxMag = m;
    }
    const scale = pad / Math.max(maxMag, 1e-6);

    ctx.clearRect(0, 0, w, h);

    // Axes (Re, Im)
    ctx.strokeStyle = '#444';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, center.y);
    ctx.lineTo(w, center.y);
    ctx.moveTo(center.x, 0);
    ctx.lineTo(center.x, h);
    ctx.stroke();

    // Unit circle (if scale allows)
    if (maxMag <= 1.5) {
      ctx.strokeStyle = 'rgba(68, 136, 255, 0.4)';
      ctx.setLineDash([2, 2]);
      ctx.beginPath();
      ctx.arc(center.x, center.y, scale, 0, TAU);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Points: W_k = re + j*im -> (center.x + re*scale, center.y - im*scale)
    ctx.fillStyle = '#4488ff';
    for (var j = 0; j < weights.length; j++) {
      var px = center.x + weights[j].re * scale;
      var py = center.y - weights[j].im * scale;
      ctx.beginPath();
      ctx.arc(px, py, 2.5, 0, TAU);
      ctx.fill();
    }

    ctx.fillStyle = '#0fa';
    ctx.font = '9px monospace';
    ctx.textAlign = 'center';
    ctx.fillText('W (complex)', center.x, center.y - 3);
  }

  /**
   * Draws the polarization ellipse from Pol0/Pol1 first-port weights.
   * Shows how i2 (phi_n) changes the phase relationship (linear vs circular/elliptical).
   */
  function updatePolarization(data) {
    const canvas = document.getElementById('cb5g-pol-canvas');
    if (!canvas || !data || !data.layer1.length) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;
    const center = { x: w / 2, y: h / 2 };
    const scale = (w / 2) * 0.7;

    ctx.clearRect(0, 0, w, h);

    ctx.strokeStyle = '#333';
    ctx.beginPath();
    ctx.moveTo(0, center.y);
    ctx.lineTo(w, center.y);
    ctx.moveTo(center.x, 0);
    ctx.lineTo(center.x, h);
    ctx.stroke();

    const half = data.layer1.length / 2;
    const p1 = data.layer1[0];
    const p2 = data.layer1[half];

    const phase1 = Math.atan2(p1.im, p1.re);
    const phase2 = Math.atan2(p2.im, p2.re);
    const amp1 = Math.sqrt(p1.re * p1.re + p1.im * p1.im) || 1e-6;
    const amp2 = Math.sqrt(p2.re * p2.re + p2.im * p2.im) || 1e-6;
    const norm = Math.max(amp1, amp2, 1e-6);

    ctx.beginPath();
    ctx.strokeStyle = '#0fa';
    ctx.lineWidth = 2;
    for (var t = 0; t <= TAU + 0.05; t += 0.05) {
      var x = center.x + (amp1 / norm) * Math.cos(t + phase1) * scale;
      var y = center.y - (amp2 / norm) * Math.cos(t + phase2) * scale;
      if (t === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    var time = (Date.now() / 500) % TAU;
    var dotX = center.x + (amp1 / norm) * Math.cos(time + phase1) * scale;
    var dotY = center.y - (amp2 / norm) * Math.cos(time + phase2) * scale;
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(dotX, dotY, 4, 0, TAU);
    ctx.fill();

    ctx.fillStyle = '#0fa';
    ctx.font = '10px monospace';
    ctx.fillText('Polarization', 5, 12);
  }

  function animate() {
    requestAnimationFrame(animate);
    if (controls && controls.enabled) controls.update();
    if (renderer && scene && camera) renderer.render(scene, camera);
    const data = calculatePrecoder();
    updatePolarization(data);
    if (data && data.layer1) drawWComplexPlane(data.layer1);
  }

  function setCameraView(view) {
    const d = 6;
    switch (view) {
      case 'front': camera.position.set(d, 0, 0); break;
      case 'back': camera.position.set(-d, 0, 0); break;
      case 'top': camera.position.set(0, d, 0); break;
      case 'side': camera.position.set(0, 0, d); break;
      case 'iso': camera.position.set(5, 4, 6); break;
      case 'zoomIn': camera.position.multiplyScalar(0.8); break;
      case 'zoomOut': camera.position.multiplyScalar(1.25); break;
      default: break;
    }
    camera.lookAt(0, 0, 0);
    if (controls) controls.update();
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

  function init() {
    const root = $('#cb5g-root');
    if (!root.length) return;

    populateTables();
    updateSliderRanges();
    syncValues();

    document.getElementById('cb5g-pmi-global').addEventListener('change', function() {
      const PMI = +this.value;
      const key = $('#cb5g-config').val();
      const cfg = ALL_CONFIGS[key] || CONFIGS[key] || ALL_CONFIGS['4,2'] || CONFIGS['2,2'];
      const logic = getTableLogic();

      if (!PMI && PMI !== 0) return; // Cho phép giá trị 0
      if (!cfg || !logic) return;

      // Lấy kết quả từ hàm convert
      let result = convertPMIToValues(cfg.N1, cfg.N2, cfg.O1, cfg.O2, logic.rank, logic.mode, PMI);
      
      if (result) {
        // Gán giá trị mới vào các thẻ input 
        // (Lưu ý: Đảm bảo các thuộc tính i11, i12, i2, i13 khớp với object mà hàm convertPMIToValues trả về)
        if (result.i11 !== undefined) $('#cb5g-i11').val(result.i11);
        if (result.i12 !== undefined) $('#cb5g-i12').val(result.i12);
        if (result.i2 !== undefined)  $('#cb5g-i2').val(result.i2);
        if (result.i13 !== undefined) $('#cb5g-i13').val(result.i13);

        // Gọi các hàm cập nhật giao diện và 3D
        syncValues();
        updateMeshes();
      }
    });

    const container = root.find('.cb5g-viewport-wrap');
    if (container.length) {
      init3D(container);
    }

    $('#cb5g-config').on('change', function() {
      updateSliderRanges();
      updateMeshes();
    });
    $('#cb5g-i11, #cb5g-i12, #cb5g-i2, #cb5g-i13, #cb5g-rank').on('input change', function() {
      syncValues();
      updateMeshes();
    });

    root.find('.cb5g-cam-btn[data-view="iso"]').on('click', () => setCameraView('iso'));
    root.find('.cb5g-cam-btn[data-view="front"]').on('click', () => setCameraView('front'));
    root.find('.cb5g-cam-btn[data-view="top"]').on('click', () => setCameraView('top'));
    root.find('.cb5g-cam-btn[data-view="side"]').on('click', () => setCameraView('side'));
    root.find('.cb5g-cam-btn[data-view="zoomIn"]').on('click', () => setCameraView('zoomIn'));
    root.find('.cb5g-cam-btn[data-view="zoomOut"]').on('click', () => setCameraView('zoomOut'));

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

    $('#cb5g3dScaleBtn').on('click', function() {
      patternScale3D = patternScale3D === 'linear' ? 'dB' : 'linear';
      update3DScaleButtonIcon();
      updateMeshes();
    });

    $(window).on('resize', function() {
      if (!container.length) return;
      const w = container.width();
      const h = container.height();
      if (renderer && camera) {
        renderer.setSize(w, h);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
      }
      update2DPlots();
    });
  }

  $(document).ready(init);
})(jQuery);
