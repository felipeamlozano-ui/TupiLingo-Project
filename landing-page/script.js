/**
 * TupiLingo • Interações, Animações e Parallax 3D
 * Design System Inspirado no Duolingo: Lúdico, Responsivo e Acessível
 */

document.addEventListener('DOMContentLoaded', () => {
  initHeaderScroll();
  initMobileMenu();
  initHeroParallax();
  initSimulator();
  initShowcaseTabs();
  initInstallAccordion();
  initFeedbackModal();
});

/**
 * 1. Cabeçalho com Efeito de Compactação Suave
 */
function initHeaderScroll() {
  const header = document.getElementById('header');
  if (!header) return;

  const onScroll = () => {
    if (window.scrollY > 20) {
      header.classList.add('scrolled');
    } else {
      header.classList.remove('scrolled');
    }
  };

  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

/**
 * 2. Menu Mobile Amigável e Acessível
 */
function initMobileMenu() {
  const toggleBtn = document.getElementById('mobileMenuToggle');
  const navLinks = document.getElementById('navLinks');

  if (!toggleBtn || !navLinks) return;

  const toggle = (forceClose = false) => {
    const isOpen = navLinks.classList.contains('open');
    if (isOpen || forceClose) {
      navLinks.classList.remove('open');
      toggleBtn.classList.remove('active');
      toggleBtn.setAttribute('aria-expanded', 'false');
    } else {
      navLinks.classList.add('open');
      toggleBtn.classList.add('active');
      toggleBtn.setAttribute('aria-expanded', 'true');
    }
  };

  toggleBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    toggle();
  });

  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => toggle(true));
  });

  document.addEventListener('click', (e) => {
    if (!navLinks.contains(e.target) && !toggleBtn.contains(e.target)) {
      toggle(true);
    }
  });
}

/**
 * 3. Parallax 3D Interativo no Hero (Stickers Orbitando + Inclinação do Celular)
 */
function initHeroParallax() {
  const stage = document.getElementById('heroStage');
  const phone = document.getElementById('heroPhoneMockup');
  const badges = document.querySelectorAll('.floating-badge, .floating-mascot-speech');

  if (!stage) return;

  // Habilita efeito apenas se o usuário tiver ponteiro fino (Desktop / Mouse)
  const isFinePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  if (!isFinePointer) return;

  let bounds = stage.getBoundingClientRect();
  let isHovered = false;

  window.addEventListener('resize', () => {
    bounds = stage.getBoundingClientRect();
  });

  stage.addEventListener('mouseenter', () => {
    isHovered = true;
    bounds = stage.getBoundingClientRect();
  });

  stage.addEventListener('mousemove', (e) => {
    if (!isHovered) return;

    const mouseX = e.clientX - bounds.left;
    const mouseY = e.clientY - bounds.top;

    // Normaliza de -1 a 1 em relação ao centro do palco
    const xRatio = (mouseX / bounds.width - 0.5) * 2;
    const yRatio = (mouseY / bounds.height - 0.5) * 2;

    // Inclinação sutil do celular 3D
    if (phone) {
      const tiltX = -yRatio * 8;
      const tiltY = xRatio * 10;
      phone.style.transform = `perspective(1000px) rotateX(${tiltX.toFixed(2)}deg) rotateY(${tiltY.toFixed(2)}deg) translateY(-8px)`;
    }

    // Deslocamento em profundidade (Parallax) para os badges flutuantes
    badges.forEach(badge => {
      const depth = parseFloat(badge.dataset.depth) || 0.4;
      const moveX = xRatio * depth * 24;
      const moveY = yRatio * depth * 24;
      badge.style.transform = `translate3d(${moveX.toFixed(1)}px, ${moveY.toFixed(1)}px, 0)`;
    });
  });

  stage.addEventListener('mouseleave', () => {
    isHovered = false;
    if (phone) {
      phone.style.transform = '';
    }
    badges.forEach(badge => {
      badge.style.transform = '';
    });
  });
}

/**
 * 4. Controle do Simulador Web (Dispositivos, Iframe, Fullscreen e Verificação Local)
 */
function initSimulator() {
  const iframe = document.getElementById('tupiIframe');
  const loader = document.getElementById('simLoader');
  const fileNotice = document.getElementById('simFileNotice');
  const btnPhone = document.getElementById('btnSimPhone');
  const btnTablet = document.getElementById('btnSimTablet');
  const simFrame = document.getElementById('simFrame');
  const screenWrapper = document.getElementById('simScreenWrapper');
  const reloadBtn = document.getElementById('simReloadBtn');
  const fullscreenBtn = document.getElementById('simFullscreenBtn');

  if (!iframe) return;

  // Verificação de segurança: navegadores modernos barram WebAssembly via file:// (CORS)
  const isFileProtocol = window.location.protocol === 'file:';
  if (isFileProtocol && fileNotice) {
    if (loader) loader.style.display = 'none';
    fileNotice.style.display = 'flex';
  }

  // Oculta o loader quando o iframe carregar
  const hideLoader = () => {
    if (loader && !loader.classList.contains('loaded')) {
      loader.classList.add('loaded');
      setTimeout(() => {
        loader.style.display = 'none';
      }, 450);
    }
  };

  iframe.addEventListener('load', hideLoader);
  setTimeout(hideLoader, 5000); // Fallback caso já esteja no cache

  // Recarregar iframe
  if (reloadBtn) {
    reloadBtn.addEventListener('click', () => {
      if (isFileProtocol && fileNotice) {
        showToast('Para rodar o WebAssembly localmente, use a Opção 5 do dev.bat!');
        return;
      }
      if (loader) {
        loader.style.display = 'flex';
        loader.classList.remove('loaded');
      }
      try {
        iframe.src = './app/index.html?t=' + Date.now();
      } catch (e) {
        iframe.setAttribute('src', './app/index.html');
      }
      showToast('Recarregando o TupiLingo...');
      setTimeout(hideLoader, 2500);
    });
  }

  // Alternar entre Celular e Tablet
  if (btnPhone && btnTablet && simFrame) {
    btnPhone.addEventListener('click', () => {
      simFrame.classList.remove('sim-tablet');
      simFrame.classList.add('sim-phone');
      btnPhone.classList.add('active');
      btnTablet.classList.remove('active');
    });

    btnTablet.addEventListener('click', () => {
      simFrame.classList.remove('sim-phone');
      simFrame.classList.add('sim-tablet');
      btnTablet.classList.add('active');
      btnPhone.classList.remove('active');
    });
  }

  // Expandir em Tela Cheia
  if (fullscreenBtn && screenWrapper) {
    fullscreenBtn.addEventListener('click', () => {
      const isFullscreen = document.fullscreenElement || document.webkitFullscreenElement;
      
      if (!isFullscreen) {
        const enterFullscreen = screenWrapper.requestFullscreen ||
                                screenWrapper.webkitRequestFullscreen ||
                                screenWrapper.mozRequestFullScreen;
        if (enterFullscreen) {
          enterFullscreen.call(screenWrapper).catch(() => {
            window.open('./app/index.html', '_blank', 'noopener,noreferrer');
          });
        } else {
          window.open('./app/index.html', '_blank', 'noopener,noreferrer');
        }
      } else {
        const exitFullscreen = document.exitFullscreen || document.webkitExitFullscreen;
        if (exitFullscreen) {
          exitFullscreen.call(document);
        }
      }
    });
  }
}

/**
 * 5. Filtro de Abas no Showcase de Telas Reais
 */
function initShowcaseTabs() {
  const tabs = document.querySelectorAll('.tab-pill');
  const cards = document.querySelectorAll('.gallery-card');

  if (!tabs.length || !cards.length) return;

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetCategory = tab.dataset.tab;

      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      cards.forEach(card => {
        if (card.dataset.category === targetCategory) {
          card.style.display = 'flex';
          card.style.opacity = '0';
          card.style.transform = 'translateY(12px)';
          setTimeout(() => {
            card.style.transition = 'all 0.25s ease';
            card.style.opacity = '1';
            card.style.transform = 'translateY(0)';
          }, 20);
        } else {
          card.style.display = 'none';
        }
      });
    });
  });

  // Ativa a primeira aba por padrão
  if (tabs[0]) {
    tabs[0].click();
  }
}

/**
 * 6. Accordion Amigável do Guia de Instalação do APK
 */
function initInstallAccordion() {
  const toggleBtn = document.getElementById('toggleInstallGuideBtn');
  const content = document.getElementById('installGuideContent');

  if (!toggleBtn || !content) return;

  toggleBtn.addEventListener('click', () => {
    const isHidden = content.style.display === 'none';
    if (isHidden) {
      content.style.display = 'block';
      toggleBtn.textContent = 'Ocultar Instruções';
    } else {
      content.style.display = 'none';
      toggleBtn.textContent = 'Instruções';
    }
  });
}

/**
 * 7. Modal de Feedback e Sugestões
 */
function initFeedbackModal() {
  const modal = document.getElementById('feedbackModal');
  const openBtn = document.getElementById('openFeedbackModalBtn');
  const closeBtn = document.getElementById('closeFeedbackModalBtn');

  if (!modal) return;

  if (openBtn) {
    openBtn.addEventListener('click', () => {
      modal.showModal();
    });
  }

  if (closeBtn) {
    closeBtn.addEventListener('click', () => {
      modal.close();
    });
  }

  modal.addEventListener('click', (e) => {
    const rect = modal.getBoundingClientRect();
    if (
      e.clientX < rect.left ||
      e.clientX > rect.right ||
      e.clientY < rect.top ||
      e.clientY > rect.bottom
    ) {
      modal.close();
    }
  });

  window.submitFeedback = () => {
    const name = document.getElementById('fbName')?.value || 'Amigo';
    modal.close();
    showToast(`Obrigado, ${name}! Sua sugestão foi registrada com sucesso.`);
    const form = document.getElementById('feedbackForm');
    if (form) form.reset();
  };
}

/**
 * 8. Notificação Toast Estilo Duolingo
 */
function showToast(message) {
  let toast = document.getElementById('siteToast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'siteToast';
    toast.className = 'toast-notification';
    document.body.appendChild(toast);
  }

  toast.innerHTML = `<span class="toast-content"><svg class="toast-svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg><span>${message}</span></span>`;
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3600);
}
