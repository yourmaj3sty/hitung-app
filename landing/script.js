/**
 * HITUNG • OIL MOTION INTERACTIVE RUNTIME & SMART DEVICE DETECTOR
 * Fluid organic viscosity simulation, Gyroscope & Pointer tracking,
 * and adaptive platform routing.
 */

(function () {
  'use strict';

  // --- 1. SMART DEVICE DETECTION & DYNAMIC CTA ---
  const userAgent = navigator.userAgent || navigator.vendor || window.opera;
  const isIOS = /iPad|iPhone|iPod/.test(userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const isAndroid = /android/i.test(userAgent);

  const devicePill = document.getElementById('device-pill');
  const deviceIcon = document.getElementById('device-icon');
  const deviceText = document.getElementById('device-detected-text');

  const mainCtaBtn = document.getElementById('main-cta-btn');
  const mainCtaIcon = document.getElementById('main-cta-icon');
  const mainCtaTitle = document.getElementById('main-cta-title');
  const mainCtaSubtitle = document.getElementById('main-cta-subtitle');

  const secondaryCtaBtn = document.getElementById('secondary-cta-btn');
  const secondaryCtaText = document.getElementById('secondary-cta-text');

  const navCtaBtn = document.getElementById('nav-cta-btn');
  const btnDownloadApkBottom = document.getElementById('btn-download-apk-bottom');
  const btnOpenIosBottom = document.getElementById('btn-open-ios-bottom');

  // Direct APK Download URL (GitHub Release v2.0 or local route)
  const APK_DOWNLOAD_URL = 'https://github.com/yourmaj3sty/hitung-app/releases/download/v2.0.0/app-release.apk';
  const PWA_APP_URL = '/app';

  // Icons SVG
  const ICON_APPLE = `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 20.94c1.5 0 2.75 1.06 4 1.06 3 0 6-8 6-12.22A4.91 4.91 0 0 0 17 5c-2.22 0-4 1.44-5 2-1-.56-2.78-2-5-2a4.9 4.9 0 0 0-5 4.78C2 14 5 22 8 22c1.25 0 2.5-1.06 4-1.06Z"/><path d="M10 2c1 .5 2 2 2 5"/></svg>`;
  const ICON_ANDROID = `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M4 18l2-9M20 18l-2-9M9 5L7 2M15 5l2-3M6 9h12a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z"/></svg>`;
  const ICON_DESKTOP = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>`;

  if (isIOS) {
    // === IPHONE / IOS EXPERIENCE ===
    deviceIcon.innerHTML = ICON_APPLE;
    deviceText.textContent = 'Perangkat Terdeteksi: iPhone / iOS';

    mainCtaIcon.innerHTML = ICON_APPLE;
    mainCtaTitle.textContent = 'Buka Web App di iPhone';
    mainCtaSubtitle = 'PWA Siap Pasang • Tanpa App Store';
    mainCtaBtn.href = PWA_APP_URL;

    mainCtaBtn.addEventListener('click', (e) => {
      // Show iOS installation guide before navigating
      openIosModal();
    });

    secondaryCtaBtn.href = APK_DOWNLOAD_URL;
    secondaryCtaText.textContent = 'Download APK (Android)';

    navCtaBtn.textContent = 'Buka Web App';
    navCtaBtn.addEventListener('click', () => openIosModal());
  } else if (isAndroid) {
    // === ANDROID EXPERIENCE ===
    deviceIcon.innerHTML = ICON_ANDROID;
    deviceText.textContent = 'Perangkat Terdeteksi: Ponsel Android';

    mainCtaIcon.innerHTML = `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>`;
    mainCtaTitle.textContent = 'Download APK Android';
    mainCtaSubtitle.textContent = 'v2.0 • Offline-First • 77 MB';
    mainCtaBtn.href = APK_DOWNLOAD_URL;
    mainCtaBtn.setAttribute('download', 'hitung-app.apk');

    secondaryCtaBtn.href = PWA_APP_URL;
    secondaryCtaText.textContent = 'Coba Versi Web';

    navCtaBtn.textContent = 'Download APK';
    navCtaBtn.addEventListener('click', () => {
      window.location.href = APK_DOWNLOAD_URL;
    });
  } else {
    // === DESKTOP / LAPTOP EXPERIENCE ===
    deviceIcon.innerHTML = ICON_DESKTOP;
    deviceText.textContent = 'Terdeteksi: Komputer / Laptop';

    mainCtaIcon.innerHTML = `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>`;
    mainCtaTitle.textContent = 'Download APK Android';
    mainCtaSubtitle.textContent = 'v2.0 • Offline-First Native APK';
    mainCtaBtn.href = APK_DOWNLOAD_URL;
    mainCtaBtn.setAttribute('download', 'hitung-app.apk');

    secondaryCtaBtn.href = PWA_APP_URL;
    secondaryCtaText.textContent = 'Buka Web App (iOS PWA)';

    navCtaBtn.textContent = 'Download';
    navCtaBtn.addEventListener('click', () => {
      document.getElementById('perangkat').scrollIntoView({ behavior: 'smooth' });
    });
  }

  if (btnDownloadApkBottom) {
    btnDownloadApkBottom.href = APK_DOWNLOAD_URL;
  }

  if (btnOpenIosBottom) {
    btnOpenIosBottom.addEventListener('click', () => openIosModal());
  }

  // --- 2. MODAL CONTROLS (iOS Guide & QR Code) ---
  const iosModal = document.getElementById('ios-guide-modal');
  const closeIosModal = document.getElementById('close-ios-modal');

  const qrModal = document.getElementById('qr-modal');
  const qrTriggerBtn = document.getElementById('qr-trigger-btn');
  const closeQrModal = document.getElementById('close-qr-modal');
  const qrUrlText = document.getElementById('qr-url-text');
  const qrCodeContainer = document.getElementById('qr-code-container');

  function openIosModal() {
    if (iosModal) iosModal.classList.add('active');
  }

  function closeAllModals() {
    if (iosModal) iosModal.classList.remove('active');
    if (qrModal) qrModal.classList.remove('active');
  }

  if (closeIosModal) closeIosModal.addEventListener('click', closeAllModals);
  if (closeQrModal) closeQrModal.addEventListener('click', closeAllModals);

  [iosModal, qrModal].forEach((m) => {
    if (m) {
      m.addEventListener('click', (e) => {
        if (e.target === m) closeAllModals();
      });
    }
  });

  if (qrTriggerBtn) {
    qrTriggerBtn.addEventListener('click', () => {
      const currentUrl = window.location.href;
      if (qrUrlText) qrUrlText.textContent = currentUrl;
      renderQrCode(currentUrl);
      if (qrModal) qrModal.classList.add('active');
    });
  }

  // Lightweight SVG QR Code Generator
  function renderQrCode(url) {
    if (!qrCodeContainer) return;
    // Uses Google Chart API or static high-quality QR vector
    const qrImg = `<img src="https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${encodeURIComponent(url)}&color=07090E&bgcolor=FFFFFF" alt="QR Code" width="180" height="180" style="display:block;border-radius:12px;" />`;
    qrCodeContainer.innerHTML = qrImg;
  }

  // --- 3. BENTO CARD SPECULAR GLOW TRACKER ---
  const bentoCards = document.querySelectorAll('.bento-card-interactive');
  bentoCards.forEach((card) => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      card.style.setProperty('--glow-x', `${x}px`);
      card.style.setProperty('--glow-y', `${y}px`);
    });
  });

  // --- 4. 3D INTERACTIVE PHONE TILT EFFECT ---
  const phoneFrame = document.getElementById('phone-frame');
  const heroSection = document.querySelector('.hero-section');

  if (phoneFrame && heroSection && window.innerWidth > 900) {
    heroSection.addEventListener('mousemove', (e) => {
      const { innerWidth, innerHeight } = window;
      const x = (e.clientX / innerWidth - 0.5) * 2;
      const y = (e.clientY / innerHeight - 0.5) * 2;

      const tiltX = -y * 12;
      const tiltY = x * 15;

      phoneFrame.style.transform = `rotateX(${tiltX}deg) rotateY(${tiltY}deg) scale(1.02)`;
    });

    heroSection.addEventListener('mouseleave', () => {
      phoneFrame.style.transform = 'rotateX(0deg) rotateY(0deg) scale(1)';
    });
  }

  // --- 5. ANIMATED BALANCE NUMBER COUNTER ---
  const counterEl = document.getElementById('mock-counter');
  let hasCounted = false;

  function animateCounter() {
    if (!counterEl || hasCounted) return;
    hasCounted = true;
    const target = 18450000;
    const duration = 1400;
    const start = performance.now();

    function step(now) {
      const progress = Math.min((now - start) / duration, 1);
      // Smooth ease-out exponential
      const ease = 1 - Math.pow(1 - progress, 4);
      const current = Math.floor(ease * target);
      counterEl.textContent = current.toLocaleString('id-ID');

      if (progress < 1) {
        requestAnimationFrame(step);
      } else {
        counterEl.textContent = '18.450.000';
      }
    }
    requestAnimationFrame(step);
  }

  // Trigger counter when visible
  if ('IntersectionObserver' in window && counterEl) {
    const observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        animateCounter();
      }
    }, { threshold: 0.3 });
    observer.observe(counterEl);
  } else {
    setTimeout(animateCounter, 500);
  }

  // --- 6. OIL MOTION INTERACTIVE FLUID CANVAS ---
  const canvas = document.getElementById('oil-motion-canvas');
  if (canvas) {
    const ctx = canvas.getContext('2d');
    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });

    // Pointer dynamics
    const pointer = {
      x: width * 0.5,
      y: height * 0.4,
      targetX: width * 0.5,
      targetY: height * 0.4,
      vx: 0,
      vy: 0,
      radius: 120,
    };

    window.addEventListener('mousemove', (e) => {
      pointer.targetX = e.clientX;
      pointer.targetY = e.clientY;
    });

    window.addEventListener('touchmove', (e) => {
      if (e.touches.length > 0) {
        pointer.targetX = e.touches[0].clientX;
        pointer.targetY = e.touches[0].clientY;
      }
    }, { passive: true });

    // Gyroscope tilt on mobile devices
    if (window.DeviceOrientationEvent) {
      window.addEventListener('deviceorientation', (e) => {
        if (e.gamma !== null && e.beta !== null) {
          const tiltX = (e.gamma / 45) * (width * 0.3);
          const tiltY = ((e.beta - 45) / 45) * (height * 0.3);
          pointer.targetX = width * 0.5 + tiltX;
          pointer.targetY = height * 0.4 + tiltY;
        }
      });
    }

    // Organic Fluid Blobs (Neon Lime, Cyber Purple, Electric Cyan)
    const blobs = [
      { x: width * 0.3, y: height * 0.3, r: 180, color: 'rgba(206, 253, 55, 0.16)', vx: 0.5, vy: 0.3, phase: 0 },
      { x: width * 0.7, y: height * 0.6, r: 240, color: 'rgba(124, 58, 237, 0.18)', vx: -0.4, vy: -0.3, phase: 2 },
      { x: width * 0.5, y: height * 0.8, r: 200, color: 'rgba(6, 182, 212, 0.14)', vx: 0.3, vy: -0.4, phase: 4 },
      { x: width * 0.8, y: height * 0.2, r: 160, color: 'rgba(206, 253, 55, 0.12)', vx: -0.3, vy: 0.5, phase: 1.5 },
    ];

    let time = 0;

    function renderOilMotion() {
      time += 0.015;

      // Pointer spring interpolation
      pointer.vx += (pointer.targetX - pointer.x) * 0.05;
      pointer.vy += (pointer.targetY - pointer.y) * 0.05;
      pointer.vx *= 0.82;
      pointer.vy *= 0.82;
      pointer.x += pointer.vx;
      pointer.y += pointer.vy;

      ctx.clearRect(0, 0, width, height);

      // Composite mode for iridescent chromatic fluid mixing
      ctx.globalCompositeOperation = 'screen';

      blobs.forEach((blob) => {
        // Natural organic harmonic motion
        blob.x += Math.sin(time + blob.phase) * blob.vx * 1.5;
        blob.y += Math.cos(time + blob.phase * 1.2) * blob.vy * 1.5;

        // Pointer viscous repulsion/attraction
        const dx = pointer.x - blob.x;
        const dy = pointer.y - blob.y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < 400 && dist > 0) {
          const force = (400 - dist) / 400;
          blob.x += (dx / dist) * force * 1.8;
          blob.y += (dy / dist) * force * 1.8;
        }

        // Draw radial chromatic glow
        const radGrad = ctx.createRadialGradient(
          blob.x,
          blob.y,
          0,
          blob.x,
          blob.y,
          blob.r * (1 + Math.sin(time * 2 + blob.phase) * 0.15)
        );
        radGrad.addColorStop(0, blob.color);
        radGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');

        ctx.fillStyle = radGrad;
        ctx.beginPath();
        ctx.arc(blob.x, blob.y, blob.r * 1.5, 0, Math.PI * 2);
        ctx.fill();
      });

      // Interactive cursor liquid wake ripple
      const cursorGrad = ctx.createRadialGradient(
        pointer.x,
        pointer.y,
        0,
        pointer.x,
        pointer.y,
        pointer.radius
      );
      cursorGrad.addColorStop(0, 'rgba(206, 253, 55, 0.25)');
      cursorGrad.addColorStop(0.5, 'rgba(124, 58, 237, 0.15)');
      cursorGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');

      ctx.fillStyle = cursorGrad;
      ctx.beginPath();
      ctx.arc(pointer.x, pointer.y, pointer.radius, 0, Math.PI * 2);
      ctx.fill();

      requestAnimationFrame(renderOilMotion);
    }

    renderOilMotion();
  }
})();
