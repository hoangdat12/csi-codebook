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
    const layerPoints = { total: [], l1: [], l2: [] };

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
      const gTotal = Math.sqrt(g1 * g1 + g2 * g2);

      const angle = (type === 'azimuth') ? phi : theta - PI / 2;
      function getXY(g) {
        const rad = getRadius(g);
        return { x: center.x + rad * Math.cos(angle), y: center.y + rad * Math.sin(angle) };
      }
      layerPoints.total.push(getXY(gTotal));
      layerPoints.l1.push(getXY(g1));
      if (data.layer2) layerPoints.l2.push(getXY(g2));
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

    // 2. Layer 1 outline (dotted blue)
    ctx.setLineDash([3, 3]);
    ctx.beginPath();
    layerPoints.l1.forEach(function (p, i) {
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.strokeStyle = '#0088ff';
    ctx.lineWidth = 1;
    ctx.stroke();

    // 3. Layer 2 outline (dotted red) when Rank 2
    if (data.layer2) {
      ctx.beginPath();
      layerPoints.l2.forEach(function (p, i) {
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      ctx.strokeStyle = '#ff3333';
      ctx.stroke();
    }
    ctx.setLineDash([]);
  }